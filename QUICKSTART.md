# Quick Start Guide

Get WordPress running on AWS EC2 in 5 minutes!

## Prerequisites

- AWS account with configured credentials
- SSH client

## Step 1: Launch EC2 Instance (2 minutes)

```bash
./launch-instance.sh
```

**Select:**
- Region (or use default)
- Instance type: `1` for t4g.micro (free tier)
- Press Enter to create new key pair
- Press Enter to create new security group
- Press Enter to skip Elastic IP
- Enter instance name or press Enter for default

**Save the output:**
- Public IP address
- SSH command
- Key file location

## Step 2: Install WordPress (3 minutes)

Copy the script to your instance:

```bash
scp -i YOUR-KEY.pem install-wordpress-apache.sh ubuntu@YOUR-PUBLIC-IP:~
```

SSH and run the installer:

```bash
ssh -i YOUR-KEY.pem ubuntu@YOUR-PUBLIC-IP
chmod +x install-wordpress-apache.sh
sudo ./install-wordpress-apache.sh
```

**When prompted:**
- Press Enter for all defaults (easiest option)
- Or enter custom values for:
  - Domain name (leave blank to use IP)
  - Site title
  - Admin username
  - Admin password (auto-generated if blank)
  - Admin email

## Step 3: Access WordPress

1. Visit: `http://YOUR-PUBLIC-IP`
2. Login: `http://YOUR-PUBLIC-IP/wp-admin`
3. Use the credentials shown in the installer output

**Done!** 🎉

## What You Get

- ✅ Ubuntu 24.04 LTS on ARM (Graviton)
- ✅ Apache 2.4 web server
- ✅ MySQL 8.0 database
- ✅ PHP 8.3 with extensions
- ✅ WordPress (latest version)
- ✅ WP-CLI installed
- ✅ Secure configuration

## Common Commands

### View WordPress credentials
```bash
sudo cat /root/wordpress-credentials.txt
```

### Restart Apache
```bash
sudo systemctl restart apache2
```

### WordPress management with WP-CLI
```bash
cd /var/www/html/wordpress
sudo -u www-data wp plugin list
sudo -u www-data wp theme list
```

### Check Apache logs
```bash
sudo tail -f /var/log/apache2/wordpress-error.log
```

## Next Steps

1. **Set up SSL/HTTPS:**
   ```bash
   sudo apt-get install -y certbot python3-certbot-apache
   sudo certbot --apache
   ```

2. **Install security plugin:**
   - Login to WordPress admin
   - Go to Plugins → Add New
   - Search for "Wordfence" or "Sucuri"

3. **Set up backups:**
   - Install "UpdraftPlus" plugin
   - Configure to backup to AWS S3 or Google Drive

4. **Change permalink structure:**
   - Go to Settings → Permalinks
   - Select "Post name"
   - Click "Save Changes"

## Cleanup (When Done Testing)

```bash
# Terminate instance
aws ec2 terminate-instances --instance-ids YOUR-INSTANCE-ID

# Delete key pair (optional)
aws ec2 delete-key-pair --key-name YOUR-KEY-NAME
rm YOUR-KEY.pem
```

## Troubleshooting

**Can't connect via SSH?**
- Check security group allows port 22 from your IP
- Verify key file permissions: `chmod 400 YOUR-KEY.pem`

**Can't access WordPress?**
- Check security group allows port 80
- Verify instance has public IP
- Check Apache: `sudo systemctl status apache2`

**502 errors?** (Shouldn't happen with Apache, but if it does)
- Restart Apache: `sudo systemctl restart apache2`
- Check PHP: `php -v`

## Cost Estimate

**t4g.micro (free tier eligible):**
- First 750 hours/month free for 12 months
- After free tier: ~$6/month (if running 24/7)

**Data transfer:**
- First 100 GB/month free
- $0.09/GB after that

**Elastic IP (if allocated):**
- Free while attached to running instance
- $0.005/hour when NOT attached

---

**Need help?** Check the main [README.md](README.md) for detailed documentation.
