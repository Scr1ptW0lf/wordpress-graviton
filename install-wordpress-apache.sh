#!/bin/bash

# WordPress Installation Script for Ubuntu 24.04 ARM64
# Installs Apache, MySQL, PHP, and WordPress with automatic configuration

set -e

echo "=== WordPress Installation Script (Apache) ==="
echo "This script will install and configure:"
echo "  - Apache web server"
echo "  - MySQL database"
echo "  - PHP 8.3"
echo "  - WordPress (latest version)"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use: sudo bash $0)"
    exit 1
fi

# Get configuration from user
echo "=== WordPress Configuration ==="
read -p "Enter your domain name (or press Enter to use server IP): " DOMAIN_NAME
read -p "Enter WordPress site title (default: My WordPress Site): " SITE_TITLE
SITE_TITLE=${SITE_TITLE:-My WordPress Site}
read -p "Enter WordPress admin username (default: admin): " WP_ADMIN_USER
WP_ADMIN_USER=${WP_ADMIN_USER:-admin}
read -sp "Enter WordPress admin password (or press Enter to generate): " WP_ADMIN_PASS
echo ""
if [ -z "$WP_ADMIN_PASS" ]; then
    WP_ADMIN_PASS=$(openssl rand -base64 16)
    echo "Generated password: $WP_ADMIN_PASS"
fi
read -p "Enter WordPress admin email: (default:test@example.com)" WP_ADMIN_EMAIL
WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL:-test@example.com}

# Generate database credentials
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS=$(openssl rand -base64 16)
DB_ROOT_PASS=$(openssl rand -base64 16)

echo ""
echo "=== Installation Summary ==="
echo "Domain: ${DOMAIN_NAME:-Server IP}"
echo "Site Title: $SITE_TITLE"
echo "Admin User: $WP_ADMIN_USER"
echo "Admin Email: $WP_ADMIN_EMAIL"
echo "Database: $DB_NAME"
echo ""
read -p "Proceed with installation? (y/n, default: y): " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ]; then
    echo "Installation cancelled"
    exit 0
fi

echo ""
echo "Starting installation..."

# Update system
echo ""
echo "[1/8] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# Install Apache
echo ""
echo "[2/8] Installing Apache..."
apt-get install -y -qq apache2

# Enable Apache modules
echo "Enabling Apache modules..."
a2enmod rewrite
a2enmod ssl
a2enmod headers

# Check if MySQL is already installed
MYSQL_INSTALLED=false
if systemctl is-active --quiet mysql || systemctl is-active --quiet mysqld; then
    MYSQL_INSTALLED=true
    echo ""
    echo "MySQL is already installed and running."
elif command -v mysql &> /dev/null; then
    MYSQL_INSTALLED=true
    echo ""
    echo "MySQL is already installed."
fi

if [ "$MYSQL_INSTALLED" = true ]; then
    echo ""
    echo "[3/8] Using existing MySQL installation..."
    read -sp "Enter MySQL root password (or press Enter to try without password): " EXISTING_ROOT_PASS
    echo ""

    MYSQL_CONNECTION_OK=false

    # Test the password
    if [ -n "$EXISTING_ROOT_PASS" ]; then
        if mysql -u root -p"${EXISTING_ROOT_PASS}" -e "SELECT 1;" &> /dev/null; then
            echo "Successfully connected to MySQL."
            DB_ROOT_PASS="$EXISTING_ROOT_PASS"
            MYSQL_CONNECTION_OK=true
        else
            echo "Error: Could not connect to MySQL with provided password."
        fi
    fi

    # Try without password if previous attempt failed or no password was provided
    if [ "$MYSQL_CONNECTION_OK" = false ]; then
        echo "Trying to connect without password..."
        if mysql -u root -e "SELECT 1;" &> /dev/null; then
            echo "Connected without password. Will set a password now."
            DB_ROOT_PASS=$(openssl rand -base64 16)
            mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASS}';"
            echo "New root password set: $DB_ROOT_PASS"
            MYSQL_CONNECTION_OK=true
        fi
    fi

    # If still cannot connect, offer to reinstall
    if [ "$MYSQL_CONNECTION_OK" = false ]; then
        echo ""
        echo "ERROR: Cannot connect to MySQL with any method."
        echo "This usually means MySQL is in an inconsistent state."
        echo ""
        read -p "Remove and reinstall MySQL? (y/n, default: y): " REINSTALL_MYSQL
        REINSTALL_MYSQL=${REINSTALL_MYSQL:-y}

        if [ "$REINSTALL_MYSQL" = "y" ]; then
            echo ""
            echo "Removing MySQL..."
            systemctl stop mysql 2>/dev/null || systemctl stop mysqld 2>/dev/null || true
            apt-get remove --purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* -qq
            apt-get autoremove -y -qq
            apt-get autoclean -qq
            rm -rf /etc/mysql /var/lib/mysql /var/log/mysql

            echo "Reinstalling MySQL..."
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq mysql-server

            # Generate new root password
            DB_ROOT_PASS=$(openssl rand -base64 16)

            # Set root password and secure installation
            mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASS}';"
            mysql -u root -p"${DB_ROOT_PASS}" -e "DELETE FROM mysql.user WHERE User='';"
            mysql -u root -p"${DB_ROOT_PASS}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
            mysql -u root -p"${DB_ROOT_PASS}" -e "DROP DATABASE IF EXISTS test;"
            mysql -u root -p"${DB_ROOT_PASS}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
            mysql -u root -p"${DB_ROOT_PASS}" -e "FLUSH PRIVILEGES;"

            echo "MySQL reinstalled successfully."
            echo "New root password: $DB_ROOT_PASS"
        else
            echo "Installation cancelled."
            exit 1
        fi
    fi
