#!/bin/bash

################################################
# Copyright 2024 Massdriver, Inc 
#
# This script generates a custom install script 
# to be ran on a source server to install the
# replication agent.
#
################################################

read -p "Enter the AWS region (e.g., us-east-1): " AWS_REGION
if [[ ! "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
  echo "Error: Invalid AWS region format. Expected format is something like 'us-east-1'."
  exit 1
fi

read -p "Enter the platform of the source server (Linux, Windows): " PLATFORM
if [[ ! "$PLATFORM" =~ (Linux|linux|LINUX|Windows|windows|WINDOWS) ]]; then
    echo "Error: Invalid platform. Expected 'Linux' or 'Windows'."
    exit 1
fi

read -p "Enter the source server name: " SERVER_NAME
if [[ -z "$SERVER_NAME" ]]; then
    echo "Error: Server name cannot be blank."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/AWSApplicationMigrationAgentInstallationRole"
ROLE_SESSION_NAME="massdriver-aws-mgn"

echo "Assuming role..."
ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$ROLE_SESSION_NAME")
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to assume role."
    exit 1
fi

AWS_ACCESS_KEY_ID=$(echo "$ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_KEY=$(echo "$ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "$ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')

if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_KEY" || -z "$AWS_SESSION_TOKEN" ]]; then
  echo "Error: Failed to extract credentials."
  exit 1
fi

if [[ "$PLATFORM" =~ ^(linux|Linux|LINUX)$ ]]; then
    echo "Paste this bash command into the Linux source server to install the replication agent: "
    echo
    echo "curl -o install.sh https://raw.githubusercontent.com/massdriver-cloud/aws-mgn-scripts/refs/heads/main/install-agent-scripts/install_agent_linux.sh && bash install.sh "$AWS_ACCOUNT_ID" "$AWS_REGION" "$SERVER_NAME" "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_KEY" "$AWS_SESSION_TOKEN""
fi

if [[ "$PLATFORM" =~ ^(windows|Windows|WINDOWS)$ ]]; then
    echo "Paste this PowerShell command into the Windows source server to install the replication agent: "
    echo
    echo "Invoke-WebRequest -Uri https://raw.githubusercontent.com/massdriver-cloud/aws-mgn-scripts/refs/heads/main/install-agent-scripts/install_agent_windows.ps1 -OutFile $env:TEMP\install_agent_windows.ps1; PowerShell -ExecutionPolicy Bypass -File $env:TEMP\install_agent_windows.ps1 -AWSAccountID $AWS_ACCOUNT_ID -AWSRegion $AWS_REGION -SourceServerName $SERVER_NAME -AWSAccessKeyID $AWS_ACCESS_KEY_ID -AWSSecretAccessKey $AWS_SECRET_KEY -AWSSessionToken $AWS_SESSION_TOKEN"
fi
