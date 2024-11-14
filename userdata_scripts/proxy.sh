#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip

# Install FastAPI and Uvicorn
sudo pip3 install fastapi uvicorn requests --break-system-packages


# Create the Proxy FastAPI app in /home/ubuntu
cat << EOF > /home/ubuntu/proxy.py
from fastapi import FastAPI, HTTPException
import requests
import uvicorn
import json

# Load configuration from config.json
#with open('config.json') as config_file:
#config = json.load(config_file)

app = FastAPI()

@app.post("/receive")
async def receive_message(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    # Respond back with a confirmation
    return {"response": "Message received by Proxy", "original_message": data["message"]}

@app.post("/directhit")
async def direct_hit(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    # Respond back with a confirmation
    return {"response": "Direct hit message received by Proxy", "original_message": data["message"]}

@app.post("/random")
async def random_request(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    # Respond back with a confirmation
    return {"response": "Random message received by Proxy", "original_message": data["message"]}

@app.post("/custom")
async def custom_request(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    # Respond back with a confirmation
    return {"response": "Custom message received by Proxy", "original_message": data["message"]}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5002)
EOF