else
    # Install MySQL
    echo ""
    echo "[3/8] Installing MySQL..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -qq mysql-server

    # Secure MySQL installation
    echo ""
    echo "[4/8] Configuring MySQL..."
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASS}';"
    mysql -u root -p"${DB_ROOT_PASS}" -e "DELETE FROM mysql.user WHERE User='';"
    mysql -u root -p"${DB_ROOT_PASS}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -u root -p"${DB_ROOT_PASS}" -e "DROP DATABASE IF EXISTS test;"
    mysql -u root -p"${DB_ROOT_PASS}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -u root -p"${DB_ROOT_PASS}" -e "FLUSH PRIVILEGES;"
fi

# Check if WordPress database already exists
echo ""
echo "[4/8] Setting up WordPress database..."

# Create MySQL defaults file for safer password handling
MYSQL_CNF=$(mktemp)
cat > "$MYSQL_CNF" <<EOF
[client]
user=root
password=${DB_ROOT_PASS}
EOF
chmod 600 "$MYSQL_CNF"

# Test MySQL connection first
echo "Testing MySQL connection..."
if ! mysql --defaults-extra-file="$MYSQL_CNF" -e "SELECT 1;" &> /dev/null; then
    echo "ERROR: Cannot connect to MySQL to create database."
    rm -f "$MYSQL_CNF"
    exit 1
fi

echo "MySQL connection successful."

# Check if database exists
echo "Checking for existing database '${DB_NAME}'..."
DB_EXISTS=$(mysql --defaults-extra-file="$MYSQL_CNF" -e "SHOW DATABASES LIKE '${DB_NAME}';" 2>/dev/null | grep -c "${DB_NAME}" || true)

if [ "$DB_EXISTS" -gt 0 ]; then
    echo ""
    echo "WARNING: Database '${DB_NAME}' already exists!"
    read -p "Delete existing database and create fresh? (y/n, default: n): " DELETE_DB
    DELETE_DB=${DELETE_DB:-n}

    if [ "$DELETE_DB" = "y" ]; then
        echo "Dropping existing database..."
        mysql --defaults-extra-file="$MYSQL_CNF" -e "DROP DATABASE ${DB_NAME};"
        echo "Creating fresh WordPress database..."
        mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    else
        echo "Using existing database '${DB_NAME}'."
    fi
else
    echo "Creating WordPress database..."
    mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    echo "Database created successfully."
fi

# Check if WordPress user already exists
echo "Checking for existing database user '${DB_USER}'..."
USER_EXISTS=$(mysql --defaults-extra-file="$MYSQL_CNF" -e "SELECT User FROM mysql.user WHERE User='${DB_USER}';" 2>/dev/null | grep -c "${DB_USER}" || true)

if [ "$USER_EXISTS" -gt 0 ]; then
    echo "Database user '${DB_USER}' already exists. Updating password and permissions..."
    mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    echo "User updated successfully."
