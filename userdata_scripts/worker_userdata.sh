#!/bin/bash

# Update package list and install MySQL
echo "Updating package list and installing MySQL server..."
sudo apt update -y
sudo apt install -y mysql-server python3-pip

# Install FastAPI, Uvicorn, and Requests with permission to override the restriction
sudo pip3 install fastapi uvicorn requests mysql-connector-python --break-system-packages

sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation
MYSQL_ROOT_PASSWORD="12345hej"
echo "Securing MySQL installation..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$MYSQL_ROOT_PASSWORD';"
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

# Configure MySQL as a replication slave
echo "Configuring MySQL as a replica..."
RANDOM_SERVER_ID=$((RANDOM + 1))
sudo sed -i '/bind-address/d' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i "/\[mysqld\]/a bind-address = 0.0.0.0\nlog_bin = /var/log/mysql/mysql-bin.log\nserver-id = $RANDOM_SERVER_ID\nbinlog_do_db = sakila" /etc/mysql/mysql.conf.d/mysqld.cnf

# Restart MySQL to apply configuration changes
sudo systemctl restart mysql

# Download and set up the Sakila database
echo "Downloading and installing Sakila sample database..."
wget https://downloads.mysql.com/docs/sakila-db.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download Sakila database. Exiting..."
    exit 1
fi

tar -xvf sakila-db.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to extract Sakila database. Exiting..."
    exit 1
fi

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" < sakila-db/sakila-schema.sql
if [ $? -ne 0 ]; then
    echo "Failed to import Sakila schema. Exiting..."
    exit 1
fi

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" < sakila-db/sakila-data.sql
if [ $? -ne 0 ]; then
    echo "Failed to import Sakila data. Exiting..."
    exit 1
fi

rm -rf sakila-db.tar.gz sakila-db

# Check if MySQL restarted successfully
if ! sudo systemctl is-active --quiet mysql; then
    echo "MySQL failed to restart. Exiting..."
    exit 1
fi

# Set up replication from the master
REPLICATION_USER="replicator"
REPLICATION_PASSWORD="12345hi"

# Start replication
echo "Starting replication..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CHANGE MASTER TO MASTER_HOST='$MANAGER_IP', MASTER_USER='$REPLICATION_USER', MASTER_PASSWORD='$REPLICATION_PASSWORD', MASTER_LOG_FILE='$MASTER_LOG_FILE', MASTER_LOG_POS=$MASTER_LOG_POS;"
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "START SLAVE;"

# Confirm replication status
echo "Checking replication status..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G"

# Write the FastAPI application to manager.py in the current directory
cat << EOF > /home/ubuntu/worker.py
from fastapi import FastAPI, HTTPException
import uvicorn
import mysql.connector
from mysql.connector import Error
import json
import requests

app = FastAPI()

db_config = {
    "host": "localhost",
    "user": "root",
    "password": "$MYSQL_ROOT_PASSWORD",
    "database": "sakila"
}

def get_db_connection():
    try:
        connection = mysql.connector.connect(**db_config)
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

@app.post("/read")
async def read_operation(data: dict):
    if "query" not in data:
        raise HTTPException(status_code=400, detail="Invalid request: 'query' is required")

    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection error")

    try:
        cursor = connection.cursor(dictionary=True)
        # Execute the read query from the request
        cursor.execute(data["query"])
        results = cursor.fetchall()
        return {"status": "success", "data": results}
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Database query error: {e}")
    finally:
        cursor.close()
        connection.close()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5003)
EOF