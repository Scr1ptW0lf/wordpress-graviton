#!/bin/bash

# AWS EC2 ARM Instance Launch Script with Elastic IP
# Launches ARM-based instances with Ubuntu 24.04 LTS ARM64

set -e

echo "=== AWS EC2 ARM Ubuntu Instance Launcher ==="
echo ""

# Function to get Ubuntu 24.04 ARM64 AMI for a region
get_ubuntu_ami() {
    local region=$1
    # Get the latest Ubuntu 24.04 LTS ARM64 AMI
    aws ec2 describe-images \
        --region "$region" \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*" \
                  "Name=state,Values=available" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text
}

# Check for default region
if [ -n "$AWS_DEFAULT_REGION" ]; then
    echo "AWS default region detected: $AWS_DEFAULT_REGION"
    read -p "Use this region? (y/n, default: y): " use_default
    use_default=${use_default:-y}
    
    if [ "$use_default" == "y" ]; then
        REGION="$AWS_DEFAULT_REGION"
        echo "Using region: $REGION"
    else
        use_default="n"
    fi
else
    use_default="n"
fi

# Prompt for region if not using default
if [ "$use_default" == "n" ]; then
    echo ""
    echo "Available regions for ARM instances:"
    echo "1. us-east-1 (N. Virginia)"
    echo "2. us-east-2 (Ohio)"
    echo "3. us-west-2 (Oregon)"
    echo "4. eu-west-1 (Ireland)"
    echo "5. eu-central-1 (Frankfurt)"
    echo "6. ap-southeast-1 (Singapore)"
    echo "7. ap-northeast-1 (Tokyo)"
    echo "8. Enter custom region"
    echo ""
    read -p "Select region (1-8): " region_choice

    case $region_choice in
        1) REGION="us-east-1" ;;
        2) REGION="us-east-2" ;;
        3) REGION="us-west-2" ;;
        4) REGION="eu-west-1" ;;
        5) REGION="eu-central-1" ;;
        6) REGION="ap-southeast-1" ;;
        7) REGION="ap-northeast-1" ;;
        8) read -p "Enter region code: " REGION ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
    
    echo "Selected region: $REGION"
fi

# Prompt for instance type
echo ""
echo "Select instance type (ARM/Graviton):"
echo "1. t4g.micro   (2 vCPU, 1 GB RAM)   - Free tier eligible"
echo "2. t4g.small   (2 vCPU, 2 GB RAM)   - ~\$0.0168/hr"
echo "3. t4g.medium  (2 vCPU, 4 GB RAM)   - ~\$0.0336/hr"
echo "4. t4g.large   (2 vCPU, 8 GB RAM)   - ~\$0.0672/hr"
echo "5. t4g.xlarge  (4 vCPU, 16 GB RAM)  - ~\$0.1344/hr"
echo "6. t4g.2xlarge (8 vCPU, 32 GB RAM)  - ~\$0.2688/hr"
echo "7. Enter custom ARM instance type"
echo ""
read -p "Select instance type (1-7): " instance_choice

case $instance_choice in
    1) INSTANCE_TYPE="t4g.micro" ;;
    2) INSTANCE_TYPE="t4g.small" ;;
    3) INSTANCE_TYPE="t4g.medium" ;;
    4) INSTANCE_TYPE="t4g.large" ;;
    5) INSTANCE_TYPE="t4g.xlarge" ;;
    6) INSTANCE_TYPE="t4g.2xlarge" ;;
    7) read -p "Enter instance type (e.g., c7g.medium): " INSTANCE_TYPE ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

echo "Selected instance type: $INSTANCE_TYPE"
echo ""
echo "Fetching latest Ubuntu 24.04 ARM64 AMI..."

AMI_ID=$(get_ubuntu_ami "$REGION")

if [ -z "$AMI_ID" ]; then
    echo "Error: Could not find Ubuntu ARM64 AMI in region $REGION"
    exit 1
fi

echo "Found AMI: $AMI_ID"
echo ""

