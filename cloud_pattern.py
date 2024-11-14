import time
import os
import stat
import boto3
import paramiko
import requests
from utils import instance_setup as i
from utils import util_functions as ssh
import globals as g

if __name__ == "__main__":
    pem_file_path = g.pem_file_path

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

    # Create security group for instances
    security_group_id = i.createSecurityGroup(vpc_id, g.security_group_name)

    # Read user data scripts from files
    with open('userdata_scripts/gatekeeper.sh', 'r') as file:
        gatekeeper_user_data = file.read()
    with open('userdata_scripts/trusted_host.sh', 'r') as file:
        trusted_host_user_data = file.read()
    with open('userdata_scripts/proxy.sh', 'r') as file:
        proxy_user_data = file.read()

    # Create instances
    gatekeeper_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, gatekeeper_user_data, "Gatekeeper"
    )[0]

    trustedhost_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, trusted_host_user_data, "Trusted-Host"
    )[0]

    proxy_instance = i.createInstance(
        't2.large', 1, 1, key_pair, security_group_id, subnet_id, proxy_user_data, "Proxy"
    )[0]

    # Wait for instances to be ready
    time.sleep(240)

    # Assuming the IPs are retrieved dynamically
    gatekeeper_private_ip, gatekeeper_public_ip = ssh.get_instance_ips('Gatekeeper')
    trusted_host_private_ip, trusted_host_public_ip = ssh.get_instance_ips('Trusted-Host')
    proxy_private_ip, proxy_public_ip = ssh.get_instance_ips('Proxy')

    print(f"Gate IP: {gatekeeper_public_ip}")
    print(f"Trusted Host IP: {trusted_host_public_ip}")
    print(f"Proxy IP: {proxy_public_ip}")

    # Set up `config.json` on the Gatekeeper instance with the IPs of Trusted Host and Proxy
    ssh.ssh_and_run_command(
        gatekeeper_public_ip, pem_file_path,
        f"echo '{{\"TRUSTED_HOST_PRIVATE_IP\": \"{trusted_host_private_ip}\", \"PROXY_PRIVATE_IP\": \"{proxy_private_ip}\"}}' > config.json"
    )

    # Set up `config.json` on the Trusted Host instance with the IP of the Proxy
    ssh.ssh_and_run_command(
        trusted_host_public_ip, pem_file_path,
        f"echo '{{\"PROXY_PRIVATE_IP\": \"{proxy_private_ip}\", \"GATEKEEPER\": \"{gatekeeper_private_ip}\"}}' > config.json"
    )

    # Set up `config.json` on the .. instance with the IP of the Proxy
    ssh.ssh_and_run_command(
        proxy_public_ip, pem_file_path,
        f"echo '{{\"TRUSTED_HOST_PRIVATE_IP\": \"{trusted_host_private_ip}\", \"GATEKEEPER\": \"{gatekeeper_private_ip}\"}}' > config.json"
    )

    time.sleep(120)
    
    # Update gatekeeper.py with Trusted Host IP and start the service
    ssh.ssh_and_run_command(
        gatekeeper_public_ip, pem_file_path,
        "nohup python3 gatekeeper.py > log.txt 2>&1 &"
    )

    ssh.ssh_and_run_command(
        trusted_host_public_ip, pem_file_path,
        "nohup python3 trusted_host.py > log.txt 2>&1 &"
    )

    # Start the proxy.py service on the Proxy instance
    ssh.ssh_and_run_command(
        proxy_public_ip, pem_file_path,
        "nohup python3 proxy.py > log.txt 2>&1 &"
    )

    time.sleep(120)

    # Send the message "hej" to the Gatekeeper
    url = f"http://{gatekeeper_public_ip}:5000/send"
    data = {"message": "hej"}

    try:
        response = requests.post(url, json=data)
        response.raise_for_status()
        print(response.status_code)
        print(response.json())
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")