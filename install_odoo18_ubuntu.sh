#!/bin/bash

################################################################################
# Script for installing Odoo on 
#  Ubuntu   
# Author: Nafaa Z
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu server.  
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano install_odoo18_ubuntu.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_odoo18_ubuntu.sh
# Execute the script to install Odoo:
# ./install_odoo18_ubuntu.sh
################################################################################

### VARIABLES ###
OE_VERSION="18.0"  # Choose the Odoo version
DOMAIN_NAME="_"  # Set the domain name
INSTALL_POSTGRESQL_FOURTEEN="True"  # Install PostgreSQL V14
INSTALL_NGINX="False"  # Set to True if you want to install Nginx
MAJOR_VERSION=${OE_VERSION%%.*}
OE_USER="odoo${MAJOR_VERSION}"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="$OE_HOME/${OE_USER}-server"
INSTALL_WKHTMLTOPDF="True"  # Set to true if you want to install Wkhtmltopdf
OE_PORT="8069"  # Default Odoo port
IS_ENTERPRISE="False"  # Set to True if you want to install the Odoo enterprise version
OE_SUPERADMIN="admin"  # Superadmin password
DB_PASSWORD="123456" # for db_password
GENERATE_RANDOM_PASSWORD="True"  # Generate random password
OE_CONFIG="${OE_USER}"  # Odoo config name
LONGPOLLING_PORT="8072"  # Default longpolling port
ENABLE_SSL="False"  # Enable SSL
ADMIN_EMAIL="odoo@example.com"  # Email for SSL registration

# Get the Ubuntu version
version=$(lsb_release -rs)

# Check Ubuntu version
if [[ "$version" =~ ^(16.04|18.04|20.04|22.04|24.04)$ ]]; then
    echo -e "Run script on Ubuntu $version." 
else
    echo -e "\n--------"
    echo -e "ERROR: Not a supported version => exit"
    exit 1
fi

# Update and upgrade the system
echo -e "\n---- Update and upgrade the system ----"
sudo apt-get update
sudo apt-get upgrade -y

# Install Python 3 pip and other essential Python development libraries
echo -e "\n---- Install Python 3 pip and other essential Python development libraries ----"
sudo apt-get install -y python3-pip python3-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev

# Create a symbolic link for Node.js and install Less and Less plugins
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less
 
# Install PostgreSQL and create a new user for Odoo
if [ "$GENERATE_RANDOM_PASSWORD" = "True" ]; then
    echo -e "\n---- Generating random db password ----"
    DB_PASSWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

# Create the .pgpass file
echo -e "\n---- Setting up .pgpass file ----"
PGPASSFILE="$HOME/.pgpass"
echo "localhost:5432:*:$OE_USER:$DB_PASSWD" > $PGPASSFILE
chmod 600 $PGPASSFILE

# Install PostgreSQL
echo -e "\n---- Install PostgreSQL and create a new user for Odoo ----"
sudo apt-get install -y postgresql

# Create the user with the generated or fixed password
sudo -u postgres createuser --createdb --no-createrole --superuser $OE_USER
sudo -u postgres psql -c "ALTER USER $OE_USER WITH PASSWORD '$DB_PASSWD';"

# Check if the user exists
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$OE_USER'" | grep -q 1; then
    echo -e "\n---- New user PostgreSQL for Odoo created ----"
fi

# Create a system user for Odoo and install Git to clone the Odoo source code
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

sudo apt-get install -y git

echo -e "\n==== Installing ODOO Server with user $OE_USER ===="
sudo su - $OE_USER -c "git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/"

# Install Python virtual environment and set up the Odoo environment
echo -e "\n---- Install Python virtual environment and set up the Odoo environment ----"
sudo apt install -y python3-venv
sudo python3 -m venv $OE_HOME_EXT/venv

# Restart services using outdated libraries
echo -e "\n---- Install Python virtual environment and set up the Odoo environment ----"
sudo systemctl restart packagekit.service
sudo systemctl restart polkit.service
sudo systemctl restart ssh.service
sudo systemctl restart systemd-journald.service
sudo systemctl restart systemd-networkd.service
sudo systemctl restart systemd-resolved.service
sudo systemctl restart systemd-timesyncd.service
sudo systemctl restart systemd-udevd.service


# Activate the virtual environment and install required Python packages
echo -e "\n---- Activate the virtual environment and install required Python packages ----"
cd $OE_HOME_EXT/
source venv/bin/activate
pip install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

# Install wkhtmltopdf and resolve any missing dependencies
if [ "$INSTALL_WKHTMLTOPDF" = "True" ]; then
    sudo wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb
    sudo wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
    sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
    sudo apt-get install -y xfonts-75dpi
    sudo dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb
    sudo apt install -f -y
fi
 
deactivate

echo -e "\n---- Configure the Odoo instance ----"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
# Configure the Odoo instance
sudo cp $OE_HOME_EXT/debian/odoo.conf /etc/${OE_CONFIG}.conf
sudo bash -c "cat << EOF > /etc/${OE_CONFIG}.conf
[options]
; This is the password that allows database operations:
admin_passwd = $OE_SUPERADMIN
db_host = localhost
db_port = 5432
db_user = $OE_USER
db_password = $DB_PASSWD
addons_path = $OE_HOME_EXT/addons
default_productivity_apps = True
logfile = /var/log/odoo/${OE_CONFIG}.log
EOF"

echo -e "\n---- Set correct permissions on the Odoo configuration file ----"
# Set correct permissions on the Odoo configuration file
sudo chown $OE_USER: /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

# Create a directory for Odoo log files and set appropriate ownership
sudo mkdir /var/log/odoo
sudo chown $OE_USER:root /var/log/odoo

echo -e "\n---- Create a systemd service file for Odoo ----"
# Create a systemd service file for Odoo
sudo bash -c "cat << EOF > /etc/systemd/system/${OE_CONFIG}.service
[Unit]
Description=Odoo
Documentation=http://www.odoo.com

[Service]
Type=simple
User=$OE_USER
ExecStart=$OE_HOME_EXT/venv/bin/python3 $OE_HOME_EXT/odoo-bin -c /etc/${OE_CONFIG}.conf

[Install]
WantedBy=default.target
EOF"

# Set permissions and ownership on the systemd service file
sudo chmod 755 /etc/systemd/system/${OE_CONFIG}.service
sudo chown root: /etc/systemd/system/${OE_CONFIG}.service



if ss -tuln | grep -q ':$OE_PORT'; then
  echo "Odoo ${OE_VERSION} installation completed. Access Odoo from your browser at http://your_IP_address:${OE_PORT}"
else
  echo "Odoo failed to start or is not listening on port: $OE_PORT"
fi

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable ${OE_CONFIG}.service

# Start the Odoo service
echo -e "\n---- Start the Odoo service ----"
sudo systemctl start ${OE_CONFIG}.service

sleep 5

# Check the status of the Odoo service
if ! sudo systemctl status ${OE_CONFIG}.service | grep -q "running"; then
    echo "Odoo failed to start. Check the logs for more details."
    exit 1
fi


# Final check for listening port
if ss -tuln | grep -q ":$OE_PORT"; then
  echo "Odoo ${OE_VERSION} installation completed. Access Odoo from your browser at http://your_IP_address:${OE_PORT}"
else
  echo "Odoo failed to start or is not listening on port: $OE_PORT"
  exit 1
fi
