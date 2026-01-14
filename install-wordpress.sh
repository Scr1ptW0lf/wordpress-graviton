#!/bin/bash

# WordPress Installation Script for Ubuntu 24.04 ARM64
# Installs NGINX, MySQL, PHP, and WordPress with automatic configuration

set -e

echo "=== WordPress Installation Script ==="
echo "This script will install and configure:"
echo "  - NGINX web server"
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
read -p "Enter WordPress admin email: " WP_ADMIN_EMAIL

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

# Install NGINX
echo ""
echo "[2/8] Installing NGINX..."
apt-get install -y -qq nginx

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

# Verify DB_ROOT_PASS is set
if [ -z "$DB_ROOT_PASS" ]; then
    echo "ERROR: DB_ROOT_PASS is not set. This should not happen."
    echo "Please report this as a bug."
    exit 1
fi

echo "DEBUG: DB_ROOT_PASS is set (length: ${#DB_ROOT_PASS})"
echo "DEBUG: First 4 chars of password: ${DB_ROOT_PASS:0:4}****"

# Create MySQL defaults file for safer password handling
MYSQL_CNF=$(mktemp)
cat > "$MYSQL_CNF" <<EOF
[client]
user=root
password=${DB_ROOT_PASS}
EOF
chmod 600 "$MYSQL_CNF"

echo "DEBUG: Created temporary MySQL config file: $MYSQL_CNF"

# Test MySQL connection first
echo "Testing MySQL connection..."
MYSQL_TEST_OUTPUT=$(mysql --defaults-extra-file="$MYSQL_CNF" -e "SELECT 1;" 2>&1)
MYSQL_TEST_EXIT=$?

if [ $MYSQL_TEST_EXIT -ne 0 ]; then
    echo "ERROR: Cannot connect to MySQL to create database."
    echo "Root password may be incorrect or MySQL is not responding."
    echo "MySQL error output:"
    echo "$MYSQL_TEST_OUTPUT"
    echo ""
    echo "Cleaning up temporary files..."
    rm -f "$MYSQL_CNF"
    echo "Please check MySQL status: systemctl status mysql"
    exit 1
fi

echo "MySQL connection successful."

# Check if database exists
echo "Checking for existing database '${DB_NAME}'..."
echo "DEBUG: Running query to check for database..."

# Use timeout to prevent hanging
if command -v timeout &> /dev/null; then
    DB_QUERY_OUTPUT=$(timeout 10 mysql --defaults-extra-file="$MYSQL_CNF" -e "SHOW DATABASES LIKE '${DB_NAME}';" 2>&1)
    DB_QUERY_EXIT=$?

    if [ $DB_QUERY_EXIT -eq 124 ]; then
        echo "ERROR: MySQL query timed out after 10 seconds."
        echo "MySQL may be unresponsive or overloaded."
        rm -f "$MYSQL_CNF"
        exit 1
    fi
else
    DB_QUERY_OUTPUT=$(mysql --defaults-extra-file="$MYSQL_CNF" -e "SHOW DATABASES LIKE '${DB_NAME}';" 2>&1)
    DB_QUERY_EXIT=$?
fi

echo "DEBUG: Query completed with exit code: $DB_QUERY_EXIT"

if [ $DB_QUERY_EXIT -ne 0 ]; then
    echo "ERROR: Failed to query MySQL databases."
    echo "MySQL error output:"
    echo "$DB_QUERY_OUTPUT"
    exit 1
fi

echo "DEBUG: Parsing query results..."
echo "DEBUG: Query output: '$DB_QUERY_OUTPUT'"
# Use grep -c with || true to prevent exit on no match due to set -e
DB_EXISTS=$(echo "$DB_QUERY_OUTPUT" | grep -c "${DB_NAME}" || true)
echo "DEBUG: Database exists check: $DB_EXISTS"

if [ "$DB_EXISTS" -gt 0 ]; then
    echo ""
    echo "WARNING: Database '${DB_NAME}' already exists!"
    read -p "Delete existing database and create fresh? (y/n, default: n): " DELETE_DB
    DELETE_DB=${DELETE_DB:-n}

    if [ "$DELETE_DB" = "y" ]; then
        echo "Dropping existing database..."
        if ! mysql --defaults-extra-file="$MYSQL_CNF" -e "DROP DATABASE ${DB_NAME};"; then
            echo "ERROR: Failed to drop database ${DB_NAME}"
            rm -f "$MYSQL_CNF"
            exit 1
        fi
        echo "Creating fresh WordPress database..."
        if ! mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
        then
            echo "ERROR: Failed to create database ${DB_NAME}"
            rm -f "$MYSQL_CNF"
            exit 1
        fi
    else
        echo "Using existing database '${DB_NAME}'."
        echo "WARNING: Existing data will be overwritten by WordPress installation!"
        read -p "Continue anyway? (y/n, default: n): " CONTINUE_EXISTING
        CONTINUE_EXISTING=${CONTINUE_EXISTING:-n}
        if [ "$CONTINUE_EXISTING" != "y" ]; then
            echo "Installation cancelled."
            exit 0
        fi
    fi
