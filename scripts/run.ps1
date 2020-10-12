using namespace System.Net
using namespace System.Array

# Input bindings and module import.
param($Request, $TriggerMetadata)
Import-Module az.sql

# Function RequestAnswer: Support for sending answer back to the requester and write logs.
function Send-Answer {
    param (
        [string]$Answer,
        [bool]$WriteHost
    )
    process {
        if($WriteHost){
            Write-Host $answer
        }
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body = $answer
        })
    }
}

# List of available SQL Tiers for DTU
$sqlSkus = @("Basic","S0","S1","S2","S3","S4","S5","S6","S7","S9","S12","P1","P2","P4","P6","P11","P15")

# Checking Environment variables
$resourceGroupName = $env:RESOURCEGROUP
$serverName = $env:SQLSERVERNAME
$databaseName = $env:SQLDBNAME
$maxsku = $env:MAXIMUMSKU
$minsku = $env:MINIMUMSKU
if ((!$resourceGroupName) -or (!$serverName) -or (!$databaseName) -or (!$maxsku) -or (!$minsku)){
    Send-Answer -Answer "ASDAS - Critical Alert: Missing one or more environment variables in the Function App - No Action" -WriteHost $true
    exit 1
}

# Checking Request variables (Azure Common Alert Schema)
$metricDTU = [int]$Request.Body.data.alertContext.condition.allOf.metricValue
$threshold = $Request.Body.data.alertContext.condition.allOf.operator
$alertCondition = $Request.Body.data.essentials.monitorCondition
if ((!$metricDTU) -or (!$threshold) -or (!$alertCondition)){
    Send-Answer -Answer "ASDAS - Wrong request - No Action" -WriteHost $true
    exit 1
}

# Checking Database current status
$database = Get-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName -databaseName $DatabaseName
if(!$database){
    Send-Answer -Answer "ASDAS - Database, Server or Resource Group does not exist - No Action" - Write-Host $true
    exit 1
}
else {
    $currentSku = $databaseName.currentServiceObjectiveName
    $scalingSku = $database.RequestedServiceObjectiveName
    $indexSku = [array]::indexof($sqlSkus,$currentSku)
    $indexMaxSku = [array]::indexof($sqlSkus,$maxsku)
    $indexMinSku = [array]::indexof($sqlSkus,$minsku)
    Write-Host "ASDAS - DB: $DatabaseName - CurrentTier: $currentSku - ScalingTier: $scalingSku - DTU: $metricDTU - Operator: $threshold - Alert Condition: $alertCondition"
}

# Checking if the DB is already in scaling or the alert is resolved.
if (($currentSku -ne $scalingSku) -or ($alertCondition -ne "Fired")) {
    Send-Answer -answer "ASDAS - DB: $DatabaseName - Scaling Already in progress or Alert Resolved - Current SKU: $currentSku" -WriteHost $true
    exit 0
}

# Scale Actions
try {
    
    #Scale UP Action.
    if ($threshold -eq "GreaterThanOrEqual") {
        if($indexSku -lt $indexMaxSku) {
            $targetsku = $sqlSkus[$indexSku+1]
            # Scale SQL Database UP.
            Set-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName -DatabaseName $databaseName -RequestedServiceObjectiveName $targetsku
            $body = "ASDAS - DB: $DatabaseName - Action required: Scale UP - Previous SKU: $currentSku, New SKU: $targetsku - DTU: $metricDTU"
            Write-Host $body
        }
        else {
            # Maximum SQL SKU reached.
            $body = "ASDAS - DB: $DatabaseName - Action required: Scale UP - Maximum SKU reached - DTU: $metricDTU"
            Write-Host $body
        }
    }

    # Scale DOWN Action.
    if ($threshold -eq "LessThanOrEqual") {
        if($indexSku -gt $indexMinSku) {
            $targetsku = $sqlSkus[$indexSku-1]
            # Scale SQL Database DOWN.
            Set-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName -databaseName $DatabaseName -RequestedServiceObjectiveName $targetsku
            $body = "ASDAS - DB: $DatabaseName - Action required: Scale DOWN - Previous SKU: $currentSku, New SKU: $targetsku - DTU: $metricDTU"
            Write-Host $body
        }
        else {
            # Minimum SKU reached.
            $body = "ASDAS - DB: $DatabaseName - Action required: Scale DOWN - Minimum SKU reached - DTU: $metricDTU"
            Write-Host $body
        }
    }
}
catch {
    Send-Answer -Answer "ASDAS - DB: $DatabaseName - Error Scaling the DB - please refer to the Function App log for additional information" -WriteHost $true
    exit 1
}

# Send Response.
Send-Answer -Answer $body -WriteHost $false
