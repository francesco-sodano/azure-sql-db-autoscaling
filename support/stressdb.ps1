$sqlserver = "sql-azsqlscaling-demo.database.windows.net"
$sqlDb = "sqldb-azsqlscaling-demo"
$user = "fsodano"
$pwd = "1mpossibile!"
$query1 = "SELECT [order_id],[item_id],[product_id],[quantity],[list_price],[discount] FROM [sales].[order_items]"
$query2 = "SELECT [customer_id],[first_name],[last_name],[phone],[email],[street],[city],[state],[zip_code] FROM [sales].[customers]"
$i=1
do {
    $result1 = Invoke-Sqlcmd -ServerInstance $sqlserver -Database $sqlDb -Username $user -Password $pwd -Query $query1
    $result2 = Invoke-Sqlcmd -ServerInstance $sqlserver -Database $sqlDb -Username $user -Password $pwd -Query $query2
    Write-Host "iteazione $i completata"  
    $i= $i+1
} while ($i -lt 10000)