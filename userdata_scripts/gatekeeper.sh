#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip

# Install FastAPI, Uvicorn, and Requests with permission to override the restriction
sudo pip3 install fastapi uvicorn requests --break-system-packages


# Write the FastAPI application to gatekeeper.py in the current directory
cat << EOF > /home/ubuntu/gatekeeper.py
from fastapi import FastAPI, HTTPException
import requests
import uvicorn
import json

# Load configuration from config.json
with open('config.json') as config_file:
    config = json.load(config_file)

trusted_host_private_ip = config.get("TRUSTED_HOST_PRIVATE_IP")
print("trusted_host_private_ip: ", trusted_host_private_ip)

app = FastAPI()

# Define acceptable operations
VALID_OPERATIONS = {"read", "write"}

def validate_request(data: dict):
    """Basic validation: Check for 'auth_key','query', and 'operation' in the request."""
    if data.get("auth_key") != "safe-key":
        raise HTTPException(status_code=400, detail="Invalid or missing 'auth_key'")

    # Check for the presence of an SQL query
    if "query" not in data:
        raise HTTPException(status_code=400, detail="Missing 'query' in the request data")

    # Validate operation
    operation = data.get("operation")
    if operation not in VALID_OPERATIONS:
        raise HTTPException(status_code=400, detail=f"Invalid operation: '{operation}'. Expected 'read' or 'write'")

    return True

@app.post("/directhit")
async def direct_hit(data: dict):
    validate_request(data)  # Validate the incoming request
    response = requests.post(f"http://{trusted_host_private_ip}:5001/directhit", json={"type": "directhit", **data})
    if response.status_code != 200:
        print(response.text)
        raise HTTPException(status_code=response.status_code, detail="Failed to send direct hit message")
    return response.json()

@app.post("/random")
async def random_request(data: dict):
    validate_request(data)  # Validate the incoming request
    response = requests.post(f"http://{trusted_host_private_ip}:5001/random", json={"type": "random", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to send random request")
    return response.json()

@app.post("/custom")
async def custom_request(data: dict):
    validate_request(data)  # Validate the incoming request
    response = requests.post(f"http://{trusted_host_private_ip}:5001/custom", json={"type": "custom", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to send custom request")
    return response.json()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
EOF