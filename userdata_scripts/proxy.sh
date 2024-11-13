#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip

# Install FastAPI and Uvicorn
sudo pip3 install fastapi uvicorn

# Create the Proxy FastAPI app in /home/ubuntu
cat << EOF > /home/ubuntu/proxy.py
from fastapi import FastAPI, HTTPException
import uvicorn
import requests

app = FastAPI()

@app.post("/receive")
async def receive_message(data: dict):
    if "message" not in data:
        raise HTTPException(status_code=400, detail="Invalid message")

    # Respond back with a confirmation
    return {"response": "Message received by Proxy", "original_message": data["message"]}
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5002)
EOF

# Install screen to run the app in the background
sudo apt install -y screen

# Run the Proxy FastAPI app with Uvicorn in a detached screen session
screen -dmS proxy uvicorn /home/ubuntu/proxy:app --host 0.0.0.0 --port 5002
