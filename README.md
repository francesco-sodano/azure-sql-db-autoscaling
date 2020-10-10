# Azure SQL DataBase DTU Auto Scaling (ASDAS)

## Introduction

This ARM Template deploys an Azure SQL Database with DTU Consumption plan (with a new Azure SQL Server) including all the resources required to perform Auto Scaling (scale up and scale down) based on Metric Alerts using a function app. Please refer to *ASDAS Architecture* for complete resource list.

The scope of this project is to give the possibility to scale automatically the Azure SQL Database DTU Tier based on DTU consumption usage to reduce costs of the data layer when database is under-utilized.

It's planned to be used in the following cases: 

- In Staging/Test environments to verify the minimum DTUs required to move in production safely.
- In Production environments for applications with **unpredictable** spikes in workload (Please read *Impact of Database Performance/Tier changes* - additional requirement for security and availabilities should be integrated).

For **predictable** workloads (for example: every morning except the weekend), could be better to use a different approach from the one provided here like a [time-triggered Azure Function](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-timer?tabs=csharp) as you can manage Tier changes when your workload is at minimum utilization and you can have minimal and planned distruption.

## Impact of Database Performance/Tier Changes

There is no out-of-the-box Auto scaling feature for Azure SQL DB and there are valid reasons for this.
Each time you perform a Performance/Tier change:

- the switch can result in a brief service interruption when the database is unavailable generally for less than 30 seconds and often for only a few seconds.
- There is latency mostly propotional to the database space used due to data copy (tipically is less than 1 minute per GB) before the change is applied.
- If you're upgrading to a higher service tier or compute size, the database max size doesn't increase - even if is included in the cost - unless you explicitly specify a larger size.
- To downgrade a database, the database used space must be smaller than the maximum allowed size of the target service tier and compute size.
- The restore service offerings are different for the various service tiers. If you're downgrading to the Basic tier, there's a lower backup retention period.
- The Geo-Replication feature present in the Premium Tier requires additional consideration and actions for scaling up or down as the replica must be always in a higher/same tier of the primary.