else
    echo "Creating WordPress database..."
    if ! mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    then
        echo "ERROR: Failed to create database ${DB_NAME}"
        rm -f "$MYSQL_CNF"
        exit 1
    fi
    echo "Database created successfully."
fi

# Check if WordPress user already exists
echo "Checking for existing database user '${DB_USER}'..."
USER_EXISTS=$(mysql --defaults-extra-file="$MYSQL_CNF" -e "SELECT User FROM mysql.user WHERE User='${DB_USER}';" 2>/dev/null | grep -c "${DB_USER}" || true)

if [ "$USER_EXISTS" -gt 0 ]; then
    echo "Database user '${DB_USER}' already exists. Updating password and permissions..."
    if ! mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    then
        echo "ERROR: Failed to update user ${DB_USER}"
        rm -f "$MYSQL_CNF"
        exit 1
    fi
    echo "User updated successfully."
else
    echo "Creating WordPress database user..."
    if ! mysql --defaults-extra-file="$MYSQL_CNF" <<EOF
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    then
        echo "ERROR: Failed to create user ${DB_USER}"
        rm -f "$MYSQL_CNF"
        exit 1
    fi
    echo "User created successfully."
fi

echo "Database setup complete."

# Clean up MySQL config file
echo "DEBUG: Cleaning up temporary MySQL config file..."
rm -f "$MYSQL_CNF"

# Install PHP
echo ""
echo "[5/8] Installing PHP and extensions..."
apt-get install -y -qq php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring \
    php8.3-xml php8.3-xmlrpc php8.3-soap php8.3-intl php8.3-zip

# Configure PHP-FPM socket permissions to prevent 502 errors
echo "Configuring PHP-FPM socket permissions..."
sed -i 's/;listen.owner = www-data/listen.owner = www-data/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/;listen.group = www-data/listen.group = www-data/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/;listen.mode = 0660/listen.mode = 0660/' /etc/php/8.3/fpm/pool.d/www.conf

# Check if WordPress directory already exists
if [ -d "/var/www/wordpress" ]; then
    echo ""
    echo "WARNING: WordPress directory /var/www/wordpress already exists!"
    read -p "Delete existing WordPress installation? (y/n, default: n): " DELETE_WP
    DELETE_WP=${DELETE_WP:-n}

    if [ "$DELETE_WP" = "y" ]; then
        echo "Removing existing WordPress directory..."
        rm -rf /var/www/wordpress
    else
        echo "Keeping existing WordPress files."
        echo "WARNING: Configuration will be overwritten!"
        read -p "Continue? (y/n, default: n): " CONTINUE_WP
        CONTINUE_WP=${CONTINUE_WP:-n}
        if [ "$CONTINUE_WP" != "y" ]; then
            echo "Installation cancelled."
            exit 0
        fi
    fi
fi

# Download WordPress
echo ""
echo "[6/8] Downloading WordPress..."
cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

if [ -d "/var/www/wordpress" ]; then
    # Backup existing wp-config.php if it exists
    if [ -f "/var/www/wordpress/wp-config.php" ]; then
        echo "Backing up existing wp-config.php..."
        cp /var/www/wordpress/wp-config.php /var/www/wordpress/wp-config.php.backup.$(date +%s)
    fi
    # Preserve wp-content if it exists
    if [ -d "/var/www/wordpress/wp-content" ]; then
        echo "Backing up wp-content directory..."
        cp -r /var/www/wordpress/wp-content /tmp/wp-content-backup
    fi
fi

cp -r wordpress /var/www/wordpress
chown -R www-data:www-data /var/www/wordpress
rm -rf wordpress latest.tar.gz

# Restore wp-content if it was backed up
if [ -d "/tmp/wp-content-backup" ]; then
    echo "Restoring wp-content directory..."
    rm -rf /var/www/wordpress/wp-content
    mv /tmp/wp-content-backup /var/www/wordpress/wp-content
    chown -R www-data:www-data /var/www/wordpress/wp-content
