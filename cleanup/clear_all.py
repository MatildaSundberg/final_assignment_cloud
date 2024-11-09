import boto3

# Function to terminate instances
def terminate_instances():
    ec2 = boto3.client('ec2')
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )
    instance_ids = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])
            ec2.terminate_instances(InstanceIds=[instance['InstanceId']])
            print(f"Terminating instance: {instance['InstanceId']}")
    return instance_ids

# Function to wait for instance termination
def wait_for_termination(instance_ids):
    ec2 = boto3.client('ec2')
    print('Waiting for instances to terminate.')
    waiter = ec2.get_waiter('instance_terminated')
    waiter.wait(InstanceIds=instance_ids)
    print("All instances terminated.")

# Function to delete key pairs
def delete_key_pairs(ec2, key_name):
    ec2.delete_key_pair(KeyName=key_name)
    print(f"Key pair {key_name} deleted.")

# Function to delete security groups
def delete_security_group(ec2, security_group_name):
    ec2 = boto3.client('ec2')
    
    ec2.delete_security_group(GroupName=security_group_name)
    print(f"Security group {security_group_name} deleted.")

# Main function to execute the steps
def clear_all(ec2, key_name, security_group_name):
    instance_ids = terminate_instances()
    wait_for_termination(instance_ids)
    delete_key_pairs(ec2, key_name)
    delete_security_group(ec2, security_group_name)
    print("All resources cleared.")