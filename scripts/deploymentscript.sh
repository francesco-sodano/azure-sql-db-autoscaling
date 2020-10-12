#!/bin/bash

az deployment group create --name ASDAS --resource-group "rg-demo-azsqlscaling" --template-uri https://raw.githubusercontent.com/francesco-sodano/azure-sql-db-autoscaling/vnext/azuredeploy.json --parameters https://raw.githubusercontent.com/francesco-sodano/azure-sql-db-autoscaling/vnext/
azuredeploy.parameters.json --rollback-on-error