fi

# Configure WordPress
echo ""
echo "[7/8] Configuring WordPress..."
cd /var/www/wordpress

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

# Configure NGINX
echo ""
echo "[8/8] Configuring NGINX..."

# Determine server name
if [ -z "$DOMAIN_NAME" ]; then
    # Try to get EC2 public IP, fallback to local IP, fallback to underscore (catch-all)
    SERVER_NAME=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    if [ -z "$SERVER_NAME" ]; then
        SERVER_NAME=$(hostname -I | awk '{print $1}')
    fi
    if [ -z "$SERVER_NAME" ]; then
        SERVER_NAME="_"
    fi
else
    SERVER_NAME="$DOMAIN_NAME"
fi

echo "Using server name: $SERVER_NAME"

cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${SERVER_NAME};

    root /var/www/wordpress;
    index index.php index.html index.htm;

    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    }
}
EOF

# Check if WordPress site configuration already exists
if [ -f "/etc/nginx/sites-available/wordpress" ]; then
    echo ""
    echo "Existing WordPress NGINX configuration found."
    echo "Creating backup at /etc/nginx/sites-available/wordpress.backup.$(date +%s)"
    cp /etc/nginx/sites-available/wordpress /etc/nginx/sites-available/wordpress.backup.$(date +%s)
fi

# Enable site
ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/

# Only remove default if it exists and is a symlink
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    rm -f /etc/nginx/sites-enabled/default
elif [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo ""
    echo "WARNING: Default NGINX site exists."
    read -p "Remove default site configuration? (y/n, default: y): " REMOVE_DEFAULT
    REMOVE_DEFAULT=${REMOVE_DEFAULT:-y}
    if [ "$REMOVE_DEFAULT" = "y" ]; then
        rm -f /etc/nginx/sites-enabled/default
    fi
fi

# Test NGINX configuration
echo ""
echo "Testing NGINX configuration..."
if ! nginx -t; then
    echo ""
    echo "ERROR: NGINX configuration test failed!"
    echo "Configuration saved to: /etc/nginx/sites-available/wordpress"
    echo "Please review and fix the configuration manually."
    exit 1
fi

# Restart services
systemctl restart nginx
systemctl restart php8.3-fpm

# Enable services to start on boot
systemctl enable nginx
systemctl enable mysql
systemctl enable php8.3-fpm

# Install WP-CLI for command line WordPress management
echo ""
echo "Installing WP-CLI..."
wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
chmod +x /usr/local/bin/wp

# Complete WordPress installation via WP-CLI
echo ""
echo "Completing WordPress installation..."
cd /var/www/wordpress

# Use underscore if SERVER_NAME is catch-all
if [ "$SERVER_NAME" = "_" ]; then
    WP_URL="http://$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')"
else
    WP_URL="http://${SERVER_NAME}"
fi

echo "WordPress URL will be: $WP_URL"

# Check if WordPress is already installed
if sudo -u www-data wp core is-installed 2>/dev/null; then
    echo ""
    echo "WARNING: WordPress is already installed!"
    echo "Running installation will:"
    echo "  - Drop all existing WordPress tables"
    echo "  - Remove all posts, pages, and content"
    echo "  - Reset all settings"
    echo ""
    read -p "Continue with fresh installation? (y/n, default: n): " REINSTALL_WP
    REINSTALL_WP=${REINSTALL_WP:-n}

    if [ "$REINSTALL_WP" = "y" ]; then
        echo "Reinstalling WordPress (this will delete all existing data)..."
        sudo -u www-data wp db reset --yes
        sudo -u www-data wp core install \
            --url="$WP_URL" \
            --title="${SITE_TITLE}" \
            --admin_user="${WP_ADMIN_USER}" \
            --admin_password="${WP_ADMIN_PASS}" \
            --admin_email="${WP_ADMIN_EMAIL}" \
            --skip-email
    else
        echo ""
        echo "Skipping WordPress installation. Existing installation preserved."
        echo "You can access the existing site at: $WP_URL"
        echo ""
        echo "NOTE: Database credentials have been updated if changed."
        exit 0
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
    echo "  apt-get install -y certbot python3-certbot-nginx"
    echo "  certbot --nginx -d ${DOMAIN_NAME}"
    echo ""
fi

echo "To manage WordPress from command line:"
echo "  cd /var/www/wordpress"
echo "  sudo -u www-data wp plugin list"
echo "  sudo -u www-data wp theme list"
echo ""
echo "=========================================="
