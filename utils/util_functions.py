import boto3
import paramiko
import time

'''
Description: Connects to an EC2 instance via SSH and runs a specified Python script.
Inputs: 
    instance_ip (str) - The public IP address of the EC2 instance.
    pem_file_path (str) - The file path to the PEM file used for SSH authentication.
    file_name (str) - The name of the Python script to run on the instance.
Outputs: None (prints connection status and script execution results).
'''
def ssh_and_run_py_script(instance_ip: str, pem_file_path: str, file_name :str):
    try:
        print(f"Connecting to {instance_ip} using SSH...")
        # Initialize SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Connect to the instance
        ssh.connect(instance_ip, username='ubuntu', key_filename=pem_file_path)
        
        print(f"Connected, now running {file_name}.py...")

        # Run the command to execute the Python script
        stdin, stdout, stderr = ssh.exec_command(f'python3 {file_name}.py')
        
        # Close the SSH connection
        ssh.close()
        print("SSH connection closed.")

    except Exception as e:
        print(f"An error occurred during SSH: {str(e)}")

def ssh_and_run_command(instance_ip:str, pem_file_path:str, command_str:str):
    try:
        print(f"Connecting to {instance_ip} using SSH...")
        # Initialize SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Connect to the instance
        ssh.connect(instance_ip, username='ubuntu', key_filename=pem_file_path)
        
        print(f"Connected, now running command: {command_str}")

        # Run the command to execute the Python script
        stdin, stdout, stderr = ssh.exec_command(f'{command_str}')
        
        # Close the SSH connection
        time.sleep(5)
        ssh.close()
        print("SSH connection closed.")

    except Exception as e:
        print(f"An error occurred during SSH: {str(e)}")

# Attaches terminal to the script
def ssh_and_run_command_tmux(instance_ip: str, pem_file_path: str, command_str: str):
    try:
        print(f"Connecting to {instance_ip} using SSH...")
        # Initialize SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Connect to the instance
        ssh.connect(instance_ip, username='ubuntu', key_filename=pem_file_path)
        
        print(f"Connected, now running command inside tmux: {command_str}")

        # Use tmux to ensure the process has a persistent TTY
        tmux_command = f"tmux new-session -d -s mysession '{command_str}'"
        
        # Run the command inside a tmux session
        ssh.exec_command(tmux_command)
        
        # Allow the command to start and then close the SSH connection
        time.sleep(5)
        ssh.close()
        print("SSH connection closed. The process is running inside a tmux session.")

    except Exception as e:
        print(f"An error occurred during SSH: {str(e)}")



def transfer_file_to_ec2(instance_id, file_path, destination_path, key_path, username='ubuntu'):
    """
    Transfer a file to an EC2 instance via SFTP.

    :param instance_id: EC2 instance ID
    :param file_path: Local path of the file to be transferred
    :param destination_path: Destination path on the EC2 instance
    :param key_path: Path to the private key file (e.g., .pem file) for SSH authentication
    :param username: Username for the EC2 instance (default: 'ubuntu')
    """
    try:
        # Initialize EC2 resource
        ec2 = boto3.client('ec2')
        
        # Get the public DNS or IP address of the EC2 instance
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance_info = response['Reservations'][0]['Instances'][0]
        public_ip = instance_info.get('PublicIpAddress') or instance_info.get('PublicDnsName')

        print(f"Public IP: {public_ip}")

        if not public_ip:
            raise ValueError("Instance does not have a public IP or DNS")

        # Initialize the SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        # Load the private key
        private_key = paramiko.RSAKey.from_private_key_file(key_path)

        # Connect to the EC2 instance
        print(f"Connecting to EC2 instance {instance_id} at {public_ip}...")
        ssh.connect(hostname=public_ip, username=username, pkey=private_key)

        # Open SFTP session
        sftp = ssh.open_sftp()

        # Transfer the file
        print(f"Transferring {file_path} to {destination_path} on EC2 instance...")
        sftp.put(file_path, destination_path)

        # Close the SFTP session and SSH connection
        sftp.close()
        ssh.close()

        print("File transfer successful!")

    except Exception as e:
        print(f"Error occurred during file transfer: {str(e)}")


def get_orchestrator_instance_id():
    # Initialize the EC2 client
    ec2_client = boto3.client('ec2')

    # Describe all running EC2 instances with the 'orchestrator-instance' tag
    response = ec2_client.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',  # Filter by the 'Name' tag
                'Values': ['orchestrator-instance']  # Only instances with the 'orchestrator-instance' tag
            },
            {
                'Name': 'instance-state-name',
                'Values': ['running']  # Only running instances
            }
        ]
    )

    # Extract the details of the orchestrator instance
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            # print(f"Orchestrator Instance Found: Instance ID: {instance_id}")
            
            # Return the Instance ID
            return instance_id
    
    print("No running orchestrator-instance found.")
    return None



def get_orchestrator_instance_ip():
    # Initialize the EC2 client
    ec2_client = boto3.client('ec2')

    # Describe all running EC2 instances with the 'orchestrator-instance' tag
    response = ec2_client.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',  # Filter by the 'Name' tag
                'Values': ['orchestrator-instance']  # Only instances with the 'orchestrator-instance' tag
            },
            {
                'Name': 'instance-state-name',
                'Values': ['running']  # Only running instances
            }
        ]
    )

    # Extract the details of the orchestrator instance
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            public_ip = instance.get('PublicIpAddress')
            if public_ip:
                # Return the Public IP address
                return public_ip
    
    print("No running orchestrator-instance found or the instance does not have a public IP address.")
    return None
