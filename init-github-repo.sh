#!/bin/bash

# GitHub Repository Initialization Script
# This script initializes a Git repository and pushes to GitHub

set -e

echo "=== GitHub Repository Setup ==="
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed"
    echo "Install with: brew install git (macOS) or apt-get install git (Linux)"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Warning: GitHub CLI (gh) is not installed"
    echo "Install with: brew install gh (macOS) or see https://cli.github.com"
    echo ""
    echo "You can still create the repo manually at https://github.com/new"
    USE_GH_CLI=false
else
    USE_GH_CLI=true
fi

# Get repository details
read -p "Enter GitHub username: " GH_USERNAME
read -p "Enter repository name (default: aws-ec2-wordpress): " REPO_NAME
REPO_NAME=${REPO_NAME:-aws-ec2-wordpress}
read -p "Repository description: " REPO_DESC
REPO_DESC=${REPO_DESC:-Automated AWS EC2 WordPress deployment with Apache}
read -p "Make repository public? (y/n, default: y): " MAKE_PUBLIC
MAKE_PUBLIC=${MAKE_PUBLIC:-y}

echo ""
echo "=== Configuration ==="
echo "Username: $GH_USERNAME"
echo "Repository: $REPO_NAME"
echo "Description: $REPO_DESC"
echo "Visibility: $([ "$MAKE_PUBLIC" = "y" ] && echo "Public" || echo "Private")"
echo ""
read -p "Continue? (y/n, default: y): " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ]; then
    echo "Setup cancelled"
    exit 0
fi

# Initialize git repository if not already initialized
if [ ! -d .git ]; then
    echo ""
    echo "Initializing Git repository..."
    git init
    echo "Git repository initialized"
else
    echo ""
    echo "Git repository already initialized"
fi

# Add all files
echo ""
echo "Adding files to Git..."
git add .

# Create initial commit
echo ""
echo "Creating initial commit..."
if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "No changes to commit"
else
    git commit -m "Initial commit: AWS EC2 WordPress deployment scripts

- EC2 instance launcher with interactive configuration
- WordPress installation script with Apache/MySQL
- Troubleshooting utilities
- Comprehensive documentation"
    echo "Initial commit created"
fi

# Rename branch to main if needed
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo ""
    echo "Renaming branch to 'main'..."
    git branch -M main
fi

# Create repository on GitHub
if [ "$USE_GH_CLI" = true ]; then
    echo ""
    echo "Creating GitHub repository..."

    if [ "$MAKE_PUBLIC" = "y" ]; then
        VISIBILITY="--public"
    else
        VISIBILITY="--private"
    fi

    # Check if user is authenticated
    if ! gh auth status &> /dev/null; then
        echo "Not authenticated with GitHub CLI"
        echo "Running: gh auth login"
        gh auth login
    fi

    # Create the repository
    if gh repo create "$GH_USERNAME/$REPO_NAME" $VISIBILITY --description "$REPO_DESC" --source=. --push; then
        echo "Repository created and pushed successfully!"
    else
        echo "Error creating repository with gh CLI"
        echo "You may need to create it manually"
    fi
else
    echo ""
    echo "=== Manual Setup Required ==="
    echo ""
    echo "1. Go to: https://github.com/new"
    echo "2. Repository name: $REPO_NAME"
    echo "3. Description: $REPO_DESC"
    echo "4. Visibility: $([ "$MAKE_PUBLIC" = "y" ] && echo "Public" || echo "Private")"
    echo "5. Click 'Create repository' (DO NOT initialize with README)"
    echo ""
    echo "Then run these commands:"
    echo ""
    echo "  git remote add origin https://github.com/$GH_USERNAME/$REPO_NAME.git"
    echo "  git push -u origin main"
    echo ""
    read -p "Press Enter after creating the repository on GitHub..."

    # Add remote and push
    echo ""
    echo "Adding remote origin..."
    if git remote | grep -q "^origin$"; then
        echo "Remote 'origin' already exists"
        git remote set-url origin "https://github.com/$GH_USERNAME/$REPO_NAME.git"
    else
        git remote add origin "https://github.com/$GH_USERNAME/$REPO_NAME.git"
    fi

    echo ""
    echo "Pushing to GitHub..."
    git push -u origin main
fi

echo ""
echo "=========================================="
echo "=== Setup Complete! ==="
echo "=========================================="
echo ""
echo "Repository URL: https://github.com/$GH_USERNAME/$REPO_NAME"
echo ""
echo "Clone with:"
echo "  git clone https://github.com/$GH_USERNAME/$REPO_NAME.git"
echo ""
echo "Next steps:"
echo "1. Visit your repository on GitHub"
echo "2. Add topics/tags for discoverability"
echo "3. Enable GitHub Pages (optional)"
echo "4. Set up branch protection (optional)"
echo ""
echo "=========================================="
