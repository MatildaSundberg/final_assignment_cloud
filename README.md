# LOG8415E Final Project

## Prerequisites

Before running the program, make sure you have the following installed:
- AWS credentials configured
- **Python 3.x**: Ensure that you have Python installed on your machine.
- **Boto3**: AWS SDK for Python.
- **Paramiko**: For SSH connections to the EC2 instances.

## Installation

1. Clone the repository to your local machine:
```sh 
git clone https://github.com/MatildaSundberg/final_assignment_cloud.git
cd <repository_directory>
```
2. Create a file named ```vpc_id.txt``` and ```subnet_id.txt``` in the AWS configuration folder ```(/home/.aws/)``` with your VPC ID and Subnet ID, respectively.
3. Ensure that your AWS credentials are configured properly, either by setting environment variables or using the AWS CLI.

## Configuration

Before running the program, you need to configure the file paths in the `globals.py` file.

## Components

### Globals
- **globals.py:** Contains global variables such as file paths, security group names, key pairs, password for MySQL.

### Main
- **main.py:** 

## Main Script: `main.py`
This script automates the setup of a distributed MySQL system using EC2 instances. It creates SSH key pairs, configures security groups, and deploys instances for the manager, workers, gatekeeper, trusted host, and proxy. Sets up MySQL replication, deploys FastAPI services, runs Sysbench benchmarks, and retrieves results for analysis. Secures non-public instances with private security groups.


### Run Clean up
- **run_cleanup.py:** Removes the instances, key pairs and security group.

### Test
- **test_custom.py:** Preformes 1000 reads and 1000 writes to the /custom endpoint.
- **test_directhit.py:** Preformes 1000 reads and 1000 writes to the /directhit endpoint
- **test_random.py:** Preformes 1000 reads and 1000 writes to the /ranomd endpoint


## Usage
1. **Configure AWS Credentials:**
   - Set up your AWS credentials on your local machine using the AWS CLI or environment variables.

2. **Edit the `globals.py` File:**
   - Open the `globals.py` file and fill in the constants with the appropriate relative paths.

3. **Make the `run_all.sh` Script Executable:**
   - In the terminal, run the following command to give execution permissions to the `run_all.sh` script:
   - 
     ```bash
     chmod +x run_all.sh
     ```

4. **Run the Bash Script:**
   - After making the script executable, run it using the following command:
     ```bash
     ./run_all.sh
     ```

5. **Check the Results:**
   - The results from the test will appear in the `test_results` map.
   - The results from the Sysbench will appear in the `sysbench` map.
   