>For these reasons Azure SQL DB Auto Scaling requires **careful planning and an extensive cost/benefit analysis and most probably some changes/adjustments on how your application is accessing the data layer** including a [retry logic for transient connection errors](https://docs.microsoft.com/en-us/azure/azure-sql/database/troubleshoot-common-connectivity-issues).

Changing the service tier or compute size of mainly involves the service performing the following steps:

1. **Create a new compute instance for the database (sometimes):** A new compute instance is created with the requested service tier and compute size. For some combinations of service tier and compute size changes, a replica of the database must be created in the new compute instance, which involves copying data and can strongly influence the overall latency. Regardless, the database remains online during this step, and connections continue to be directed to the database in the original compute instance.
   
2. **Switch routing of connections to a new compute instance (always):** Existing connections to the database in the original compute instance are dropped. Any new connections are established to the database in the new compute instance. For some combinations of service tier and compute size changes, database files are detached and reattached during the switch. Regardless, the switch can result in a brief service interruption when the database is unavailable generally for less than 30 seconds and often for only a few seconds. If there are long-running transactions running when connections are dropped, the duration of this step may take longer in order to recover aborted transactions.

## ASDAS Architecture

the following Azure artifacts are deployed with the ARM Template:

- SQL Logical Server
- SQL Database (DTU Consumption Plan) with Transparent Data Encryption Enabled and Firewall rule to permit access from Azure services
- 2 Metric Alerts (scaling up and scaling down)
- Action Group to be called by Metric Alerts
- Storage Account (Standard v2 LRS) for Function App deployment
- Hosting Plan (Serverless) for Function App
- Function App (Code - Powershell Core 7.0) with the scaling PowerShell script
- App Insights component for Function App Logs
- Role Assignment for Function App identity (System Assigned) as 'SQL DB Contributor Role' at resource group scope.

![ASDAS Reference Architecture](/images/ReferenceArchitecture.JPG)

*Note: Resource dependencies are not reflected correctly in this image.*

## ASDAS Parameters

To deploy the ASDAS ARM Template, you need to provide some parameters.
These parameters are also used to compose some of the attributes of other artifacts in the template.

the list is the following:

- **storageAccountName**: Storage Account where the Function App will be deployed. Standard Azure restrictions to be followed.
- **sqlServerName**: Name of SQL Logical Server hosting the Azure SQL DB. Standard Azure restrictions to be followed.
- **sqlDBName**: Azure SQL DB Name. Max Lenght allowed 30 characters.
- **sqlAdministratorLogin**: The administrator username of the SQL logical server. Standard Azure restrictionsto be followed.
- **sqlAdministratorLoginPassword**: The administrator password of the SQL logical server. Standard Azure restrictions to be followed.
- **startingSkuTier**: Starting tier of the SQL database, min and max allowed Autiscaling performance SKU, Database tiers. Only allowed values:
  - Basic,Basic,S2,Basic
  - S0,S0,S2,Standard
  - S1,S0,S2,Standard
  - S2,S0,S2,Standard
  - S3,S3,S12,Standard
  - S4,S3,S12,Standard
  - S5,S3,S12,Standard
  - S6,S3,S12,Standard
  - S7,S3,S12,Standard
  - S9,S3,S12,Standard
  - S12,S3,S12,Standard
  - P1,P1,P6,Premium
  - P2,P1,P6,Premium
  - P4,P1,P6,Premium
  - P6,P1,P6,Premium
  - P11,P11,P15,Premium
  - P15,P11,P15,Premium

## ASDAS Defaults and Recommended Settings

ASDAS includes a set parameters already pre-defined **to reduce at the minimum the impact of the Azure Database tier scale**. You can change these default values (editing the *azuredeploy.json* - you should evaluate carefully the impact) but they are not defined as standard ARM Template parameters.

**Action Group** name and short name are pre-defined as they can be reused by multiple instances of ASDAS.

**Hosting Plan** name is pre-defined as it can be reused by multiple instances of ASDAS.

**Alerts** are sent using the [Common Alert Schema](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-common-schema).

**Metrics** are using the following values:

- Scale UP
  - Metric: DTU Consumption Percent
  - Evaluation frequency: 5 minutes
  - Windows Size: 5 minutes
  - Operator: GreaterThanOrEqual
  - Aggragation: Average
  - Threshold: 90
  - Severity: 1

- Scale DOWN
  - Metric: DTU Consumption Percent
  - Evaluation frequency: 5 minutes
  - Windows Size: 5 minutes
  - Operator: LessThanOrEqual
  - Aggragation: Average
  - Threshold: 20
  - Severity: 2

**Scaling function** only operate with this pre-configured database tiers/storage ranges:

- Basic/S0-S2 - 2Gb Storage
- S3-S12 - 250Gb Storage
- P1-P6 - 500Gb Storage
- P11-P15 - 1Tb Storage

## ASDAS Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ffrancesco-sodano%2Fazure-sql-db-autoscaling%2Fvnext%2Fazuredeploy.json)

## ASDAS Limitation and Known Issues

- ASDAS is not supporting Geo-Replicated Azure SQL DBs.
- ASDAS is not supporting the database max size scaling even if included in the costs (be careful with the Basic/S0-S2 range as S0-S2 includes 250Gb Storage and Basic only 2Gb).
- ASDAS is not implementing any backup strategy in the template.
- ASDAS Function App is running in anonymous mode as Azure Monitor (Action Group) is not able to send authenticated requests.  

## References

 - [Resource limits for single databases using the DTU purchasing model - Azure SQL Database](https://docs.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases#single-database-storage-sizes-and-compute-sizes)
 - [Some examples to how achieve Retry-Logic Access to Azure SQL DB](https://docs.microsoft.com/en-us/azure/azure-sql/database/troubleshoot-common-connectivity-issues)
 - [Handling Application Connections during Database Changes](https://docs.microsoft.com/en-us/previous-versions/azure/dn369872(v=azure.100)?redirectedfrom=MSDN#handling-application-connections-during-database-changes)
 - [Overview of alerts in Microsoft Azure](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-overview)
 - [Common Alert Schema](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-common-schema)