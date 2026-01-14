#!/bin/bash

# WordPress 502 Error Troubleshooting Script
# This script checks common causes of 502 Bad Gateway errors

echo "=== WordPress 502 Error Troubleshooting ==="
echo ""

# Check PHP-FPM status
echo "[1] Checking PHP-FPM status..."
if systemctl is-active --quiet php8.3-fpm; then
    echo "  ✓ PHP-FPM is running"
else
    echo "  ✗ PHP-FPM is NOT running"
    echo "  Starting PHP-FPM..."
    systemctl start php8.3-fpm
    if systemctl is-active --quiet php8.3-fpm; then
        echo "  ✓ PHP-FPM started successfully"
    else
        echo "  ✗ Failed to start PHP-FPM"
        echo "  Check logs: journalctl -u php8.3-fpm -n 50"
        exit 1
    fi
fi

# Check PHP-FPM socket
echo ""
echo "[2] Checking PHP-FPM socket..."
if [ -S /var/run/php/php8.3-fpm.sock ]; then
    echo "  ✓ PHP-FPM socket exists: /var/run/php/php8.3-fpm.sock"
    ls -lh /var/run/php/php8.3-fpm.sock
else
    echo "  ✗ PHP-FPM socket NOT found"
    echo "  Expected location: /var/run/php/php8.3-fpm.sock"
    echo ""
    echo "  Available sockets:"
    ls -lh /var/run/php/ 2>/dev/null || echo "    No sockets found"
fi

# Check socket permissions
echo ""
echo "[3] Checking socket permissions..."
SOCKET_PERMS=$(stat -c '%a' /var/run/php/php8.3-fpm.sock 2>/dev/null)
SOCKET_OWNER=$(stat -c '%U:%G' /var/run/php/php8.3-fpm.sock 2>/dev/null)
echo "  Socket permissions: $SOCKET_PERMS"
echo "  Socket owner: $SOCKET_OWNER"

# Check NGINX status
echo ""
echo "[4] Checking NGINX status..."
if systemctl is-active --quiet nginx; then
    echo "  ✓ NGINX is running"
else
    echo "  ✗ NGINX is NOT running"
    echo "  Starting NGINX..."
    systemctl start nginx
fi

# Check NGINX configuration
echo ""
echo "[5] Testing NGINX configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    echo "  ✓ NGINX configuration is valid"
else
    echo "  ✗ NGINX configuration has errors:"
    nginx -t
fi

# Check NGINX error log
echo ""
echo "[6] Recent NGINX errors (last 10 lines)..."
if [ -f /var/log/nginx/error.log ]; then
    tail -10 /var/log/nginx/error.log
else
    echo "  No error log found"
fi

# Check PHP-FPM error log
echo ""
echo "[7] Recent PHP-FPM errors (last 10 lines)..."
if [ -f /var/log/php8.3-fpm.log ]; then
    tail -10 /var/log/php8.3-fpm.log
else
    journalctl -u php8.3-fpm -n 10 --no-pager
fi

# Check PHP-FPM pool configuration
echo ""
echo "[8] Checking PHP-FPM pool configuration..."
if [ -f /etc/php/8.3/fpm/pool.d/www.conf ]; then
    echo "  Listen directive:"
    grep "^listen = " /etc/php/8.3/fpm/pool.d/www.conf
    echo ""
    echo "  Listen owner/group:"
    grep "^listen.owner" /etc/php/8.3/fpm/pool.d/www.conf
    grep "^listen.group" /etc/php/8.3/fpm/pool.d/www.conf
    grep "^listen.mode" /etc/php/8.3/fpm/pool.d/www.conf
else
    echo "  ✗ PHP-FPM pool config not found"
fi

# Check WordPress directory permissions
echo ""
echo "[9] Checking WordPress directory permissions..."
if [ -d /var/www/wordpress ]; then
    ls -ld /var/www/wordpress
    echo ""
    echo "  WordPress files owner:"
    ls -l /var/www/wordpress/index.php 2>/dev/null || echo "    index.php not found"
else
    echo "  ✗ WordPress directory not found"
fi

# Check if WordPress is accessible
echo ""
echo "[10] Testing PHP processing..."
TEST_FILE="/var/www/wordpress/test-php.php"
echo "<?php phpinfo(); ?>" > "$TEST_FILE"
chown www-data:www-data "$TEST_FILE"

echo "  Created test file: $TEST_FILE"
echo "  Try accessing: http://YOUR_SERVER_IP/test-php.php"
echo ""
echo "  To test from command line:"
echo "    curl -I http://localhost/test-php.php"

# Summary and recommendations
echo ""
echo "=========================================="
echo "=== Common 502 Fixes ==="
echo "=========================================="
echo ""
echo "1. Restart PHP-FPM:"
echo "   systemctl restart php8.3-fpm"
echo ""
echo "2. Restart NGINX:"
echo "   systemctl restart nginx"
echo ""
echo "3. Check PHP-FPM is listening on correct socket:"
echo "   grep 'listen = ' /etc/php/8.3/fpm/pool.d/www.conf"
echo ""
echo "4. Fix socket permissions (if needed):"
echo "   sed -i 's/;listen.owner = www-data/listen.owner = www-data/' /etc/php/8.3/fpm/pool.d/www.conf"
echo "   sed -i 's/;listen.group = www-data/listen.group = www-data/' /etc/php/8.3/fpm/pool.d/www.conf"
echo "   sed -i 's/;listen.mode = 0660/listen.mode = 0660/' /etc/php/8.3/fpm/pool.d/www.conf"
echo "   systemctl restart php8.3-fpm"
echo ""
echo "5. View live NGINX error log:"
echo "   tail -f /var/log/nginx/error.log"
echo ""
echo "6. View live PHP-FPM log:"
echo "   journalctl -u php8.3-fpm -f"
echo ""
echo "7. Clean up test file when done:"
echo "   rm $TEST_FILE"
echo ""
echo "=========================================="
