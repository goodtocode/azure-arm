using '../templates/platform-hub.bicep'

// =====================
// Common
// =====================
var environmentIac = 'prod'
param location = 'West US 2'
param prefix = 'gtc'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: 'esa-hub'
  owner: 'goodtocode'
}

// =====================
// Log Analytics Workspace
// =====================
param logAnalyticsWorkspaceName = '${prefix}-hub-${environmentIac}-law'
// Add more log analytics parameters as needed

// =====================
// Key Vault
// =====================
param keyVaultName = '${prefix}-hub-${environmentIac}-kv'
// Add more key vault parameters as needed

// =====================
// Virtual Network
// =====================
param vnetName = '${prefix}-hub-${environmentIac}-vnet'
param vnetAddressPrefix = '10.10.0.0/16'
// Add more vnet parameters as needed

// =====================
// Firewall
// =====================
param firewallName = '${prefix}-hub-${environmentIac}-fw'
// Add more firewall parameters as needed

// =====================
// Add additional modules/resources below as needed
