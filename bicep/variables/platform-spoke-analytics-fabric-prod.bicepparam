using '../templates/platform-spoke-analytics-fabric.bicep'

// =====================
// Common
// =====================
var scopeOwner = 'ScopeOrTenant'
var productIac = 'spoke-analytics'
var environmentIac = 'prod'
var regionIac = 'westus'
var instanceIac = '300'
var capacityNameBase = replace(productIac, '-', '')
param location = 'westus'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: scopeOwner
}

// =====================
// Platform Spoke Analytics RG: ${scopeOwner}-${productIac}-${regionIac}-${instanceIac}-rg
// Examples: production-spoke-analytics-westus-300-rg or gtc-spoke-analytics-westus-300-rg
// =====================
param capacityName = '${capacityNameBase}${regionIac}${instanceIac}'
param capacitySkuName = 'F2'
// Replace with the Microsoft Entra user identity or object ID for the capacity administrator.
param capacityAdminMembers = [
  'fabric-admin@contoso.com'
]
