# Login and set subscription variables
az login

$mgmtRg = "can-platmgmt-wus2-001-rg"
$mgmtTemplate = "bicep/templates/platform-hub-publicroute-mgmt.bicep"
$mgmtParams = "bicep/variables/platform-hub-publicroute-mgmt.bicepparam"
$networkRg = "can-platnetwork-wus2-001-rg"
$networkTemplate = "bicep/templates/platform-hub-publicroute-network.bicep"
$networkParams = "bicep/variables/platform-hub-publicroute-network.bicepparam"
$hubSubId = "<HubSubID>"

# Create resource groups if not exist
az group create --name $mgmtRg --location westus2
az group create --name $networkRg --location westus2

# Management group deployment: what-if, then deploy if OK
az account set --subscription $hubSubId
az deployment group what-if --resource-group $mgmtRg --template-file $mgmtTemplate --parameters @$mgmtParams
if ($LASTEXITCODE -eq 0) {
    az deployment group create --resource-group $mgmtRg --template-file $mgmtTemplate --parameters @$mgmtParams
}

# Network group deployment: what-if, then deploy if OK
az deployment group what-if --resource-group $networkRg --template-file $networkTemplate --parameters @$networkParams
if ($LASTEXITCODE -eq 0) {
    az deployment group create --resource-group $networkRg --template-file $networkTemplate --parameters @$networkParams
}