else
    echo "Creating WordPress database user..."
    mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    echo "User created successfully."
fi

echo "Database setup complete."
rm -f "$MYSQL_CNF"

# Install PHP
echo ""
echo "[5/8] Installing PHP and extensions..."
apt-get install -y -qq php8.3 php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring \
    php8.3-xml php8.3-xmlrpc php8.3-soap php8.3-intl php8.3-zip libapache2-mod-php8.3 php8.3-imagick

# Configure PHP
echo "Configuring PHP..."
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/8.3/apache2/php.ini
sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/8.3/apache2/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.3/apache2/php.ini

# Check if WordPress directory already exists
if [ -d "/var/www/html/wordpress" ]; then
    echo ""
    echo "WARNING: WordPress directory /var/www/html/wordpress already exists!"
    read -p "Delete existing WordPress installation? (y/n, default: n): " DELETE_WP
    DELETE_WP=${DELETE_WP:-n}

    if [ "$DELETE_WP" = "y" ]; then
        echo "Removing existing WordPress directory..."
        rm -rf /var/www/html/wordpress
    fi
fi

# Download WordPress
echo ""
echo "[6/8] Downloading WordPress..."
cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress /var/www/html/
chown -R www-data:www-data /var/www/html/wordpress
rm -f latest.tar.gz

# Configure WordPress
echo ""
echo "[7/8] Configuring WordPress..."
cd /var/www/html/wordpress

# Generate WordPress salts
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

# Create wp-config.php
cat > wp-config.php <<EOF
<?php
define( 'DB_NAME', '${DB_NAME}' );
define( 'DB_USER', '${DB_USER}' );
define( 'DB_PASSWORD', '${DB_PASS}' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

${SALTS}

\$table_prefix = 'wp_';

define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF

chown www-data:www-data wp-config.php
chmod 640 wp-config.php

# Configure Apache
echo ""
echo "[8/8] Configuring Apache..."

# Determine server name
if [ -z "$DOMAIN_NAME" ]; then
    # Try to get EC2 public IP first
    SERVER_NAME=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)

    # If we got a valid public IP, use it
    if [ -n "$SERVER_NAME" ] && [[ ! "$SERVER_NAME" =~ ^172\. ]] && [[ ! "$SERVER_NAME" =~ ^10\. ]] && [[ ! "$SERVER_NAME" =~ ^192\.168\. ]]; then
        echo "Detected EC2 public IP: $SERVER_NAME"
    else
        # Fallback: try to get public IP from external service
        echo "EC2 metadata not available, trying external service..."
        SERVER_NAME=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null || curl -s --connect-timeout 5 https://icanhazip.com 2>/dev/null)

        if [ -n "$SERVER_NAME" ]; then
            echo "Detected public IP from external service: $SERVER_NAME"
        else
            # Last resort: use local IP (but warn user)
            SERVER_NAME=$(hostname -I | awk '{print $1}')
            echo "WARNING: Using local IP address: $SERVER_NAME"
            echo "This is a private IP and won't be accessible from the internet."
            echo "Consider specifying a domain name or public IP."
        fi
    fi
else
    SERVER_NAME="$DOMAIN_NAME"
    echo "Using provided domain: $SERVER_NAME"
fi

# Create Apache virtual host
cat > /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    ServerAdmin ${WP_ADMIN_EMAIL}
    DocumentRoot /var/www/html/wordpress

    <Directory /var/www/html/wordpress>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress-error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress-access.log combined
</VirtualHost>
EOF

# Enable WordPress site
echo "Enabling WordPress site..."
a2ensite wordpress.conf

# Disable default site if it exists
if [ -f /etc/apache2/sites-enabled/000-default.conf ]; then
    echo "Disabling default site..."
    a2dissite 000-default.conf
fi

# Test Apache configuration
echo ""
echo "Testing Apache configuration..."
if ! apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    echo "ERROR: Apache configuration test failed!"
    apache2ctl configtest
    exit 1
fi

echo "Apache configuration is valid."

# Restart Apache
echo "Restarting Apache..."
systemctl restart apache2

# Enable services to start on boot
systemctl enable apache2
systemctl enable mysql

# Install WP-CLI for command line WordPress management
echo ""
echo "Installing WP-CLI..."
wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
chmod +x /usr/local/bin/wp

