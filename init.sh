#!/bin/bash

#########################################################################
# Copyright 2024 Massdriver, Inc                                        #
#                                                                       #
# This script initializes the requires roles and policies required for  #
# AWS Application Migration Service (MGN). It also enables the service  #
# in the region specified during execution. Lastly, it configures       #
# default replication and launch templates.                             #
#                                                                       #
#########################################################################

prompt_user() {
    local prompt="$1"
    local regex="$2"
    local error_message="$3"
    local result_var="$4"

    while true; do
        read -p "$prompt" input
        if [[ "$input" =~ $regex ]]; then
            eval "$result_var='$input'"
            break
        else
            echo "$error_message"
        fi
    done
}

prompt_user "Enter the AWS region (e.g., us-east-1): " \
    "^[a-z]{2}-[a-z]+-[0-9]+$" \
    "Error: Invalid AWS region format. Expected format is something like 'us-east-1'." \
    AWS_REGION

prompt_user "Set replication server IP type (PUBLIC_IP, PRIVATE_IP): " \
    "^(PUBLIC_IP|PRIVATE_IP)$" \
    "Error: Invalid IP type. Expected 'PUBLIC_IP' or 'PRIVATE_IP'." \
    IP_TYPE

prompt_user "Set replication server disk type (GP2, GP3, ST1): " \
    "^(GP2|GP3|ST1)$" \
    "Error: Invalid disk type. Expected 'GP2', 'GP3', or 'ST1'." \
    DISK_TYPE

prompt_user "Set replication server EBS encryption (DEFAULT, CUSTOM): " \
    "^(DEFAULT|CUSTOM)$" \
    "Error: Invalid EBS encryption type. Expected 'DEFAULT' or 'CUSTOM'." \
    EBS_ENCRYPTION

prompt_user "Set replication server instance type (e.g., t2.micro): " \
    "^[a-z]{1}[0-9]{1}\.[a-z]+$" \
    "Error: Invalid instance type. Expected format is something like 't2.micro' or 'c5.xlarge'." \
    INSTANCE_TYPE

prompt_user "Set replication server staging area subnet ID (e.g., subnet-01234abcde). Make sure the subnet is in the same region: " \
    "^subnet-[a-z0-9]+$" \
    "Error: Invalid staging subnet ID. Expected format is something like 'subnet-01234abcde'." \
    STAGING_SUBNET

prompt_user "Set replication server staging area tags (e.g., Key=value,Foo=bar): " \
    "^([a-zA-Z0-9-]+=[a-zA-Z0-9-]+)(,[a-zA-Z0-9-]+=[a-zA-Z0-9-]+)*$" \
    "Error: Invalid staging tags. Expected format is something like 'key=value,Foo=Bar'." \
    STAGING_TAGS

# Handling yes/no prompts with simple logic
read -p "Do you want to associate a default security group for replication server? (yes/no): " ASSOCIATE_SG
ASSOCIATE_SG_ARG="--no-associate-default-security-group"
if [[ "$ASSOCIATE_SG" =~ ^(yes|y)$ ]]; then
    ASSOCIATE_SG_ARG="--associate-default-security-group"
fi

read -p "Do you want to create a public IP for replication server? (yes/no): " CREATE_PUBLIC_IP
CREATE_PUBLIC_IP_ARG="--no-create-public-ip"
if [[ "$CREATE_PUBLIC_IP" =~ ^(yes|y)$ ]]; then
    CREATE_PUBLIC_IP_ARG="--create-public-ip"
fi

read -p "Do you want to use a dedicated replication server? (yes/no): " USE_DEDICATED_REPLICATION_SERVER
DEDICATED_REPLICATION_SERVER_ARG="--no-use-dedicated-replication-server"
if [[ "$USE_DEDICATED_REPLICATION_SERVER" =~ ^(yes|y)$ ]]; then
    DEDICATED_REPLICATION_SERVER_ARG="--use-dedicated-replication-server"
fi

prompt_user "Set launch server boot mode (LEGACY_BIOS, UEFI, USE_SOURCE). USE_SOURCE recommended: " \
    "^(LEGACY_BIOS|UEFI|USE_SOURCE)$" \
    "Error: Invalid boot mode. Expected 'LEGACY_BIOS', 'UEFI', or 'USE_SOURCE'." \
    BOOT_MODE

prompt_user "Set instance state upon launch (STARTED, STOPPED): " \
    "^(STARTED|STOPPED)$" \
    "Error: Invalid launch mode. Expected 'STARTED' or 'STOPPED'." \
    LAUNCH_MODE

read -p "Is server BYOL (Bring Your Own Licensing)? (yes/no): " LICENSE
LICENSE_ARG="osByol=false"
if [[ "$LICENSE" =~ ^(yes|y)$ ]]; then
    LICENSE_ARG="osByol=true"
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

create_role_attach_policies() {
    local role_name=$1
    local policy_document=$2
    local path=$3
    shift 3
    local policies=("$@")
    echo "Creating role $role_name..."
    aws iam create-role --path "$path" --role-name "$role_name" --assume-role-policy-document "$policy_document" 2>>init.log
    if [[ $? -ne 0 ]]; then
        if grep -q "EntityAlreadyExists" init.log; then
            echo "Role $role_name already exists."
        else
            echo "Error creating role $role_name:"
            cat init.log
        fi
    else
        echo "Role $role_name created successfully."
    fi

    for policy in "${policies[@]}"; do
        echo "Attaching policy $policy to role $role_name..."
        aws iam attach-role-policy --policy-arn "$policy" --role-name "$role_name" 2>>init.log
        if [[ $? -ne 0 ]]; then
            echo "Error attaching policy $policy to role $role_name:"
            cat init.log
        else
            echo "Policy $policy attached successfully."
        fi
    done
}

