using namespace System.Net
using namespace System.Array

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)
Import-Module az.sql

# List of available SQL SKU for DTU
$sqlSkus = @('Basic','S0','S1','S2','S3','S4','S5','S6','S7','S9','S12','P1','P2','P4','P6','P11','P15')

# Checking parameters.
$metricDTU = [int]$Request.Body.data.alertContext.condition.allOf.metricValue
$threshold = $Request.Body.data.alertContext.condition.allOf.operator
$alertCondition = $Request.Body.data.essentials.monitorCondition
$currentSku = (Get-AzSqlDatabase -ResourceGroupName $env:RESOURCEGROUP -ServerName $env:SQLSERVERNAME -DatabaseName $env:SQLDBNAME).currentServiceObjectiveName
$scalingSku = (Get-AzSqlDatabase -ResourceGroupName $env:RESOURCEGROUP -ServerName $env:SQLSERVERNAME -DatabaseName $env:SQLDBNAME).RequestedServiceObjectiveName
$indexSku = [array]::indexof($sqlSkus,$currentSku)
$indexMaxSku = [array]::indexof($sqlSkus,$env:MAXIMUMSKU)
$indexMinSku = [array]::indexof($sqlSkus,$env:MINIMUMSKU)
Write-Host "DB: $env:SQLDBNAME - CurrentServiceServiceObject: $currentSku - RequestedServiceObject: $scalingSku - DTU: $metricDTU - Operator: $threshold - Condition: $alertCondition"

# Checking if the DB is already in scaling (exit if already scaling or the alert is resolved)
if (($currentSku -ne $scalingSku) -or ($alertCondition -ne "Fired")) {
    $body = "DB: $env:SQLDBNAME - Scaling Already in progress or Alert Resolved - Current SKU: $currentSku"
    Write-Host $body
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = $body
    })
    exit 0
}

# Scale actions
try {
    
    #Scale UP Action.
    if ($threshold -eq "GreaterThanOrEqual") {
        if($indexSku -lt $indexMaxSku) {
            $targetsku = $sqlSkus[$indexSku+1]
            # Scale SQL Database UP.
            Set-AzSqlDatabase -ResourceGroupName $env:RESOURCEGROUP -ServerName $env:SQLSERVERNAME -DatabaseName $env:SQLDBNAME -RequestedServiceObjectiveName $targetsku
            $body = "DB: $env:SQLDBNAME - Action required: Scale UP - Previous SKU: $currentSku, New SKU: $targetsku - DTU: $metricDTU"
            Write-Host $body
        }
        else {
            # Maximum SQL SKU reached.
            $body = "DB: $env:SQLDBNAME - Action required: Scale UP - Maximum SKU reached - DTU: $metricDTU"
            Write-Host $body
        }
    }

    # Scale DOWN Action.
    if ($threshold -eq "LessThanOrEqual") {
        if($indexSku -gt $indexMinSku) {
            $targetsku = $sqlSkus[$indexSku-1]
            # Scale SQL Database DOWN.
            Set-AzSqlDatabase -ResourceGroupName $env:RESOURCEGROUP -ServerName $env:SQLSERVERNAME -DatabaseName $env:SQLDBNAME -RequestedServiceObjectiveName $targetsku
            $body = "DB: $env:SQLDBNAME - Action required: Scale DOWN - Previous SKU: $currentSku, New SKU: $targetsku - DTU: $metricDTU"
            Write-Host $body
        }
        else {
            #Minimum SKU reached.
            $body = "DB: $env:SQLDBNAME - Action required: Scale DOWN - Minimum SKU reached - DTU: $metricDTU"
            Write-Host $body
        }
    }
}
catch {
    $body = "DB: $env:SQLDBNAME - Error Scaling the DB - please refer to the Function App log for additional information"
    Write-Host $body
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = $body
    })
    exit 1
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})