# Complete WordPress installation via WP-CLI
echo ""
echo "Completing WordPress installation..."
cd /var/www/html/wordpress

# Determine WordPress URL
# If SERVER_NAME looks like a private IP, try to get public IP
if [[ "$SERVER_NAME" =~ ^172\. ]] || [[ "$SERVER_NAME" =~ ^10\. ]] || [[ "$SERVER_NAME" =~ ^192\.168\. ]]; then
    PUBLIC_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null)
    if [ -n "$PUBLIC_IP" ]; then
        WP_URL="http://${PUBLIC_IP}"
        echo "Using public IP for WordPress URL: $PUBLIC_IP"
    else
        WP_URL="http://${SERVER_NAME}"
        echo "WARNING: Could not determine public IP, using private IP: $SERVER_NAME"
    fi
else
    WP_URL="http://${SERVER_NAME}"
fi

echo "WordPress URL will be: $WP_URL"

# Check if WordPress is already installed
if sudo -u www-data wp core is-installed 2>/dev/null; then
    echo ""
    echo "WARNING: WordPress is already installed!"
    read -p "Continue with fresh installation? (y/n, default: n): " REINSTALL_WP
    REINSTALL_WP=${REINSTALL_WP:-n}

    if [ "$REINSTALL_WP" = "y" ]; then
        echo "Reinstalling WordPress..."
        sudo -u www-data wp db reset --yes
        sudo -u www-data wp core install \
            --url="$WP_URL" \
            --title="${SITE_TITLE}" \
            --admin_user="${WP_ADMIN_USER}" \
            --admin_password="${WP_ADMIN_PASS}" \
            --admin_email="${WP_ADMIN_EMAIL}" \
            --skip-email
    fi
else
    sudo -u www-data wp core install \
        --url="$WP_URL" \
        --title="${SITE_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email
fi

echo ""
echo "=========================================="
echo "=== WordPress Installation Complete! ==="
echo "=========================================="
echo ""
echo "Website URL: $WP_URL"
echo "Admin URL: $WP_URL/wp-admin"
echo ""
echo "WordPress Admin Credentials:"
echo "  Username: $WP_ADMIN_USER"
echo "  Password: $WP_ADMIN_PASS"
echo "  Email: $WP_ADMIN_EMAIL"
echo ""
echo "Database Credentials:"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Password: $DB_PASS"
echo ""
echo "MySQL Root Password: $DB_ROOT_PASS"
echo ""
echo "IMPORTANT: Save these credentials securely!"
echo ""

# Save credentials to file
CREDS_FILE="/root/wordpress-credentials.txt"
cat > "$CREDS_FILE" <<EOF
WordPress Installation Credentials
===================================
Date: $(date)

Website URL: $WP_URL
Admin URL: $WP_URL/wp-admin

WordPress Admin:
  Username: $WP_ADMIN_USER
  Password: $WP_ADMIN_PASS
  Email: $WP_ADMIN_EMAIL

Database:
  Name: $DB_NAME
  User: $DB_USER
  Password: $DB_PASS

MySQL Root Password: $DB_ROOT_PASS

WP-CLI installed at: /usr/local/bin/wp
Usage: sudo -u www-data wp <command>

Apache Configuration: /etc/apache2/sites-available/wordpress.conf
EOF

chmod 600 "$CREDS_FILE"

echo "Credentials saved to: $CREDS_FILE"
echo ""
echo "Next steps:"
echo "1. Visit $WP_URL/wp-admin to access your site"
echo "2. Consider setting up SSL/HTTPS with Let's Encrypt"
echo "3. Install a caching plugin for better performance"
echo "4. Configure regular backups"
echo ""

if [ -n "$DOMAIN_NAME" ]; then
    echo "To set up SSL with Let's Encrypt:"
    echo "  apt-get install -y certbot python3-certbot-apache"
    echo "  certbot --apache -d ${DOMAIN_NAME}"
    echo ""
fi

echo "To manage WordPress from command line:"
echo "  cd /var/www/html/wordpress"
echo "  sudo -u www-data wp plugin list"
echo "  sudo -u www-data wp theme list"
echo ""
echo "Apache logs:"
echo "  Error log: /var/log/apache2/wordpress-error.log"
echo "  Access log: /var/log/apache2/wordpress-access.log"
echo ""
echo "=========================================="
