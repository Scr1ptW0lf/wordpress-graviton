# AWS EC2 WordPress Deployment Scripts

Automated scripts for launching AWS EC2 ARM instances and installing WordPress with Apache/MySQL stack on Ubuntu 24.04 LTS.

## 🚀 Features

- **One-command EC2 instance launch** with interactive configuration
- **Automatic WordPress installation** with Apache, MySQL, and PHP 8.3
- **ARM/Graviton instance support** for cost-effective hosting
- **Security best practices** built-in (MySQL hardening, secure passwords)
- **Smart IP detection** (automatically uses public IP, not private)
- **Elastic IP support** for persistent addressing
- **Safety checks** (existing resource detection, backup options)

## 📋 Prerequisites

### For EC2 Launch (`launch-instance.sh`)
- AWS CLI configured with credentials (`aws configure`)
- Appropriate AWS permissions (EC2, VPC)
- Bash shell environment

### For WordPress Installation (`install-wordpress-apache.sh`)
- Ubuntu 24.04 LTS ARM64 instance
- Root access (`sudo`)
- Internet connectivity

## 🛠️ Installation

Clone this repository:

```bash
git clone https://github.com/YOUR_USERNAME/aws-ec2-wordpress.git
cd aws-ec2-wordpress
chmod +x *.sh
```

## 📖 Usage

### Step 1: Launch EC2 Instance

Run the launch script:

```bash
./launch-instance.sh
```

**Interactive prompts:**
1. Select AWS region (or use default)
2. Choose instance type (t4g.micro to t4g.2xlarge)
3. Select or create SSH key pair (number selection supported)
4. Select or create security group (number selection supported)
5. Optional: Allocate Elastic IP
6. Name your instance

**Output:**
- Instance ID and public IP
- SSH connection command
- Key pair saved as `.pem` file (if newly created)

### Step 2: Install WordPress

SSH into your new instance:

```bash
ssh -i your-key.pem ubuntu@YOUR_PUBLIC_IP
```

Copy the installation script to your instance:

```bash
# From your local machine
scp -i your-key.pem install-wordpress-apache.sh ubuntu@YOUR_PUBLIC_IP:~
```

Run the WordPress installation:

```bash
ssh -i your-key.pem ubuntu@YOUR_PUBLIC_IP
chmod +x install-wordpress-apache.sh
sudo ./install-wordpress-apache.sh
```

**Interactive prompts:**
1. Domain name (optional, uses public IP if blank)
2. WordPress site title
3. Admin username
4. Admin password (auto-generated if blank)
5. Admin email

**Installation includes:**
- ✅ Apache 2.4 web server
- ✅ MySQL 8.0 database
- ✅ PHP 8.3 with required extensions
- ✅ WordPress (latest version)
- ✅ WP-CLI for command-line management
- ✅ Automatic security configuration

## 🔧 Configuration

### Instance Types

| Type | vCPU | RAM | Cost/hr* | Use Case |
|------|------|-----|----------|----------|
| t4g.micro | 2 | 1 GB | Free tier | Development/Testing |
| t4g.small | 2 | 2 GB | ~$0.0168 | Small blogs |
| t4g.medium | 2 | 4 GB | ~$0.0336 | Medium traffic sites |
| t4g.large | 2 | 8 GB | ~$0.0672 | High traffic sites |

*Prices approximate, check AWS pricing for your region

### Security Groups

The launch script creates security groups with:
- Port 22 (SSH) - open to 0.0.0.0/0
- Port 80 (HTTP) - open to 0.0.0.0/0
- Port 443 (HTTPS) - open to 0.0.0.0/0

**Security Note:** For production, restrict SSH (port 22) to your IP only.

## 🔒 Security Features

### Launch Script
- ✅ Uses latest Ubuntu 24.04 ARM64 AMI
- ✅ Creates unique key pairs with secure permissions (400)
- ✅ Configurable security groups
- ✅ Resource tagging for easy management

### WordPress Installation
- ✅ MySQL root password auto-generated
- ✅ Unique database user credentials
- ✅ WordPress salts auto-generated
- ✅ File permissions properly configured
- ✅ MySQL secure installation (removes test DB, anonymous users)
- ✅ Credentials saved to `/root/wordpress-credentials.txt` (600 permissions)

## 📁 File Structure

```
aws-ec2-wordpress/
├── README.md                      # This file
├── launch-instance.sh             # EC2 instance launcher
├── install-wordpress-apache.sh    # WordPress installer
└── troubleshoot-wordpress.sh      # Troubleshooting tools (optional)
```

## 🐛 Troubleshooting

