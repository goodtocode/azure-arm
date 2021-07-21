ECHO Dependent on https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

ECHO *** Auth ****
az login & az account set --subscription SubscriptionID & ECHO Authenticated

ECHO *** Key Vaults soft-deletes ***
az keyvault list-deleted
az keyvault purge --name NAME

ECHO *** Cognitive Services soft-deletes ***
az cognitiveservices account list-deleted
az cognitiveservices account purge --name NAME --location LOCATION --resource-group RESORUCE_GROUP