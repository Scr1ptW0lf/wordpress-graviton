# AWS EC2 WordPress Deployment

Automated scripts for launching AWS EC2 ARM instances and installing WordPress with Apache, MySQL, and PHP on Ubuntu 24.04 LTS.

## Quick Start

### Step 1: Launch EC2 Instance (Run in AWS CloudShell)

Open AWS CloudShell in your AWS Console and run:

```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/aws-ec2-wordpress/main/launch-instance.sh
chmod +x launch-instance.sh
./launch-instance.sh
```

Follow the interactive prompts. The script will output your instance's public IP and SSH command.

### Step 2: Install WordPress (Run on EC2 Instance)

SSH into your instance and run:

```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/aws-ec2-wordpress/main/install-wordpress-apache.sh
chmod +x install-wordpress-apache.sh
sudo ./install-wordpress-apache.sh
```

Follow the prompts to configure WordPress.

## Features

**launch-instance.sh**
- Interactive AWS region selection
- ARM/Graviton instance support (t4g family)
- Number-based selection for existing resources
- Automatic Ubuntu 24.04 ARM64 AMI detection
- Security group creation with SSH, HTTP, HTTPS access
- Optional Elastic IP allocation

**install-wordpress-apache.sh**
- Apache 2.4 web server
- MySQL 8.0 with security hardening
- PHP 8.3 with required extensions
- WordPress (latest version)
- WP-CLI for command-line management
- Automatic public IP detection
- Safe handling of existing installations
- Automatic credential generation

## Configuration

### Instance Types

| Type | vCPU | RAM | Monthly Cost* |
|------|------|-----|---------------|
| t4g.micro | 2 | 1 GB | Free tier eligible |
| t4g.small | 2 | 2 GB | ~$12 |
| t4g.medium | 2 | 4 GB | ~$24 |
| t4g.large | 2 | 8 GB | ~$48 |

*Approximate costs for 24/7 operation

### Security Groups

Default security group configuration:
- Port 22 (SSH): 0.0.0.0/0
- Port 80 (HTTP): 0.0.0.0/0
- Port 443 (HTTPS): 0.0.0.0/0

For production, restrict SSH access to your IP only.

## Post-Installation

### View Credentials

```bash
sudo cat /root/wordpress-credentials.txt
```

### Set Up SSL

```bash
sudo apt-get install -y certbot python3-certbot-apache
sudo certbot --apache -d yourdomain.com
```

### WordPress CLI Usage

```bash
cd /var/www/html/wordpress
sudo -u www-data wp plugin list
sudo -u www-data wp theme list
sudo -u www-data wp plugin install PLUGIN_NAME --activate
```

### Database Backup

```bash
sudo -u www-data wp db export backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Cannot Connect via SSH

Check security group allows SSH from your IP:
```bash
aws ec2 describe-security-groups --group-ids YOUR_SG_ID
```

### Cannot Access WordPress

Verify security group allows HTTP traffic and instance has public IP assigned.

### Apache Issues

```bash
sudo systemctl status apache2
sudo tail -f /var/log/apache2/wordpress-error.log
sudo systemctl restart apache2
```

### Database Issues

```bash
sudo systemctl status mysql
mysql -u wpuser -p wordpress
```

## Cleanup

### Terminate Instance

```bash
aws ec2 terminate-instances --instance-ids YOUR_INSTANCE_ID
```

### Release Elastic IP

```bash
aws ec2 release-address --allocation-id YOUR_ALLOCATION_ID
```

### Delete Resources

```bash
aws ec2 delete-security-group --group-id YOUR_SG_ID
aws ec2 delete-key-pair --key-name YOUR_KEY_NAME
```

## Security Notes

- MySQL root password is auto-generated and saved securely
- WordPress database user has limited privileges
- All credentials saved to `/root/wordpress-credentials.txt` with 600 permissions
- MySQL secure installation removes test databases and anonymous users
- For production use, set up SSL/HTTPS and restrict SSH access


## Cost Estimates

**t4g.micro (free tier):**
- 750 hours/month free for first 12 months
- After free tier: ~$6/month

**Data transfer:**
- First 100 GB/month free
- $0.09/GB thereafter

**Elastic IP:**
- Free while attached to running instance
- $0.005/hour when unattached

## License

MIT License - See LICENSE file for details