### Cannot connect to instance
```bash
# Check instance status
aws ec2 describe-instances --instance-ids YOUR_INSTANCE_ID

# Check security group allows SSH from your IP
aws ec2 describe-security-groups --group-ids YOUR_SG_ID
```

### WordPress shows private IP
The scripts automatically detect public IPs. If you see a private IP:
1. Ensure instance has public IP assigned
2. Check that security group allows HTTP/HTTPS
3. Try accessing via Elastic IP if allocated

### Apache not serving pages
```bash
# Check Apache status
sudo systemctl status apache2

# Check logs
sudo tail -f /var/log/apache2/wordpress-error.log

# Restart Apache
sudo systemctl restart apache2
```

### Database connection errors
```bash
# Check MySQL status
sudo systemctl status mysql

# View credentials
sudo cat /root/wordpress-credentials.txt

# Test database connection
mysql -u wpuser -p wordpress
```

## 🚀 Next Steps After Installation

1. **Visit your WordPress site:** `http://YOUR_PUBLIC_IP`
2. **Login to admin:** `http://YOUR_PUBLIC_IP/wp-admin`
3. **Set up SSL/HTTPS:**
   ```bash
   sudo apt-get install -y certbot python3-certbot-apache
   sudo certbot --apache -d yourdomain.com
   ```
4. **Install recommended plugins:**
   - Security: Wordfence or Sucuri
   - Caching: WP Super Cache or W3 Total Cache
   - Backups: UpdraftPlus or BackWPup

5. **Configure backups:**
   ```bash
   # Database backup
   sudo -u www-data wp db export backup.sql

   # Full backup
   sudo tar -czf wordpress-backup.tar.gz /var/www/html/wordpress
   ```

## 🔄 Updates

### Update WordPress Core
```bash
cd /var/www/html/wordpress
sudo -u www-data wp core update
```

### Update Plugins
```bash
sudo -u www-data wp plugin update --all
```

### Update System Packages
```bash
sudo apt-get update
sudo apt-get upgrade
```

## 🧹 Cleanup

### Remove Instance
```bash
aws ec2 terminate-instances --instance-ids YOUR_INSTANCE_ID
```

### Release Elastic IP (to avoid charges)
```bash
aws ec2 release-address --allocation-id YOUR_ALLOCATION_ID
```

### Delete Security Group
```bash
aws ec2 delete-security-group --group-id YOUR_SG_ID
```

### Delete Key Pair
```bash
aws ec2 delete-key-pair --key-name YOUR_KEY_NAME
rm YOUR_KEY_NAME.pem
```

## 📝 Advanced Usage

### Using WP-CLI

```bash
# List plugins
sudo -u www-data wp plugin list

# Install plugin
sudo -u www-data wp plugin install jetpack --activate

# Create user
sudo -u www-data wp user create newuser user@example.com

# Update site URL
sudo -u www-data wp option update siteurl 'https://yourdomain.com'
sudo -u www-data wp option update home 'https://yourdomain.com'
```

### Customizing Apache

```bash
# Edit virtual host
sudo nano /etc/apache2/sites-available/wordpress.conf

# Test configuration
sudo apache2ctl configtest

# Reload Apache
sudo systemctl reload apache2
```

### Database Management

```bash
# View credentials
sudo cat /root/wordpress-credentials.txt

# Access MySQL
sudo mysql -u root -p

# Backup database
sudo -u www-data wp db export backup-$(date +%Y%m%d).sql

# Restore database
sudo -u www-data wp db import backup.sql
```

## ⚠️ Important Notes

- **Elastic IP Costs:** Elastic IPs cost $0.005/hour when NOT associated with a running instance. Release unused Elastic IPs to avoid charges.
- **Instance Costs:** Remember to terminate instances when not in use to avoid ongoing charges.
- **Backups:** The scripts don't set up automatic backups. Configure your own backup solution.
- **SSL:** The installation uses HTTP only. Set up SSL/HTTPS with Let's Encrypt for production use.
- **Updates:** Keep WordPress, plugins, and system packages updated for security.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see below for details.

## 🙏 Acknowledgments

- Built for Ubuntu 24.04 LTS ARM64
- Optimized for AWS Graviton (ARM) instances
- Uses official WordPress, Apache, MySQL, and PHP packages

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the script output for error messages
3. Check AWS CloudWatch logs
4. Open an issue on GitHub

## 🔗 Useful Links

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [WordPress Documentation](https://wordpress.org/support/)
- [WP-CLI Documentation](https://wp-cli.org/)
- [Apache Documentation](https://httpd.apache.org/docs/)
- [Let's Encrypt](https://letsencrypt.org/)

---

**Made with ❤️ for easy WordPress deployment on AWS**
