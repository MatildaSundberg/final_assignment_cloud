import globals as g
from cleanup import clear_all
import boto3

'''
Description: This script performs a cleanup operation by deleting the specified AWS EC2 instances, key pair, and security group.
             It uses the `clear_all` function from the `cleanup` module to remove these resources.
'''

ec2 = boto3.client('ec2')

clear_all.clear_all(ec2, g.key_pair_name, g.security_group_name)