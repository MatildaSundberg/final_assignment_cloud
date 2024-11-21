
import requests
import concurrent.futures
import uuid
import os
from utils import util_functions as u

# Get the IP addresses of the Gatekeeper instance
gatekeeper_private_ip, gatekeeper_public_ip = u.get_instance_ips('Gatekeeper')

# Configuration
URL = f"http://{gatekeeper_public_ip}:5000/directhit"  # Replace with actual Gatekeeper URL
AUTH_KEY = "safe-key"  # Authorization key for requests
HEADERS = {"Content-Type": "application/json"}

# Log file paths
WRITE_LOG_FILE = "test_results/write_results_directhit.log"
READ_LOG_FILE = "test_results/read_results_directhit.log"

# Ensure log files are clean before starting
if os.path.exists(WRITE_LOG_FILE):
    os.remove(WRITE_LOG_FILE)
if os.path.exists(READ_LOG_FILE):
    os.remove(READ_LOG_FILE)

# Function to send a write request
def send_write_request(unique_id):
    # Insert into the Sakila `actor` table with a unique first name
    first_name = f"John_{unique_id[:8]}"  # Using only first 8 characters for brevity
    last_name = f"Doe_{unique_id[:8]}"
    write_query = f"INSERT INTO actor (first_name, last_name) VALUES ('{first_name}', '{last_name}')"

    payload = {
        "auth_key": AUTH_KEY,
        "operation": "write",
        "query": write_query
    }

    try:
        response = requests.post(URL, headers=HEADERS, json=payload)
        response.raise_for_status()
        result = f"WRITE SUCCESS: {unique_id} - {response.status_code} - {response.json()}"
    except Exception as e:
        result = f"WRITE ERROR: {unique_id} - {e}"
    # Write result to file
    with open(WRITE_LOG_FILE, "a") as f:
        f.write(result + "\n")
    return unique_id, result

# Function to send a read request
def send_read_request(unique_id):
    # Read the actor entry corresponding to the unique first name
    first_name = f"John_{unique_id[:8]}"
    read_query = f"SELECT * FROM actor WHERE first_name = '{first_name}'"

    payload = {
        "auth_key": AUTH_KEY,
        "operation": "read",
        "query": read_query
    }

    try:
        response = requests.post(URL, headers=HEADERS, json=payload)
        response.raise_for_status()
        result = f"READ SUCCESS: {unique_id} - {response.status_code} - {response.json()}"
    except Exception as e:
        result = f"READ ERROR: {unique_id} - {e}"
    # Write result to file
    with open(READ_LOG_FILE, "a") as f:
        f.write(result + "\n")
    return unique_id, result

# Main function to send 1000 write and read requests
def main():
    num_requests = 1000

    # Generate unique IDs for tracking
    unique_ids = [str(uuid.uuid4()) for _ in range(num_requests)]

    # Using a thread pool for concurrency
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        # Submit write requests
        write_futures = {executor.submit(send_write_request, uid): uid for uid in unique_ids}
        write_results = {}

        for future in concurrent.futures.as_completed(write_futures):
            unique_id, result = future.result()
            write_results[unique_id] = result
            print(result)

        # Submit read requests only for successful writes
        read_futures = {executor.submit(send_read_request, uid): uid for uid in write_results.keys()}
        for future in concurrent.futures.as_completed(read_futures):
            unique_id, result = future.result()
            print(result)

if __name__ == "__main__":
    main()
