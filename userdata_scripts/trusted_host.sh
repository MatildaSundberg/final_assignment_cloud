#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip

# Install FastAPI, Uvicorn, and Requests with permission to override restrictions
sudo pip3 install fastapi uvicorn requests --break-system-packages


# Create the Trusted Host FastAPI app in the current directory as trusted_host.py
cat << EOF > /home/ubuntu/trusted_host.py
from fastapi import FastAPI, HTTPException
import requests
import uvicorn
import json

# Load configuration from config.json
with open('config.json') as config_file:
    config = json.load(config_file)

proxy_private_ip = config.get("PROXY_PRIVATE_IP")

app = FastAPI()

@app.post("/receive")
async def receive_message(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    # Forward the message to Proxy
    response = requests.post(f"http://{proxy_private_ip}:5002/receive", json=data)
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to forward message")
    return {"status": "Message forwarded successfully"}

@app.post("/directhit")
async def direct_hit(data: dict):
    validate_request(data)
    response = requests.post(f"http://{proxy_private_ip}:5002/directhit", json={"type": "directhit", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to forward direct hit to Proxy")
    return {"status": "Direct hit request forwarded to Proxy"}

@app.post("/random")
async def random_request(data: dict):
    validate_request(data)
    response = requests.post(f"http://{proxy_private_ip}:5002/random", json={"type": "random", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to forward random request to Proxy")
    return {"status": "Random request forwarded to Proxy"}

@app.post("/custom")
async def custom_request(data: dict):
    validate_request(data)
    response = requests.post(f"http://{proxy_private_ip}:5002/random", json={"type": "custom", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to forward custom request to Proxy")
    return {"status": "Custom request forwarded to Proxy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5001)
EOF
