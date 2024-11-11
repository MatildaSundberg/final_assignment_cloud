#!/bin/bash

# Update package list and install MySQL
echo "Updating package list and installing MySQL server..."
sudo apt update -y
sudo apt install -y mysql-server python3-pip

sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation
MYSQL_ROOT_PASSWORD="12345hej"  # Set your root password
echo "Securing MySQL installation..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$MYSQL_ROOT_PASSWORD';"
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

# Configure MySQL as a replication slave
echo "Configuring MySQL as a replica..."
sudo sed -i '/bind-address/d' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/\[mysqld\]/a bind-address = 0.0.0.0\nlog_bin = /var/log/mysql/mysql-bin.log\nserver-id = 2\nbinlog_do_db = sakila' /etc/mysql/mysql.conf.d/mysqld.cnf #TODO: change server-id to random number 

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