# AWSApplicationMigrationReplicationServerRole
create_role_attach_policies \
    "AWSApplicationMigrationReplicationServerRole" \
    '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": { "Service": "ec2.amazonaws.com" },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    "/service-role/" \
    "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationReplicationServerPolicy"

# AWSApplicationMigrationConversionServerRole
create_role_attach_policies \
    "AWSApplicationMigrationConversionServerRole" \
    '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": { "Service": "ec2.amazonaws.com" },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    "/service-role/" \
    "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationConversionServerPolicy"

# AWSApplicationMigrationMGHRole
create_role_attach_policies \
    "AWSApplicationMigrationMGHRole" \
    '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": { "Service": "mgn.amazonaws.com" },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    "/service-role/" \
    "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationMGHAccess"

# AWSApplicationMigrationLaunchInstanceWithDrsRole
create_role_attach_policies \
    "AWSApplicationMigrationLaunchInstanceWithDrsRole" \
    '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": { "Service": "ec2.amazonaws.com" },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    "/service-role/" \
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" \
    "arn:aws:iam::aws:policy/service-role/AWSElasticDisasterRecoveryEc2InstancePolicy"

# AWSApplicationMigrationLaunchInstanceWithSsmRole
create_role_attach_policies \
    "AWSApplicationMigrationLaunchInstanceWithSsmRole" \
    '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": { "Service": "ec2.amazonaws.com" },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    "/service-role/" \
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

# AWSApplicationMigrationAgentRole
create_role_attach_policies \
    "AWSApplicationMigrationAgentRole" \
    "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Effect\": \"Allow\",
          \"Principal\": {
            \"Service\": \"mgn.amazonaws.com\"
          },
          \"Action\": [
            \"sts:AssumeRole\",
            \"sts:SetSourceIdentity\"
          ],
          \"Condition\": {
            \"StringLike\": {
              \"sts:SourceIdentity\": \"s-*\",
              \"aws:SourceAccount\": \"$ACCOUNT_ID\"
            }
          }
        }
      ]
    }" \
    "/service-role/" \
    "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationAgentPolicy_v2"

# AWSApplicationMigrationAgentInstallationRole
echo "Creating role AWSApplicationMigrationAgentInstallationRole..."
aws iam create-role --role-name "AWSApplicationMigrationAgentInstallationRole" --assume-role-policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
          {
            \"Effect\": \"Allow\",
            \"Principal\": {
              \"AWS\": \"arn:aws:iam::$ACCOUNT_ID:root\"
            },
            \"Action\": \"sts:AssumeRole\"
          }
        ]
    }" 2>>init.log

if [[ $? -ne 0 ]]; then
    if grep -q "EntityAlreadyExists" init.log; then
        echo "Role AWSApplicationMigrationAgentInstallationRole already exists."
    else
        echo "Error creating role AWSApplicationMigrationAgentInstallationRole:"
        cat init.log
    fi
else
    echo "Role AWSApplicationMigrationAgentInstallationRole created successfully."
fi

echo "Attaching policy arn:aws:iam::aws:policy/AWSApplicationMigrationAgentInstallationPolicy to role AWSApplicationMigrationAgentInstallationRole..."
aws iam attach-role-policy --policy-arn "arn:aws:iam::aws:policy/AWSApplicationMigrationAgentInstallationPolicy" --role-name "AWSApplicationMigrationAgentInstallationRole"
if [[ $? -ne 0 ]]; then
    echo "Error attaching policy to AWSApplicationMigrationAgentInstallationRole:"
    cat init.log
else
    echo "Policy attached successfully to AWSApplicationMigrationAgentInstallationRole."
fi

echo "Initializing MGN service..."
aws mgn initialize-service --region "$AWS_REGION" 2>>init.log
if [[ $? -ne 0 ]]; then
    if grep -q "AlreadyInitialized" init.log; then
        echo "MGN service is already initialized in region $AWS_REGION."
    else
        echo "Error initializing MGN service:"
        cat init.log
    fi
else
    echo "MGN service initialized successfully."
fi

echo "Creating replication configuration template..."
aws mgn create-replication-configuration-template \
    --region "$AWS_REGION" \
    --bandwidth-throttling 0 \
    --data-plane-routing "$IP_TYPE" \
    --default-large-staging-disk-type "$DISK_TYPE" \
    --ebs-encryption "$EBS_ENCRYPTION" \
    --replication-server-instance-type "$INSTANCE_TYPE" \
    --staging-area-subnet-id "$STAGING_SUBNET" \
    --staging-area-tags "$STAGING_TAGS" \
    --replication-servers-security-groups-ids \
    $ASSOCIATE_SG_ARG \
    $CREATE_PUBLIC_IP_ARG \
    $DEDICATED_REPLICATION_SERVER_ARG \
    2>>init.log

if [[ $? -ne 0 ]]; then
    if grep -q "ServiceQuotaExceededException" init.log; then
        echo "Replication configuration template already exists for region $AWS_REGION."
    else
        echo "Error creating replication configuration template:"
        cat init.log
    fi
else
    echo "Replication configuration template created successfully."
fi

echo "Creating launch configuration template..."
aws mgn create-launch-configuration-template \
    --region "$AWS_REGION" \
    --boot-mode "$BOOT_MODE" \
    --launch-disposition "$LAUNCH_MODE" \
    --licensing "$LICENSE_ARG" \
    --target-instance-type-right-sizing-method BASIC \
    2>>init.log

if [[ $? -ne 0 ]]; then
    if grep -q "ServiceQuotaExceededException" init.log; then
        echo "Launch configuration template already exists for region $AWS_REGION."
    else
        echo "Error creating replication configuration template:"
        cat init.log
    fi
else
    echo "Replication configuration template created successfully."
fi