# List existing key pairs
echo "Fetching existing key pairs in $REGION..."
EXISTING_KEYS=$(aws ec2 describe-key-pairs \
    --region "$REGION" \
    --query 'KeyPairs[*].KeyName' \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_KEYS" ]; then
    echo "Existing key pairs in $REGION:"
    # Convert to array for number selection
    mapfile -t KEY_ARRAY < <(echo "$EXISTING_KEYS" | tr '\t' '\n')
    for i in "${!KEY_ARRAY[@]}"; do
        echo "$((i+1)). ${KEY_ARRAY[$i]}"
    done
    echo ""
else
    echo "No existing key pairs found in $REGION"
    echo ""
fi

# Prompt for key pair
read -p "Enter key pair name, number to select from list, or press Enter to create new: " KEY_INPUT
CREATE_NEW_KEY=false

if [ -z "$KEY_INPUT" ]; then
    KEY_NAME="arm-key-$(date +%s)"
    CREATE_NEW_KEY=true
    echo "Will create new key pair: $KEY_NAME"
elif [[ "$KEY_INPUT" =~ ^[0-9]+$ ]] && [ -n "$EXISTING_KEYS" ]; then
    # User entered a number
    if [ "$KEY_INPUT" -ge 1 ] && [ "$KEY_INPUT" -le "${#KEY_ARRAY[@]}" ]; then
        KEY_NAME="${KEY_ARRAY[$((KEY_INPUT-1))]}"
        echo "Will use existing key pair: $KEY_NAME"
    else
        echo "Invalid selection number"
        exit 1
    fi
else
    KEY_NAME="$KEY_INPUT"
    echo "Will use existing key pair: $KEY_NAME"
fi

echo ""

# List existing security groups
echo "Fetching existing security groups in $REGION..."
EXISTING_SGS=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_SGS" ]; then
    echo "Existing security groups in $REGION:"
    # Convert to arrays for number selection
    mapfile -t SG_LINES < <(echo "$EXISTING_SGS")
    declare -a SG_ID_ARRAY
    declare -a SG_NAME_ARRAY
    declare -a SG_DESC_ARRAY

    for line in "${SG_LINES[@]}"; do
        read -r sg_id sg_name sg_desc <<< "$line"
        SG_ID_ARRAY+=("$sg_id")
        SG_NAME_ARRAY+=("$sg_name")
        SG_DESC_ARRAY+=("$sg_desc")
    done

    for i in "${!SG_ID_ARRAY[@]}"; do
        echo "$((i+1)). ${SG_ID_ARRAY[$i]} - ${SG_NAME_ARRAY[$i]} (${SG_DESC_ARRAY[$i]})"
    done
    echo ""
else
    echo "No existing security groups found in $REGION"
    echo ""
fi

# Prompt for security group
read -p "Enter security group ID, number to select from list, or press Enter to create new: " SG_INPUT
CREATE_NEW_SG=false

if [ -z "$SG_INPUT" ]; then
    SG_NAME="arm-sg-$(date +%s)"
    CREATE_NEW_SG=true
    echo "Will create new security group: $SG_NAME"
    echo "  - Port 22 (SSH) - open to 0.0.0.0/0"
    echo "  - Port 80 (HTTP) - open to 0.0.0.0/0"
    echo "  - Port 443 (HTTPS) - open to 0.0.0.0/0"
elif [[ "$SG_INPUT" =~ ^[0-9]+$ ]] && [ -n "$EXISTING_SGS" ]; then
    # User entered a number
    if [ "$SG_INPUT" -ge 1 ] && [ "$SG_INPUT" -le "${#SG_ID_ARRAY[@]}" ]; then
        SG_ID="${SG_ID_ARRAY[$((SG_INPUT-1))]}"
        echo "Will use existing security group: $SG_ID (${SG_NAME_ARRAY[$((SG_INPUT-1))]})"
        echo "Note: Ensure ports 22, 80, and 443 are open if needed"
    else
        echo "Invalid selection number"
        exit 1
    fi
else
    SG_ID="$SG_INPUT"
    echo "Will use existing security group: $SG_ID"
    echo "Note: Ensure ports 22, 80, and 443 are open if needed"
fi

echo ""

# Prompt for Elastic IP
read -p "Allocate and assign an Elastic IP? (y/n, default: n): " ALLOCATE_EIP
ALLOCATE_EIP=${ALLOCATE_EIP:-n}

echo ""
read -p "Enter instance name tag (default: ubuntu-arm-instance): " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-ubuntu-arm-instance}

echo ""
echo "=== Launch Configuration ==="
echo "Region: $REGION"
echo "Instance Type: $INSTANCE_TYPE"
echo "AMI: $AMI_ID (Ubuntu 24.04 ARM64)"
echo "Key Pair: $KEY_NAME $([ "$CREATE_NEW_KEY" == true ] && echo '(will be created)')"
echo "Security Group: $([ "$CREATE_NEW_SG" == true ] && echo "$SG_NAME (will be created)" || echo "$SG_ID")"
echo "Name: $INSTANCE_NAME"
echo "Elastic IP: $([ "$ALLOCATE_EIP" == "y" ] && echo 'Yes' || echo 'No')"
echo ""
read -p "Launch instance? (y/n, default: y): " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ]; then
    echo "Launch cancelled"
    exit 0
