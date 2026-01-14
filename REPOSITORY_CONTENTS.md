# Repository Contents Summary

This repository contains everything needed to deploy WordPress on AWS EC2.

## Core Scripts

### 1. launch-instance.sh
**Purpose:** Launch AWS EC2 ARM instances with interactive configuration

**Features:**
- Interactive region selection (uses AWS_DEFAULT_REGION if set)
- ARM instance type selection (t4g.micro to t4g.2xlarge)
- Number-based selection for existing key pairs
- Number-based selection for existing security groups
- Optional Elastic IP allocation
- Automatic Ubuntu 24.04 ARM64 AMI detection
- Creates security groups with SSH, HTTP, HTTPS access

**Usage:**
```bash
./launch-instance.sh
```

### 2. install-wordpress-apache.sh
**Purpose:** Install WordPress with Apache/MySQL/PHP stack

**Features:**
- Apache 2.4 web server
- MySQL 8.0 with automatic security hardening
- PHP 8.3 with required extensions (including imagick)
- WordPress latest version
- WP-CLI for command-line management
- Automatic public IP detection (avoids private IPs)
- Handles existing MySQL/WordPress installations safely
- Generates secure random passwords
- Saves credentials to /root/wordpress-credentials.txt

**Usage:**
```bash
sudo ./install-wordpress-apache.sh
```

### 3. troubleshoot-wordpress.sh
**Purpose:** Diagnose and fix common WordPress issues

**Features:**
- Checks PHP-FPM status (for NGINX version)
- Verifies socket permissions
- Shows recent error logs
- Tests configurations
- Provides fix commands

**Usage:**
```bash
sudo ./troubleshoot-wordpress.sh
```

### 4. install-wordpress.sh
**Purpose:** Alternative WordPress installer using NGINX

**Features:**
- NGINX instead of Apache
- PHP-FPM for better performance
- All other features same as Apache version
- Includes automatic socket permission fixes

**Usage:**
```bash
sudo ./install-wordpress.sh
```

## Documentation

### README.md
Comprehensive documentation including:
- Complete feature list
- Prerequisites
- Step-by-step installation guide
- Configuration options
- Security features
- Troubleshooting guide
- Advanced usage (WP-CLI, backups, etc.)
- Cleanup instructions

### QUICKSTART.md
Quick 5-minute deployment guide:
- Minimal steps to get WordPress running
- Common commands
- Basic troubleshooting
- Cost estimates

### LICENSE
MIT License - free to use, modify, and distribute

## Repository Setup

### init-github-repo.sh
Automated GitHub repository creation:
- Initializes git repository
- Creates initial commit
- Uses GitHub CLI (gh) or provides manual instructions
- Pushes to GitHub

**Usage:**
```bash
chmod +x init-github-repo.sh
./init-github-repo.sh
```

### .gitignore
Prevents committing:
- SSH keys (*.pem)
- Credentials
- Backup files
- Logs
- OS files

## File Structure

```
aws-ec2-wordpress/
├── README.md                       # Main documentation
├── QUICKSTART.md                   # 5-minute guide
├── LICENSE                         # MIT License
├── .gitignore                      # Git ignore rules
├── launch-instance.sh              # EC2 launcher (main)
├── install-wordpress-apache.sh     # WordPress + Apache (main)
├── install-wordpress.sh            # WordPress + NGINX (alternative)
├── troubleshoot-wordpress.sh       # Troubleshooting tool
└── init-github-repo.sh            # GitHub setup helper
```

## Quick Start

1. **Initialize repository:**
   ```bash
   chmod +x init-github-repo.sh
   ./init-github-repo.sh
   ```

2. **Users can then:**
   ```bash
   git clone https://github.com/USERNAME/aws-ec2-wordpress.git
   cd aws-ec2-wordpress
   ./launch-instance.sh
   # ... follow prompts ...
   scp install-wordpress-apache.sh ubuntu@IP:~
   ssh ubuntu@IP
   sudo ./install-wordpress-apache.sh
   ```

## Key Features Summary

### Launch Script
✅ ARM/Graviton instance support
✅ Number-based resource selection
✅ Automatic AMI detection
✅ Elastic IP support
✅ Interactive and user-friendly

### WordPress Installation
✅ Apache or NGINX options
✅ Public IP auto-detection
✅ MySQL security hardening
✅ Safe handling of existing installations
✅ Automatic credential generation
✅ WP-CLI included

### Safety
✅ Confirmation prompts for destructive actions
✅ Backup creation options
✅ Error handling and validation
✅ Clear warning messages
✅ Credentials saved securely

### Documentation
✅ Comprehensive README
✅ Quick start guide
✅ Inline script comments
✅ Troubleshooting guide
✅ Cost estimates

## Recommended Workflow

1. Fork/clone this repository
2. Run `init-github-repo.sh` to create your own repository
3. Customize scripts as needed
4. Share with your team or community
5. Contribute improvements back

## Support

- Check README.md for detailed documentation
- Check QUICKSTART.md for fast deployment
- Use troubleshoot-wordpress.sh for issues
- Open GitHub issues for bugs/features

## Contributing

Contributions welcome! This is open source (MIT License).

Areas for contribution:
- Additional cloud provider support (Azure, GCP)
- Different OS support (Amazon Linux, Debian)
- Additional web servers (Caddy, Lighttpd)
- WordPress optimization scripts
- Backup automation
- Monitoring setup

---

**Created:** 2026-01-14
**Last Updated:** 2026-01-14
