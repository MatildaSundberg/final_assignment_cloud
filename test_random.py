import requests
import concurrent.futures
import os
from utils import util_functions as u

"""
Description:
This script performs stress testing by sending 1000 concurrent write and read requests 
to the Gatekeeper instance with the endpoint /random . The script inserts unique records into the `actor` table (write operation) 
and retrieves them based on unique identifiers (read operation). Results of the operations are logged to 
separate files for analysis.

Outputs:
    - Log files containing the results of write operations (`write_results_custom.log`).
    - Log files containing the results of read operations (`read_results_custom.log`).

"""

# Get the IP addresses of the Gatekeeper instance
gatekeeper_private_ip, gatekeeper_public_ip = u.get_instance_ips('Gatekeeper')

URL = f"http://{gatekeeper_public_ip}:5000/random"
AUTH_KEY = "safe-key"  # Authorization key for requests
HEADERS = {"Content-Type": "application/json"}

# Log file paths
WRITE_LOG_FILE = "test_results/write_results_random.log"
READ_LOG_FILE = "test_results/read_results_random.log"

# Ensure log files are clean before starting
os.makedirs("test_results", exist_ok=True)  # Ensure the directory exists
if os.path.exists(WRITE_LOG_FILE):
    os.remove(WRITE_LOG_FILE)
if os.path.exists(READ_LOG_FILE):
    os.remove(READ_LOG_FILE)

# Function to send a write request
def send_write_request(id):
    # Insert into the Sakila `actor` table with a unique first name
    first_name = f"Test_{id}"
    last_name = f"Andersson_{id}"
    write_query = f"INSERT INTO actor (first_name, last_name) VALUES ('{first_name}', '{last_name}')"

    payload = {
        "auth_key": AUTH_KEY,
        "operation": "write",
        "query": write_query,
        "message": "Hello from custom"
    }

    try:
        response = requests.post(URL, headers=HEADERS, json=payload)
        response.raise_for_status()
        result = f"WRITE SUCCESS: {id} - {response.status_code} - {response.json()}"
    except Exception as e:
        result = f"WRITE ERROR: {id} - {e}"
    # Write result to file
    with open(WRITE_LOG_FILE, "a") as f:
        f.write(result + "\n")
    return id, result

# Function to send a read request
def send_read_request(id):
    # Read the actor entry corresponding to the unique first name
    first_name = f"Test_{id}"
    read_query = f"SELECT * FROM actor WHERE first_name = '{first_name}'"

    payload = {
        "auth_key": AUTH_KEY,
        "operation": "read",
        "query": read_query,
        "message": "Hello from custom"
    }

    try:
        response = requests.post(URL, headers=HEADERS, json=payload)
        response.raise_for_status()
        result = f"READ SUCCESS: {id} - {response.status_code} - {response.json()}"
    except Exception as e:
        result = f"READ ERROR: {id} - {e}"
    # Write result to file
    with open(READ_LOG_FILE, "a") as f:
        f.write(result + "\n")
    return id, result

# Main function to send 1000 write and read requests
def main():
    num_requests = 1000

    # Generate IDs for tracking
    ids = list(range(1, num_requests + 1))  # IDs from 1 to 1000

    # Using a thread pool for concurrency
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        # Submit write requests
        write_futures = {executor.submit(send_write_request, i): i for i in ids}
        write_results = {}

        for future in concurrent.futures.as_completed(write_futures):
            id, result = future.result()
            write_results[id] = result
            print(result)

        # Submit read requests only for successful writes
        read_futures = {executor.submit(send_read_request, id): id for id in write_results.keys()}
        for future in concurrent.futures.as_completed(read_futures):
            id, result = future.result()
            print(result)

if __name__ == "__main__":
    main()