fi

echo ""
echo "Starting launch process..."

# Create key pair if needed
if [ "$CREATE_NEW_KEY" == true ]; then
    echo ""
    echo "Creating key pair: $KEY_NAME"
    aws ec2 create-key-pair \
        --region "$REGION" \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "  Key saved to: ${KEY_NAME}.pem"
    echo "  IMPORTANT: Download this key file from CloudShell if you need it elsewhere!"
fi

# Create security group if needed
if [ "$CREATE_NEW_SG" == true ]; then
    echo ""
    echo "Creating security group: $SG_NAME"
    
    # Get default VPC
    VPC_ID=$(aws ec2 describe-vpcs \
        --region "$REGION" \
        --filters "Name=isDefault,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text)
    
    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        echo "Error: No default VPC found. Please specify a security group ID."
        exit 1
    fi
    
    SG_ID=$(aws ec2 create-security-group \
        --region "$REGION" \
        --group-name "$SG_NAME" \
        --description "Security group for ARM instance with web access" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' \
        --output text)
    
    echo "  ✓ Created security group: $SG_ID"
    echo "  Adding security rules..."
    
    # Add SSH rule
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SG_ID" \
        --ip-permissions \
        IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges="[{CidrIp=0.0.0.0/0,Description='SSH'}]" \
        > /dev/null
    
    # Add HTTP rule
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SG_ID" \
        --ip-permissions \
        IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges="[{CidrIp=0.0.0.0/0,Description='HTTP'}]" \
        > /dev/null
    
    # Add HTTPS rule
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SG_ID" \
        --ip-permissions \
        IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges="[{CidrIp=0.0.0.0/0,Description='HTTPS'}]" \
        > /dev/null
    
    echo "  ✓ Port 22 (SSH) configured"
    echo "  ✓ Port 80 (HTTP) configured"
    echo "  ✓ Port 443 (HTTPS) configured"
fi

echo ""
echo "Launching instance..."

INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "  ✓ Instance launched: $INSTANCE_ID"
echo "  Waiting for instance to be running..."

aws ec2 wait instance-running \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID"

echo "  ✓ Instance is running!"

# Handle Elastic IP
if [ "$ALLOCATE_EIP" == "y" ]; then
    echo ""
    echo "Allocating Elastic IP..."
    
    ALLOCATION_OUTPUT=$(aws ec2 allocate-address \
        --region "$REGION" \
        --domain vpc \
        --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$INSTANCE_NAME-eip}]")
    
    ALLOCATION_ID=$(echo "$ALLOCATION_OUTPUT" | grep -o '"AllocationId": "[^"]*' | cut -d'"' -f4)
    ELASTIC_IP=$(echo "$ALLOCATION_OUTPUT" | grep -o '"PublicIp": "[^"]*' | cut -d'"' -f4)
    
    echo "  ✓ Elastic IP allocated: $ELASTIC_IP"
    echo "  Associating Elastic IP with instance..."
    
    ASSOCIATION_ID=$(aws ec2 associate-address \
        --region "$REGION" \
        --instance-id "$INSTANCE_ID" \
        --allocation-id "$ALLOCATION_ID" \
        --query 'AssociationId' \
        --output text)
    
    echo "  ✓ Elastic IP associated"
    PUBLIC_IP=$ELASTIC_IP
else
    PUBLIC_IP=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
fi

echo ""
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "Public IP: $PUBLIC_IP"
if [ "$ALLOCATE_EIP" == "y" ]; then
    echo "Elastic IP: Yes (IP will persist after stop/start)"
    echo "Allocation ID: $ALLOCATION_ID"
else
    echo "Elastic IP: No (IP will change if instance is stopped)"
fi
echo "Region: $REGION"
echo "Security: SSH (22), HTTP (80), HTTPS (443) open"
echo ""
echo "Connect with:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo ""
echo "Test web access:"
echo "  curl http://${PUBLIC_IP}"
echo ""
echo "  Wait 30-60 seconds for SSH to become available"

if [ "$ALLOCATE_EIP" == "y" ]; then
    echo ""
    echo "Don't forget about releasing your elastic IP after instance termination to avoid charges! "
fi