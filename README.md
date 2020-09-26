# Azure SQL DB Auto Scaling (ASDAS)

## Introduction

For a predictable workloads (like every morning except the weekend), could be better to use a different approach like the one provided here.

## Why there is no out-of-the-box feature for this?

There is no out-of-the-box Auto scaling feature for Azure SQL DB in Azure and there are more than one reason for that:

Each time you perform a Performance/Tier change:

- the switch can result in a brief service interruption when the database is unavailable generally for less than 30 seconds and often for only a few seconds.
- There is latency mostly propotional to the database space used due to data copy (tipically is less than 1 minute per GB) before the change is applied.
- If you're upgrading to a higher service tier or compute size, the database max size doesn't increase - even if is included in the cost - unless you explicitly specify a larger size.
 - To downgrade a database, the database used space must be smaller than the maximum allowed size of the target service tier and compute size.
 - The restore service offerings are different for the various service tiers. If you're downgrading to the Basic tier, there's a lower backup retention period.
 - The Geo-Replication feature present in the Premium Tier requires additional consideration and actions for scaling up or down as the replica must be always in a higher/same tier of the primary.

For these reasons (and many more..) Azure SQL DB Auto Scaling requires **careful planning and an extensive cost/benefit analysis and probably some changes/adjustments on how your application is accessing the data layer.**

## Impact of Database Performance/Tier Changes

Changing the service tier or compute size of mainly involves the service performing the following steps:

1. **Create a new compute instance for the database (sometimes):** A new compute instance is created with the requested service tier and compute size. For some combinations of service tier and compute size changes, a replica of the database must be created in the new compute instance, which involves copying data and can strongly influence the overall latency. Regardless, the database remains online during this step, and connections continue to be directed to the database in the original compute instance.
   
2. **Switch routing of connections to a new compute instance (always):** Existing connections to the database in the original compute instance are dropped. Any new connections are established to the database in the new compute instance. For some combinations of service tier and compute size changes, database files are detached and reattached during the switch. Regardless, the switch can result in a brief service interruption when the database is unavailable generally for less than 30 seconds and often for only a few seconds. If there are long-running transactions running when connections are dropped, the duration of this step may take longer in order to recover aborted transactions.

## ASDAS Architecture

## ASDAS Parameters 

## ASDAS Recommended Settings

For this reasons my suggestion is to use this tool just for the following ranges:

- **Basic/S0-S2**
- **S3-S12**
- **P1-P15**

## ASDAS Deployment

## ASDAS Limitation and Know Issues

- ASDAS is not supporting Geo-Replicated Azure SQL DBs
- 

## References
 - [Resource limits for single databases using the DTU purchasing model - Azure SQL Database](https://docs.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases#single-database-storage-sizes-and-compute-sizes)
 - [Some examples to how achieve Retry-Logic Access to Azure SQL DB](https://docs.microsoft.com/en-us/azure/azure-sql/database/troubleshoot-common-connectivity-issues)
 - [Handling Application Connections during Database Changes](https://docs.microsoft.com/en-us/previous-versions/azure/dn369872(v=azure.100)?redirectedfrom=MSDN#handling-application-connections-during-database-changes)