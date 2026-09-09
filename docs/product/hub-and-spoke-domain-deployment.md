# Azure Platform Hub and Spoke Domain Deployment Matrix

Resource groups use the suffix convention from the parameter files:
`<scopeOwner>-<domain>-<environment>-<region>-<instance>-rg`.

The rows remain grouped by deployment domain. A shared or workload deployment can reference an existing management or network resource group; that reference does not move the deployment into another domain group.

## Platform Hub

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| platform-hub-network-publicroute.bicep | platform-hub-network-publicroute-plat.bicepparam | hub-network-plat-wus2-001-rg | VNet | hub-network-plat-wus2-001-vnet |
| platform-hub-network-publicroute.bicep | platform-hub-network-publicroute-plat.bicepparam | hub-network-plat-wus2-001-rg | Subnet | hub-network-hub-management-001-snet |
| platform-hub-management.bicep | platform-hub-management-plat.bicepparam | hub-management-plat-wus2-001-rg | Sentinel Workspace | hub-management-plat-wus2-001-sent |
| platform-hub-management.bicep | platform-hub-management-plat.bicepparam | hub-management-plat-wus2-001-rg | Application Insights | hub-management-plat-wus2-001-appi |
| platform-hub-management.bicep | platform-hub-management-plat.bicepparam | hub-management-plat-wus2-001-rg | Key Vault | hub-management-plat-001-kv |

## Platform Spoke

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| platform-spoke-network-publicroute.bicep | platform-spoke-network-publicroute-dev.bicepparam | spoke-network-dev-wus2-001-rg | VNet | spoke-network-dev-wus2-001-vnet |
| platform-spoke-network-publicroute.bicep | platform-spoke-network-publicroute-dev.bicepparam | spoke-network-dev-wus2-001-rg | Subnet | spoke-network-hub-management-001-snet |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | Application Insights | spoke-management-dev-wus2-001-appi |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | App Configuration | spoke-management-dev-wus2-001-appcs |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | Key Vault | spoke-management-dev-001-kv |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | App Service Plan | spoke-management-dev-wus2-f1-001-plan |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | hub-management-plat-wus2-001-rg | Sentinel Workspace | hub-management-plat-wus2-001-sent |

## Platform Spoke Analytics

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| platform-spoke-analytics-fabric.bicep | platform-spoke-analytics-fabric-westus-300.bicepparam | spoke-analytics-prod-westus-300-rg | Fabric Capacity | spokeanalyticsprodwestus300 |

## Platform Shared AI

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| platform-shared-ai-foundry.bicep | platform-shared-ai-foundry-dev.bicepparam | spoke-ai-dev-wus-100-rg | Azure AI Foundry | spoke-ai-dev-wus-100-aif |
| platform-shared-ai-foundry.bicep | platform-shared-ai-foundry-dev.bicepparam | spoke-ai-dev-wus-100-rg | Azure AI Foundry Project | spoke-ai-dev-wus-100-proj |
| platform-shared-ai-ollama.bicep | platform-shared-ai-ollama-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Container App Environment | spoke-ai-dev-wus2-001-acaenv |
| platform-shared-ai-ollama.bicep | platform-shared-ai-ollama-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Container App | spoke-ai-dev-wus2-001-ollama |
| platform-shared-ai-ollama.bicep | platform-shared-ai-ollama-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Storage Account | spokeaidevwus2001oll |

## Platform Spoke AI

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| platform-spoke-ai-foundry.bicep | platform-spoke-ai-foundry-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Azure AI Foundry | spoke-ai-dev-wus2-001-aif |
| platform-spoke-ai-foundry.bicep | platform-spoke-ai-foundry-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Azure AI Foundry Project | spoke-ai-dev-wus2-001-proj |
| platform-spoke-ai-foundry.bicep | platform-spoke-ai-foundry-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Private Endpoint | spoke-ai-dev-wus2-001-aif-pe |

## Workload Shared

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| workload-shared-func.bicep | workload-shared-func-dev.bicepparam | PRODUCT-dev-wus2-001-rg | Function App | PRODUCT-dev-wus2-001-func |
| workload-shared-web.bicep | workload-shared-web-dev.bicepparam | PRODUCT-dev-wus2-001-shared-rg | Web App | PRODUCT-dev-wus2-001-web |

Both shared workload deployments reuse existing `spoke-management-dev-wus2-001-rg` services where specified by their parameter files.

## Workload Spoke

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| workload-spoke-api.bicep | workload-spoke-api-dev.bicepparam | PRODUCT-dev-wus2-001-rg | API App | PRODUCT-dev-wus2-001-api |
| workload-spoke-api-sql.bicep | workload-spoke-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | API App | PRODUCT-dev-wus2-001-api |
| workload-spoke-api-sql.bicep | workload-spoke-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Server | PRODUCT-dev-wus2-001-sql |
| workload-spoke-api-sql.bicep | workload-spoke-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Database | PRODUCT-dev-wus2-001-sqldb |
| workload-spoke-web.bicep | workload-spoke-web-dev.bicepparam | PRODUCT-dev-wus2-001-rg | Web App | PRODUCT-dev-wus2-001-web |
| workload-spoke-web-api.bicep | workload-spoke-web-api-dev.bicepparam | PRODUCT-dev-wus2-001-rg | Web App | PRODUCT-dev-wus2-001-web |
| workload-spoke-web-api.bicep | workload-spoke-web-api-dev.bicepparam | PRODUCT-dev-wus2-001-rg | API App | PRODUCT-dev-wus2-001-api |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | Web App | PRODUCT-dev-wus2-001-web |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | API App | PRODUCT-dev-wus2-001-api |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Server | PRODUCT-dev-wus2-001-sql |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Database | PRODUCT-dev-wus2-001-sqldb |
| workload-spoke-web-sql.bicep | workload-spoke-web-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | Web App | PRODUCT-dev-wus2-001-web |
| workload-spoke-web-sql.bicep | workload-spoke-web-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Server | PRODUCT-dev-wus2-001-sql |
| workload-spoke-web-sql.bicep | workload-spoke-web-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Database | PRODUCT-dev-wus2-001-sqldb |
| workload-spoke-func.bicep | workload-spoke-func-dev.bicepparam | PRODUCT-dev-wus2-001-rg | Function App | PRODUCT-dev-wus2-001-func |

Workload spoke deployments reuse `spoke-management-dev-wus2-001-rg` and `spoke-network-dev-wus2-001-rg` for shared management and network resources where specified by their parameter files.

## Workload Standalone

| Bicep Template | Parameter File | Resource Group | Resource Type | Resource Name |
|----------|----------|----------|----------|----------|
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | Web App | PRODUCT-dev-wus2-001-web |
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | API App | PRODUCT-dev-wus2-001-api |
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Server | PRODUCT-dev-wus2-001-sql |
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | PRODUCT-dev-wus2-001-rg | SQL Database | PRODUCT-dev-wus2-001-sqldb |