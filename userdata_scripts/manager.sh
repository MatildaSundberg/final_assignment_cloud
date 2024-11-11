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
#sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
#sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';"
#sudo mysql -e "DROP DATABASE IF EXISTS test;"
#sudo mysql -e "FLUSH PRIVILEGES;"

# Enable MySQL binary logging for replication
echo "Configuring MySQL for replication..."
sudo sed -i '/\[mysqld\]/a bind-address = 0.0.0.0\nlog_bin = /var/log/mysql/mysql-bin.log\nserver-id = 1\nbinlog_do_db = sakila' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

# Check if MySQL restarted successfully
if ! sudo systemctl is-active --quiet mysql; then
    echo "MySQL failed to restart. Exiting..."
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

#rm -rf sakila-db.tar.gz sakila-db

# Create a replication user
echo "Creating replication user..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'replicator'@'%' IDENTIFIED WITH 'mysql_native_password' BY '12345hi';"
if [ $? -ne 0 ]; then
    echo "Failed to create replication user. Exiting..."
    exit 1
fi

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';"
if [ $? -ne 0 ]; then
    echo "Failed to grant replication privileges. Exiting..."
    exit 1
fi

sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
if [ $? -ne 0 ]; then
    echo "Failed to flush privileges. Exiting..."
    exit 1
fi


echo "Setup completed successfully."
