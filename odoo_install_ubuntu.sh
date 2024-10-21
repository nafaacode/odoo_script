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


INSTALL_NGINX="False"  # Set to True if you want to install Nginx
WEBSITE_NAME="_"  # Set the domain name
ENABLE_SSL="False"  # Enable SSL
ADMIN_EMAIL="odoo@example.com"  # Email for SSL registration
POSTGRES_VERSION="14"  # Choose the PostgreSQL version
INSTALL_POSTGRESQL_FOURTEEN="True"  # Install PostgreSQL V14

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
sudo apt-get install -y postgresql-$POSTGRES_VERSION

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

# Restart services using outdated libraries todo: check if necessary
echo -e "\n---- Install Python virtual environment and set up the Odoo environment ----"
sudo systemctl restart packagekit.service
sudo systemctl restart polkit.service
sudo systemctl restart systemd-journald.service
sudo systemctl restart systemd-networkd.service
sudo systemctl restart systemd-resolved.service
sudo systemctl restart systemd-timesyncd.service
sudo systemctl restart systemd-udevd.service

# Install Python virtual environment and set up the Odoo environment
echo -e "\n---- Install Python virtual environment and set up the Odoo environment ----"
sudo apt install -y python3-venv
sudo python3 -m venv $OE_HOME_EXT/venv

# Activate the virtual environment and install required Python packages
echo -e "\n---- Activate the virtual environment and install required Python packages ----"
cd $OE_HOME_EXT/
source $OE_HOME_EXT/venv/bin/activate
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

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an official Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries in virtual environment ----"
    pip install psycopg2-binary pdfminer.six num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
fi

deactivate

echo -e "\n---- Create custom addons directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "\n---- Configure the Odoo instance ----"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

# Configure the Odoo instance
sudo cp $OE_HOME_EXT/debian/odoo.conf /etc/${OE_CONFIG}.conf
sudo bash -c "cat << EOF > /etc/${OE_CONFIG}.conf
[options]
; This is the configuration file for Odoo
; You can customize the configuration options as needed
; You can find more options in the Odoo documentation
addons_path = ${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons,${OE_HOME}/enterprise/addons
admin_passwd = $OE_SUPERADMIN
dbfilter = ^%d
http_port = ${OE_PORT}
longpolling_port = ${LONGPOLLING_PORT}
workers = 0
limit_memory_hard = 26843545600
limit_memory_soft = 21474836480
max_cron_threads = 2
logfile = /var/log/odoo/odoo.log
logrotate = True
; PostgreSQL settings
db_user = $OE_USER
db_password = $DB_PASSWD
db_host = False
db_port = 5432
db_sslmode = require  # Enable SSL for PostgreSQL
EOF"

# Create the log directory and set permissions
echo -e "\n---- Creating log directory and setting permissions ----"
sudo mkdir /var/log/odoo
sudo chown $OE_USER:$OE_USER /var/log/odoo

# Install and configure Nginx
if [ "$INSTALL_NGINX" = "True" ]; then
    echo -e "\n---- Install and configure Nginx ----"
    sudo apt-get install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx

    # Nginx configuration
    sudo bash -c "cat << EOF > /etc/nginx/sites-available/$WEBSITE_NAME
server {
    listen 80;
    server_name $WEBSITE_NAME;

    location / {
        proxy_pass http://127.0.0.1:${OE_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

EOF"

    sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/
    sudo systemctl restart nginx
fi

# Start the Odoo service
echo -e "\n---- Start the Odoo service ----"
sudo cp $OE_HOME_EXT/debian/odoo.service /etc/systemd/system/${OE_CONFIG}.service
sudo systemctl restart ${OE_CONFIG}
sudo systemctl enable ${OE_CONFIG}

echo -e "\n---- Odoo has been successfully installed and started! ----"
echo -e "You can access it at http://<your_domain_or_IP>:${OE_PORT}/"
echo -e "Your admin password is: $OE_SUPERADMIN"
