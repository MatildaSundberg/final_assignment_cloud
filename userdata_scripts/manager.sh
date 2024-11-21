#!/bin/bash

# Update package list and install MySQL
echo "Updating package list and installing MySQL server..."
sudo apt update -y
sudo apt install -y mysql-server python3-pip
sudo apt-get update


# Start and enable MySQL service
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

# Create a replication user
REPLICATION_USER="replicator"
REPLICATION_PASSWORD="12345hi"

echo "Creating replication user..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER '$REPLICATION_USER'@'%' IDENTIFIED WITH 'mysql_native_password' BY '$REPLICATION_PASSWORD';"
if [ $? -ne 0 ]; then
    exit 1
fi

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT REPLICATION SLAVE ON *.* TO '$REPLICATION_USER'@'%';"
if [ $? -ne 0 ]; then
    exit 1
fi

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
if [ $? -ne 0 ]; then
    exit 1
fi


# Enable MySQL binary logging for replication
echo "Configuring MySQL for replication..."
sudo sed -i '/bind-address/d' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/\[mysqld\]/a bind-address = 0.0.0.0\nlog_bin = /var/log/mysql/mysql-bin.log\nserver-id = 1\nbinlog_do_db = sakila' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

# Check if MySQL restarted successfully
if ! sudo systemctl is-active --quiet mysql; then
    exit 1
fi

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

echo "Setup completed successfully."

# Write the FastAPI application to manager.py in the current directory
cat << EOF > /home/ubuntu/manager.py
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

# Load IP address from config.json
with open('config.json') as config_file:
    config = json.load(config_file)

WORKER_1_PRIVATE_IP = config.get("WORKER_1_PRIVATE_IP")
WORKER_2_PRIVATE_IP = config.get("WORKER_2_PRIVATE_IP")

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
        print(results)
        return {"status": "success", "data": results}
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Database query error: {e}")
    finally:
        cursor.close()
        connection.close()

@app.post("/write")
async def write_operation(data: dict):
    if "query" not in data:
        raise HTTPException(status_code=400, detail="Invalid request: 'query' is required")

    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection error")

    try:
        cursor = connection.cursor()
        # Execute the write query from the request
        cursor.execute(data["query"])
        connection.commit()
        return {"status": "success", "data": "Write operation completed"}
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Database write error: {e}")
    finally:
        cursor.close()
        connection.close()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5003)
EOF

sudo apt-get install -y sysbench

echo "Preparing the Sakila database for benchmarking..."
sudo sysbench /usr/share/sysbench/oltp_read_only.lua \
  --mysql-db=sakila \
  --mysql-user=root \
  --mysql-password=$MYSQL_ROOT_PASSWORD \
  prepare
if [ $? -ne 0 ]; then
    echo "Sysbench preparation failed. Exiting..."
    exit 1
fi
