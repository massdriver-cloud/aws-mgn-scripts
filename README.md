# aws-mgn-scripts

Scripts for initializing AWS MGN and installing AWS MGN replication agents

## Prerequisites

1. Configure AWS creds using `aws configure`.
2. Fork this repo.

## MGN Setup

### Initialize AWS MGN Service

Run `./init.sh` and answer prompts.

### Create Migration Inventory (optional)

> [!TIP]
>  Migration inventory is great for migration multiple VMs across multiple migration waves, or VMs that are dependent on other VMs (grouped into the same "Application").

1. Run `./inventory.sh` or manually add data to `aws-application-migration-service-import.csv`.
2. Replace all of the `REPLACE` keys with desired values.
3. Update all of the indexes (`0`) where needed.
4. Import completed inventory using `./import.sh`.

## Agent Installation

1. Run `./generate_install_script.sh` and answer prompts.
2. Copy code output and paste into source server to download and install the replication agent.
3. Check AWS MGN console for source server replication status or use:

```bash
aws mgn describe-source-servers --region <region>
```
