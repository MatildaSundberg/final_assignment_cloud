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
TRUSTED_HOST_URL = f"http://{trusted_host_private_ip}:5001/receive"

app = FastAPI()

def validate_request(data: dict):
    """Basic validation: Check for an 'auth_key' with value 'safe-key'."""
    if data.get("auth_key") != "safe-key":
        raise HTTPException(status_code=400, detail="Invalid or missing 'auth_key'")
    return True

@app.post("/send")
async def send_message(data: dict):
    validate_request(data)  # Validate the incoming request
    response = requests.post(TRUSTED_HOST_URL, json=data)
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to send message")
    return {"status": "Message sent successfully"}

@app.post("/directhit")
async def direct_hit(data: dict):
    validate_request(data)  # Validate the incoming request
    response = requests.post(TRUSTED_HOST_URL, json={"type": "directhit", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to send direct hit message")
    return {"status": "Direct hit request sent successfully"}

@app.post("/random")
async def random_request(data: dict):
    validate_request(data)  # Validate the incoming request
    response = requests.post(TRUSTED_HOST_URL, json={"type": "random", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to send random request")
    return {"status": "Random request sent successfully"}

@app.post("/custom")
async def custom_request(data: dict):
    validate_request(data)  # Validate the incoming request
    response = requests.post(TRUSTED_HOST_URL, json={"type": "custom", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to send custom request")
    return {"status": "Custom request sent successfully"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
EOF