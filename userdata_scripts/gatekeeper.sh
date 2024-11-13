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
import os

app = FastAPI()

TRUSTED_HOST_PRIVATE_IP = os.getenv("TRUSTED_HOST_PRIVATE_IP")

TRUSTED_HOST_URL = "http://$TRUSTED_HOST_PRIVATE_IP:5001/receive"

@app.post("/send")
async def send_message(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    if data["message"] != "hej":
        raise HTTPException(status_code=400, detail="Invalid message content")

    response = requests.post(TRUSTED_HOST_URL, json=data)
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to send message")

    return {"status": "Message sent successfully"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
EOF

# Install screen to run the app in the background
sudo apt install -y screen

# Run the Gatekeeper FastAPI app with Uvicorn in a detached screen session
screen -dmS gatekeeper uvicorn home/ubuntu/gatekeeper:app --host 0.0.0.0 --port 5000
# no hup uvicorn home/ubuntu/gatekeeper:app --host??