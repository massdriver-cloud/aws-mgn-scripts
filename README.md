# aws-mgn-scripts

Scripts for initializing AWS MGN and installing AWS MGN replication agents

## MGN Setup

### Initialize AWS MGN service

1. Configure AWS creds using `aws configure`
2. Run `./init.sh`
3. Answer prompts

### Create migration inventory

> [!TIP]
> Migration inventory is great for migration multiple VMs across multiple migration waves, or VMs that are dependent on other VMs (grouped into the same "Application").

1. Run `./inventory.sh` or manually add data to `aws-application-migration-service-import.csv`
2. Import completed inventory using `./import.sh`

## Agent Installation

1. Fetch temporary credentials locally (fill in `AWS_ACCOUNT_ID`):

```bash
AWS_ACCOUNT_ID=
aws sts assume-role \
    --role-arn arn:aws:iam::$AWS_ACCOUNT_ID:role/AWSApplicationMigrationAgentInstallationRole \
    --role-sesssion-name massdriver-aws-mgn
```

2. Paste this script into source server (make sure to replace env vars with correct info):

<details>
    <summary>Linux</summary>

```bash
AWS_ACCOUNT_ID=
AWS_REGION=
SERVER_NAME=
AWS_ACCESS_KEY_ID=
AWS_SECRET_KEY=
AWS_SESSION_TOKEN=
curl -o install.sh https://raw.githubusercontent.com/massdriver-cloud/aws-mgn-scripts/refs/heads/main/install_agent_linux.sh && \
bash install.sh $AWS_ACCOUNT_ID $AWS_REGION $SERVER_NAME $AWS_ACCESS_KEY_ID $AWS_SECRET_KEY $AWS_SESSION_TOKEN
```

</details>

<details>
    <summary>Windows</summary>

```powershell
$awsAccountId = $Env:id
$awsRegion = $Env:region
$serverName = $Env:name
$awsAccessKeyId = $Env:accessKey
$awsSecretKey = $Env:secretKey
$awsSessionToken = $Env:sessionToken
Invoke-WebRequest -Uri https://raw.githubusercontent.com/massdriver-cloud/aws-mgn-scripts/refs/heads/main/install_agent_windows.ps1 -OutFile $env:TEMP\install_agent_windows.ps1; PowerShell -ExecutionPolicy Bypass -File $env:TEMP\install_agent_windows.ps1 -AWSAccountID $awsAccountId -AWSRegion $awsRegion -SourceServerName $serverName -AWSAccessKeyID $awsAccessKeyId -AWSSecretAccessKey $awsSecretKey -AWSSessionToken $awsSessionToken
```

</details>

3. Check AWS MGN console for source server replication status or use `aws mgn describe-source-servers --region <region>`
