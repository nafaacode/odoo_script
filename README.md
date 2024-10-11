
##### 1. Download the script:
```
sudo wget https://raw.githubusercontent.com/nafaacode/odoo_script/refs/heads/main/odoo_install_ubuntu.sh

```

##### 2. Modify the parameters


# Odoo Installation Script for Ubuntu

This script automates the installation of Odoo on Ubuntu servers. It sets up all necessary components, including PostgreSQL, Nginx, and SSL certificates, if required.

## Author
Nafaa Z

## Prerequisites
- This script is intended for Ubuntu 16.04, 18.04, 20.04, 22.04, and 24.04.
- Make sure you have `sudo` privileges.

## Usage

1. **Create a new script file:**
   ```bash
   sudo nano install_odoo18_ubuntu.sh
   
2. **Make the script executable:**

   sudo chmod +x install_odoo18_ubuntu.sh
   
3. **Run the script to install Odoo:**
   ./install_odoo18_ubuntu.sh

**Before running the script, configure the following variables in the script:**

OE_VERSION: The version of Odoo to install (default is "18.0").
INSTALL_NGINX: Set to "True" if you want to install Nginx.
WEBSITE_NAME: The domain name for your Odoo instance.
ENABLE_SSL: Set to "True" to enable SSL.
ADMIN_EMAIL: Email for SSL registration (should not be "odoo@example.com").
INSTALL_POSTGRESQL_FOURTEEN: Set to "True" to install PostgreSQL 14.
INSTALL_WKHTMLTOPDF: Set to "True" to install Wkhtmltopdf.
IS_ENTERPRISE: Set to "True" to install the Odoo enterprise version.
OE_SUPERADMIN: Superadmin password for Odoo.
DB_PASSWORD: Database password (if not generating a random one).
GENERATE_RANDOM_PASSWORD: Set to "True" to generate a random database password.

**Notes**
The script sets up a PostgreSQL database for Odoo and creates a system user.
It configures Nginx as a reverse proxy for Odoo.
It generates SSL certificates using Certbot if enabled.
Ensure to replace placeholder values like WEBSITE_NAME and ADMIN_EMAIL with your actual values.

**Troubleshooting**
If you encounter issues:

Check the logs located at /var/log/odoo/.
**Verify Nginx configuration with:**
bash
Copier le code
sudo nginx -t
**Check the status of the Odoo service using:**
bash
Copier le code
sudo systemctl status odoo.service

**License**
This project is licensed under the MIT License. See the LICENSE file for more details.
