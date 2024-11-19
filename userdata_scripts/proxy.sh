#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip

# Install FastAPI, Uvicorn, and Requests with permission to override restrictions
sudo pip3 install fastapi uvicorn requests --break-system-packages

# Create the Proxy FastAPI app in /home/ubuntu
cat << EOF > /home/ubuntu/proxy.py
from fastapi import FastAPI, HTTPException
import requests
import json
import uvicorn
import random
import subprocess  # Added import

# Load Manager IP address from config.json
with open('config.json') as config_file:
    config = json.load(config_file)

manager_private_ip = config.get("MANAGER_PRIVATE_IP")
worker_1_private_ip = config.get("WORKER_1_PRIVATE_IP")
worker_2_private_ip = config.get("WORKER_2_PRIVATE_IP")

def ping_server(ip_address):
    try:
        # Run the ping command with 1 packet and capture the output
        ping_response = subprocess.run(
            ["ping", "-c", "1", ip_address],
            capture_output=True,
            text=True,
            timeout=2
        )
        
        # Extract and parse the time value from the output
        if ping_response.returncode == 0:
            # Find the "time=" portion in the output and extract the latency in ms
            output = ping_response.stdout
            latency = float(output.split("time=")[-1].split(" ")[0])
            return latency
        else:
            return float('inf')  # Return infinity if the ping fails
    except subprocess.TimeoutExpired:
        return float('inf')  # Return infinity if the ping times out

app = FastAPI()

@app.post("/directhit")
async def direct_hit(data: dict):

    operation = data.get("operation")
    # Determine whether to send to Manager's read or write endpoint
    try:
        if operation == "read":
            response = requests.post(f"http://{manager_private_ip}:5003/read", json=data)
        elif operation == "write":
            response = requests.post(f"http://{manager_private_ip}:5003/write", json=data)
        else:
            print(f"Invalid operation type: {operation}")
            raise HTTPException(status_code=400, detail="Invalid operation type")

        response.raise_for_status()
        print(response.json())
        return {f"{operation} from Manager": response.json()}
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Failed to forward request to Manager: {e}")

@app.post("/random")
async def random_request(data: dict):
    # Check for a valid message and query in the request
    if "message" not in data or "query" not in data:
        raise HTTPException(status_code=400, detail="Invalid request: 'message' and 'query' are required")
    
    operation = data.get("operation")

    if operation == "write":
        # Forward the write request
        try:
            response = requests.post(f"http://{manager_private_ip}:5003/write", json=data)
            response.raise_for_status()
            return {"write": response.json()}
        except requests.exceptions.RequestException as e:
            raise HTTPException(status_code=500, detail=f"Failed to forward request to Worker: {e}")
    elif operation == "read":
        # Randomly select between worker_1 and worker_2
        selected_worker_ip = random.choice([worker_1_private_ip, worker_2_private_ip])

        selected_worker = "Worker 1" if selected_worker_ip == worker_1_private_ip else "Worker 2"

        # Forward the read request to the selected worker
        try:
            response = requests.post(f"http://{selected_worker_ip}:5003/read", json=data)
            response.raise_for_status()
            return {f"Read from {selected_worker}": response.json()}
        except requests.exceptions.RequestException as e:
            raise HTTPException(status_code=500, detail=f"Failed to forward request to Worker: {e}")

@app.post("/custom")
async def custom_request(data: dict):
    # Prepare the data payload
    payload = {"type": "custom", **data}

    operation = data.get("operation")

    if operation == "write":
        # Forward the write request
        try:
            response = requests.post(f"http://{manager_private_ip}:5003/write", json=payload)
            response.raise_for_status()
            return {"write": response.json()}
        except requests.RequestException as e:
            raise HTTPException(status_code=500, detail=f"Failed to forward request to Worker: {e}")

    elif operation == "read":
        # Ping each worker to measure latency
        worker_latencies = {
            worker_1_private_ip: ping_server(worker_1_private_ip),
            worker_2_private_ip: ping_server(worker_2_private_ip)
        }
        
        # Select the worker with the lowest latency
        best_worker_ip = min(worker_latencies, key=worker_latencies.get)

        if best_worker_ip == float('inf'):
            raise HTTPException(status_code=500, detail="All workers are down")
        
        selected_worker = "Worker 1" if best_worker_ip == worker_1_private_ip else "Worker 2"

        # Forward the request to the worker with the lowest latency
        try:
            response = requests.post(f"http://{best_worker_ip}:5003/read", json=payload)
            response.raise_for_status()
            return {f"Read from {selected_worker} ": response.json()}
        except requests.RequestException as e:
            raise HTTPException(status_code=500, detail=f"Failed to forward request to Worker: {e}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5002)
EOF
