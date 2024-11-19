import time
import os
import stat
import boto3
import paramiko
from utils import instance_setup as i
import globals as g
from utils import util_functions as u

import logging
logging.getLogger("paramiko").setLevel(logging.CRITICAL)

if __name__ == "__main__":
    pem_file_path = g.pem_file_path
    MYSQL_ROOT_PASSWORD = g.mysql_root_password

    # Create EC2 Client
    session = boto3.Session()
    ec2 = session.resource('ec2')

    # Read VPC and Subnet IDs from files
    with open(f'{g.aws_folder_path}/vpc_id.txt', 'r') as file:
        vpc_id = file.read().strip()
    with open(f'{g.aws_folder_path}/subnet_id.txt', 'r') as file:
        subnet_id = file.read().strip()

    # Delete keypair with the same name (for testing)
    try:
        ec2.KeyPair(g.key_pair_name).delete()
    except Exception as e:
        print(f"Key pair deletion error (if it doesn't exist, this is expected): {e}")

    # Create a new key pair and save the .pem file
    key_pair = ec2.create_key_pair(KeyName=g.key_pair_name)
    os.chmod(pem_file_path, stat.S_IWUSR)  # Change security to be able to read
    with open(pem_file_path, 'w') as pem_file:
        pem_file.write(key_pair.key_material)
    os.chmod(pem_file_path, stat.S_IRUSR)  # Change file permissions to 400 to protect the private key

    # Read user data scripts from files
    with open('userdata_scripts/manager.sh', 'r') as file:
        manager_user_data = file.read()
    with open('userdata_scripts/worker_userdata.sh', 'r') as file:
        worker_user_data = file.read()
    with open('userdata_scripts/gatekeeper.sh', 'r') as file:
        gatekeeper_user_data = file.read()
    with open('userdata_scripts/trusted_host.sh', 'r') as file:
        trusted_host_user_data = file.read()
    with open('userdata_scripts/proxy.sh', 'r') as file:
        proxy_user_data = file.read()

    # Create security group for instances
    security_group_id = i.createSecurityGroup(vpc_id, g.security_group_name)

    print("Creating instances...")

    # Launch instances
    manager_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, manager_user_data, "MySQL-Manager"
    )[0]

    gatekeeper_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, gatekeeper_user_data, "Gatekeeper"
    )[0]

    trustedhost_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, trusted_host_user_data, "Trusted-Host"
    )[0]

    proxy_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, proxy_user_data, "Proxy"
    )[0]

    # Wait for manager instance to initialize
    print("Waiting for instances to initialize...")
    time.sleep(240)

    gatekeeper_private_ip, gatekeeper_public_ip = u.get_instance_ips('Gatekeeper')
    trusted_host_private_ip, trusted_host_public_ip = u.get_instance_ips('Trusted-Host')
    proxy_private_ip, proxy_public_ip = u.get_instance_ips('Proxy')
    manager_private_ip, manager_public_ip  = u.get_instance_ips('MySQL-Manager')

    print(f"Manager instance IP: {manager_private_ip}")

    # SSH into the manager instance to retrieve MASTER_LOG_FILE and MASTER_LOG_POS
    with paramiko.SSHClient() as ssh:
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(manager_public_ip, username='ubuntu', key_filename=pem_file_path)
    
        # Store MySQL credentials in .my.cnf file securely
        command = f"echo -e '[client]\\nuser=root\\npassword={MYSQL_ROOT_PASSWORD}' > /home/ubuntu/.my.cnf && chmod 600 /home/ubuntu/.my.cnf"
        ssh.exec_command(command)

        # Run command to retrieve log file and position
        stdin, stdout, stderr = ssh.exec_command("mysql --defaults-file=/home/ubuntu/.my.cnf -e 'SHOW MASTER STATUS\\G'")
    
        output = stdout.read().decode()
        error = stderr.read().decode()

        if error:
            print(f"Error retrieving master status: {error}")
            exit(1)

    # Parse output to get MASTER_LOG_FILE and MASTER_LOG_POS
    master_log_file = ""
    master_log_pos = ""
    for line in output.splitlines():
        if "File:" in line:
            master_log_file = line.split(":")[1].strip()
        elif "Position:" in line:
            master_log_pos = line.split(":")[1].strip()

    print(f"Retrieved MASTER_LOG_FILE: {master_log_file}, MASTER_LOG_POS: {master_log_pos}")

    # Update worker user data with retrieved information
    worker_user_data = worker_user_data.replace('$MANAGER_IP', manager_private_ip)
    worker_user_data = worker_user_data.replace('$MASTER_LOG_FILE', master_log_file)
    worker_user_data = worker_user_data.replace('$MASTER_LOG_POS', master_log_pos)

    time.sleep(120)

    # Launch worker instances
    worker_instances = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, worker_user_data, "MySQL-Worker-1"
    )
    worker_instances = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, worker_user_data, "MySQL-Worker-2"
    )
    time.sleep(60)

    worker_1_private_ip, worker_1_public_ip = u.get_instance_ips('MySQL-Worker-1')
    worker_2_private_ip, worker_2_public_ip = u.get_instance_ips('MySQL-Worker-2')

    time.sleep(60)


    print("Worker instances created.")

    print(f"Gate IP: {gatekeeper_public_ip}")
    print(f"Trusted Host IP: {trusted_host_public_ip}")
    print(f"Proxy IP: {proxy_public_ip}")

    #Set up `config.json` on the Gatekeeper instance with the IPs of Trusted Host and Proxy
    u.ssh_and_run_command(
        gatekeeper_public_ip, pem_file_path,
        f"echo '{{\"TRUSTED_HOST_PRIVATE_IP\": \"{trusted_host_private_ip}\", \"PROXY_PRIVATE_IP\": \"{proxy_private_ip}\"}}' > config.json"
    )

    # Set up `config.json` on the Trusted Host instance with the IP of the Proxy
    u.ssh_and_run_command(
        trusted_host_public_ip, pem_file_path,
        f"echo '{{\"PROXY_PRIVATE_IP\": \"{proxy_private_ip}\", \"GATEKEEPER\": \"{gatekeeper_private_ip}\"}}' > config.json"
    )

    # Set up `config.json` on the .. instance with the IP of the Proxy
    u.ssh_and_run_command(
        proxy_public_ip, pem_file_path,
        f"echo '{{\"WORKER_1_PRIVATE_IP\": \"{worker_1_private_ip}\", \"WORKER_2_PRIVATE_IP\": \"{worker_2_private_ip}\", \"MANAGER_PRIVATE_IP\": \"{manager_private_ip}\"}}' > config.json"
    )

    time.sleep(120)


    # Start running .py files
    u.ssh_and_run_command(
        gatekeeper_public_ip, pem_file_path,
        "nohup python3 gatekeeper.py > log.txt 2>&1 &"
    )

    u.ssh_and_run_command(
        trusted_host_public_ip, pem_file_path,
        "nohup python3 trusted_host.py > log.txt 2>&1 &"
    )

    u.ssh_and_run_command(
        proxy_public_ip, pem_file_path,
        "nohup python3 proxy.py > log.txt 2>&1 &"
    )

    u.ssh_and_run_command(
        worker_1_public_ip, pem_file_path,
        "nohup python3 worker.py > log.txt 2>&1 &"
    )

    u.ssh_and_run_command(
        worker_2_public_ip, pem_file_path,
        "nohup python3 worker.py > log.txt 2>&1 &"
    ) 

    u.ssh_and_run_command(
        manager_public_ip, pem_file_path,
        "nohup python3 manager.py > log.txt 2>&1 &"
    )

    time.sleep(240)

    u.ssh_and_run_command(
        manager_public_ip, pem_file_path,
        f"sudo sysbench /usr/share/sysbench/oltp_read_only.lua --mysql-db=sakila --mysql-user=root --mysql-password={MYSQL_ROOT_PASSWORD} run > sysbench_results_manager.txt"
    )
    u.ssh_and_run_command(
        worker_1_public_ip, pem_file_path,
        f"sudo sysbench /usr/share/sysbench/oltp_read_only.lua --mysql-db=sakila --mysql-user=root --mysql-password={MYSQL_ROOT_PASSWORD} run > sysbench_results_worker.txt"
    )
    u.ssh_and_run_command(
        worker_2_public_ip, pem_file_path,
        f"sudo sysbench /usr/share/sysbench/oltp_read_only.lua --mysql-db=sakila --mysql-user=root --mysql-password={MYSQL_ROOT_PASSWORD} run > sysbench_results_worker.txt"
    )

    time.sleep(100)

    manager_instance_id = u.retrieve_instance_id('MySQL-Manager')
    worker_instance_id = u.retrieve_instance_id('MySQL-Worker-1')
    worker_2_instance_id = u.retrieve_instance_id('MySQL-Worker-2')
    trustedhost_instance_id = u.retrieve_instance_id('Trusted-Host')
    proxy_instance_id = u.retrieve_instance_id('Proxy')


    sysbench_dir = "./sysbench"

    manager_file_path = os.path.join(sysbench_dir, "manager.txt")
    worker_file_path = os.path.join(sysbench_dir, "worker.txt")
    worker_2_file_path = os.path.join(sysbench_dir, "worker_2.txt")

    # Ensure sysbench directory exists
    if not os.path.exists(sysbench_dir):
        os.makedirs(sysbench_dir)
        sysbench_dir = "./sysbench"

    u.transfer_file_from_ec2(manager_instance_id, "/home/ubuntu/sysbench_results_manager.txt", manager_file_path, pem_file_path)
    u.transfer_file_from_ec2(worker_instance_id, "/home/ubuntu/sysbench_results_worker.txt", worker_file_path, pem_file_path)
    u.transfer_file_from_ec2(worker_2_instance_id, "/home/ubuntu/sysbench_results_worker.txt", worker_2_file_path, pem_file_path)

    #time.sleep(200)

    # Create private security group
    #private_sg = i.create_private_security_group(vpc_id, g.security_group_name2, security_group_id)                          
    #i.update_instance_security_groups([manager_instance_id, trustedhost_instance_id, proxy_instance_id, worker_instance_id, worker_2_instance_id], [security_group_id])

