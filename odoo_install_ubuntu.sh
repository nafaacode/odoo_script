#!/bin/bash
################################################################################
# Script for installing Odoo on 
#  Ubuntu 16.04, 18.04, 20.04, 22.04, 24.04  
# Author: Nafaa Z
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo_install_ubuntu.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo_install_ubuntu.sh
# Execute the script to install Odoo:
# ./odoo_install_ubuntu.sh
################################################################################

### VARIABLES ### 

OE_VERSION="17.0"  # Choose the Odoo version
DOMAIN_NAME="_"  # Set the domain name
INSTALL_POSTGRESQL_FOURTEEN="True"  # Install PostgreSQL V14
INSTALL_NGINX="False"  # Set to True if you want to install Nginx
MAJOR_VERSION=${OE_VERSION%%.*}
OE_USER="odoo${MAJOR_VERSION}"
OE_HOME="/home/$OE_USER"
OE_HOME_EXT="$OE_HOME/${OE_USER}-server"
INSTALL_WKHTMLTOPDF="True"  # Set to true if you want to install Wkhtmltopdf
OE_PORT="8069"  # Default Odoo port
IS_ENTERPRISE="False"  # Set to True if you want to install the Odoo enterprise version
OE_SUPERADMIN="admin"  # Superadmin password
GENERATE_RANDOM_PASSWORD="True"  # Generate random password
OE_CONFIG="${OE_USER}"  # Odoo config name
LONGPOLLING_PORT="8072"  # Default longpolling port
ENABLE_SSL="True"  # Enable SSL
ADMIN_EMAIL="odoo@example.com"  # Email for SSL registration

###   

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

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo add-apt-repository -y universe
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y libpq-dev

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
if [ "$INSTALL_POSTGRESQL_FOURTEEN" = "True" ]; then
    echo -e "\n---- Installing PostgreSQL V14 ----"
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt-get install -y postgresql-14
else
    echo -e "\n---- Installing the default PostgreSQL version ----"
    sudo apt-get install -y postgresql postgresql-server-dev-all
fi

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true
 
#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
if [[ "$version" =~ ^(18.04|20.04|22.04|24.04)$ ]]; then
    sudo add-apt-repository -y ppa:deadsnakes/ppa 
fi

sudo apt-get install -y python3 python3-pip python3.11
sudo apt-get install -y git python3-cffi build-essential wget python3-dev python3.11-dev libfreetype-dev libxml2-dev python3-venv python3.11-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi zlib1g-dev libpq-dev libxslt1-dev libtiff5-dev libopenjp2-7-dev libcap-dev
 
# Check pip3 installation
if ! PIP_VERSION=$(pip3 --version); then
    echo -e "ERROR: pip3 installation failed."
    exit 1
fi
echo "pip3 version : $PIP_VERSION"

# Check python3 version
if ! PYTHON_VERSION=$(python3 --version); then
    echo -e "\n--------"
    echo -e "ERROR: python3 installation failed."
    exit 1
fi

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ "$INSTALL_WKHTMLTOPDF" = "True" ]; then
    echo -e "\n---- Installing Wkhtmltopdf ----"
    if [[ "$version" == "22.04" || "$version" == "24.04" ]]; then
        sudo apt install -y wkhtmltopdf
    else
        # Download Wkhtmltopdf for older versions
        if [ "$(getconf LONG_BIT)" == "64" ]; then
            _url="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_amd64.deb"
        else
            _url="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_i386.deb"
        fi
        sudo gdebi --n "$(basename $_url)"
    fi
    sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
    sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
    echo "Wkhtmltopdf isn't installed due to user choice!"
fi

#--------------------------------------------------
# Create ODOO system user
#--------------------------------------------------
echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server with user $OE_USER ===="
sudo su - $OE_USER -c "rm -rf $OE_HOME_EXT/ && git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/"

# Create a Python virtual environment
sudo su - $OE_USER -c "python3.11 -m venv $OE_USER-venv"

sudo su - $OE_USER <<EOF

# create ans swith to Python virtual environment
source $OE_HOME/$OE_USER-venv/bin/activate
pip install wheel setuptools pip --upgrade
pip install psycopg2 python-ldap

