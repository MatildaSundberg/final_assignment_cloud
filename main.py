import time
import os
import stat
import boto3
import paramiko
from utils import instance_setup as i
import globals as g
from utils import util_functions as u

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

    # Load user data scripts for manager and workers
    with open('userdata_scripts/manager.sh', 'r') as file:
        manager_user_data = file.read()
    with open('userdata_scripts/worker_userdata.sh', 'r') as file:
        worker_user_data = file.read()

    # Create security group for instances
    security_group_id = i.createSecurityGroup(vpc_id, g.security_group_name)

    print("Creating instances...")

    # Launch manager instance
    manager_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, manager_user_data, "MySQL-Manager"
    )[0]

    # Wait for manager instance to initialize
    print("Waiting for manager instance to initialize...")
    time.sleep(120)


    manager_private_ip, manager_public_ip  = u.get_instance_ips('MySQL-Manager')
    print(f"Manager instance IP: {manager_private_ip}")

    # SSH into the manager instance to retrieve MASTER_LOG_FILE and MASTER_LOG_POS
    with paramiko.SSHClient() as ssh:
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(manager_public_ip, username='ubuntu', key_filename=pem_file_path)
        
        # Create a .my.cnf file to securely store MySQL credentials in the ubuntu user's home directory
        ssh.exec_command(f'''
            echo "[client]
            user=root
            password={MYSQL_ROOT_PASSWORD}" | tee /home/ubuntu/.my.cnf > /dev/null
            chmod 600 /home/ubuntu/.my.cnf
        ''')

        # Run command to retrieve log file and position using .my.cnf credentials
        stdin, stdout, stderr = ssh.exec_command("mysql --defaults-file=/home/ubuntu/.my.cnf -e \"SHOW MASTER STATUS\\G\"")
        output = stdout.read().decode()
        error = stderr.read().decode()

        if error:
            print(f"Error retrieving master status: {error}")
            ssh.close()
            exit(1)
        ssh.close()

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

    # Launch worker instances
    worker_instances = i.createInstance(
        't2.large', 2, 2, key_pair, security_group_id, subnet_id, worker_user_data, "MySQL-Worker"
    )

    print("Worker instances created.")

    # time error??