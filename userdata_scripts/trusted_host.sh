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

@app.post("/directhit")
async def direct_hit(data: dict):
    response = requests.post(f"http://{proxy_private_ip}:5002/directhit", json=data)
    if response.status_code != 200:
        print(response.text)
        raise HTTPException(status_code=response.status_code, detail="Failed to forward direct hit to Proxy")
    return response.json()

@app.post("/random")
async def random_request(data: dict):
    response = requests.post(f"http://{proxy_private_ip}:5002/random", json={"type": "random", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to forward random request to Proxy")
    return response.json()

@app.post("/custom")
async def custom_request(data: dict):
    response = requests.post(f"http://{proxy_private_ip}:5002/random", json={"type": "custom", **data})
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to forward custom request to Proxy")
    return response.json()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5001)
EOF