echo -e "\n---- Install python packages/requirements ----"
pip install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Create custom module directory ----"
mkdir -p $OE_HOME/custom/addons

#close Python virtual environment
deactivate

EOF

if [ "$IS_ENTERPRISE" = "True" ]; then
    sudo su - $OE_USER -c "mkdir -p $OE_HOME/enterprise/addons"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo -H pip3 install psycopg2-binary pdfminer.six
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

#--------------------------------------------------
# Create Odoo config file
#--------------------------------------------------
echo -e "* Creating server config file"
sudo bash -c "cat > /etc/${OE_CONFIG}.conf" <<EOF
[options]
; This is the password that allows database operations:
admin_passwd = ${OE_SUPERADMIN}
http_port = ${OE_PORT}
logfile = /var/log/${OE_USER}/${OE_CONFIG}.log
addons_path = ${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons
EOF

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

#--------------------------------------------------
# Adding ODOO as a daemon
# /home/odoo17/odoo17-venv/bin/python3 /home/odoo17/odoo17-server/odoo-bin -c /etc/odoo17.conf
#--------------------------------------------------
echo -e "* Create init file"
cat <<EOF | sudo tee /etc/init.d/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
### END INIT INFO

USER=$OE_USER
HOME=$OE_HOME
PIDFILE=/var/run/\$USER/\$OE_CONFIG.pid
DAEMON=$OE_HOME/$OE_USER-venv/bin/python3
DAEMON_OPTS="$OE_HOME_EXT/odoo-bin -c /etc/$OE_CONFIG.conf"

test -d /var/run/\$USER || mkdir -p /var/run/\$USER
chown \$USER:\$USER /var/run/\$USER

case "\$1" in
  start)
    echo "Starting \$DAEMON ..."
    start-stop-daemon --start --quiet --pidfile \$PIDFILE --make-pidfile --background --chuid \$USER --exec \$DAEMON -- \$DAEMON_OPTS
    ;;
  stop)
    echo "Stopping \$DAEMON ..."
    start-stop-daemon --stop --quiet --pidfile \$PIDFILE
    ;;
  restart)
    echo "Restarting \$DAEMON ..."
    start-stop-daemon --stop --quiet --pidfile \$PIDFILE
    sleep 1
    start-stop-daemon --start --quiet --pidfile \$PIDFILE --make-pidfile --background --chuid \$USER --exec \$DAEMON -- \$DAEMON_OPTS
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart}"
    exit 1
    ;;
esac

exit 0
EOF

sudo chmod +x /etc/init.d/$OE_CONFIG
sudo update-rc.d $OE_CONFIG defaults

#--------------------------------------------------
# Configure Nginx if required
#--------------------------------------------------
if [ "$INSTALL_NGINX" = "True" ]; then
    echo -e "\n---- Install Nginx ----"
    sudo apt-get install -y nginx
    echo -e "\n---- Creating Nginx config file ----"
    sudo bash -c "cat > /etc/nginx/sites-available/$OE_CONFIG <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:$OE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF"
    sudo ln -s /etc/nginx/sites-available/$OE_CONFIG /etc/nginx/sites-enabled/$OE_CONFIG
    sudo nginx -t
    sudo systemctl restart nginx
fi

#--------------------------------------------------
# Enable SSL
#--------------------------------------------------
if [ "$ENABLE_SSL" = "True" ]; then
    echo -e "\n---- Enable SSL ----"
    sudo apt-get install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d $DOMAIN_NAME --email $ADMIN_EMAIL --agree-tos --no-eff-email --redirect
fi

#--------------------------------------------------
# Start Odoo server
#--------------------------------------------------
echo -e "\n---- Starting Odoo Server ----"
sudo service $OE_CONFIG start

if ss -tuln | grep -q ':$OE_PORT'; then
  echo "Odoo is running and listening on port: $OE_PORT"
else
  echo "Odoo failed to start or is not listening on port: $OE_PORT"
fi

#--------------------------------------------------
# End of script
#--------------------------------------------------
echo -e "\n=== Odoo installation completed! ==="
