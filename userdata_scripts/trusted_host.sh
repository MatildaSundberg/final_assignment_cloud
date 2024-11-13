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
import os

app = FastAPI()

PROXY_PRIVATE_IP = os.getenv("PROXY_PRIVATE_IP")
PROXY_URL = "http://$PROXY_PRIVATE_IP:5002/receive"

@app.post("/receive")
async def receive_message(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    # Forward the message to Proxy
    response = requests.post(PROXY_URL, json=data)
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to forward message")

    return {"status": "Message forwarded successfully"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5001)
EOF

# Install screen to run the app in the background
sudo apt install -y screen

# Run the Trusted Host FastAPI app with Uvicorn in a detached screen session
screen -dmS trusted_host uvicorn /home/ubuntu/trusted_host:app --host 0.0.0.0 --port 5001
