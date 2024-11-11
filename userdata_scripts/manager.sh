#!/bin/bash

# Update package list and install MySQL
echo "Updating package list and installing MySQL server..."
sudo apt update -y
sudo apt install -y mysql-server python3-pip

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
