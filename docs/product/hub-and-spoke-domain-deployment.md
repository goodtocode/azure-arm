# Azure Platform Hub and Spoke Domain Deployment Matrix

## Core Conventions

| Slot | Purpose | Example | RG | Resources |
|----------|----------|----------|----------|----------|
| 1 | Scope Owner | platform, prod, devtest, shared, nursing, certification | Platform RG Slots Convention | Platform Resources Slots Convention |
| 2 | Workload Scope | hub, spoke, education | `{scopeOwner}-{scopeType}-{service}-{region}-{instance}-rg` | `{scopeType}-{service}-{region}-{instance}-{resourceAbbreviation}` |
| 3 | Service Domain / Product | connectivity, identity, management, security, beacon |  |  |
| 4 | Region or Environment | Platform: westus2, eastus2; Business: prod, dev |  |  |
| 5 | Instance | 100 |  |  |

| Domain Resource Group | Usage |
|----------|----------|
| connectivity | ExpressRoute, VPN, DNS, Routing |
| network | VNet, Subnets, NSG, Peerings |
| security | Firewall, Sentinel, DDoS |
| identity | Entra, PIM, Domain Services |
| management | Monitoring, Backup, Automation |

### Platform Slots

**Platform RG Slots Convention**

`{scopeOwner}-{scopeType}-{service}-{region}-{instance}-rg`

**Platform Resources Slots Convention**

`{scopeType}-{service}-{region}-{instance}-{resourceAbbreviation}`

| Platform RG Examples | Platform Resource Examples |
|----------|----------|
| `platform-hub-connectivity-westus2-100-rg` | `hub-network-westus2-100-vnet` |
| `platform-hub-identity-westus2-100-rg` | `hub-identity-westus2-100-rg` |
| `devtest-spoke-network-westus2-100-rg` | `hub-vpngateway-westus2-100-pip` |
| `production-spoke-network-westus2-100-rg` |  |

### Business Product Slots

**Business Product RG Slots Convention**

`{scopeOwner}-{businessUnit/familyLine}-{product}-{env}-{instance}-rg`

**Business Product Resources Slots Convention**

`{businessUnit/familyLine}-{product}-{env}-{instance}-{resourceAbbreviation}`

| Business Product RG Examples | Business Product Resource Examples |
|----------|----------|
| `devtest-nursing-beacon-dev-100-rg` | `nursing-beacon-prod-100-appi` |
| `production-nursing-beacon-prod-100-rg` | `nursing-beacon-prod-100-web` |
|  | `nursing-beacon-prod-100-func` |
|  | `nursingbeaconprod001st` |

Platform hub and spoke resource groups and resources use `region` in slot 4. Business product resource groups and resources use `env` in slot 4; they do not include a platform region slot.

The rows remain grouped by deployment domain. A shared or workload deployment can reference an existing management or network resource group; that reference does not move the deployment into another domain group.

## Platform Hub

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| platform-hub-network-publicroute.bicep | platform-hub-network-publicroute-plat.bicepparam | hub-network-plat-wus2-001-rg | VNet | hub-network-plat-wus2-001-vnet |
| platform-hub-network-publicroute.bicep | platform-hub-network-publicroute-plat.bicepparam | hub-network-plat-wus2-001-rg | Subnet | hub-network-hub-management-001-snet |
| platform-hub-management.bicep | platform-hub-management-plat.bicepparam | hub-management-plat-wus2-001-rg | Sentinel Workspace | hub-management-plat-wus2-001-sent |
| platform-hub-management.bicep | platform-hub-management-plat.bicepparam | hub-management-plat-wus2-001-rg | Application Insights | hub-management-plat-wus2-001-appi |
| platform-hub-management.bicep | platform-hub-management-plat.bicepparam | hub-management-plat-wus2-001-rg | Key Vault | hub-management-plat-001-kv |

## Platform Spoke

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| platform-spoke-network-publicroute.bicep | platform-spoke-network-publicroute-dev.bicepparam | spoke-network-dev-wus2-001-rg | VNet | spoke-network-dev-wus2-001-vnet |
| platform-spoke-network-publicroute.bicep | platform-spoke-network-publicroute-dev.bicepparam | spoke-network-dev-wus2-001-rg | Subnet | spoke-network-hub-management-001-snet |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | Application Insights | spoke-management-dev-wus2-001-appi |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | App Configuration | spoke-management-dev-wus2-001-appcs |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | Key Vault | spoke-management-dev-001-kv |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | spoke-management-dev-wus2-001-rg | App Service Plan | spoke-management-dev-wus2-f1-001-plan |
| platform-spoke-management.bicep | platform-spoke-management-dev.bicepparam | hub-management-plat-wus2-001-rg | Sentinel Workspace | hub-management-plat-wus2-001-sent |

## Platform Spoke Analytics

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| platform-spoke-analytics-fabric.bicep | platform-spoke-analytics-fabric-westus-300.bicepparam | spoke-analytics-prod-westus-300-rg | Fabric Capacity | spokeanalyticsprodwestus300 |

## Platform Shared AI

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| platform-shared-ai-foundry.bicep | platform-shared-ai-foundry-dev.bicepparam | spoke-ai-dev-wus-100-rg | Azure AI Foundry | spoke-ai-dev-wus-100-aif |
| platform-shared-ai-foundry.bicep | platform-shared-ai-foundry-dev.bicepparam | spoke-ai-dev-wus-100-rg | Azure AI Foundry Project | spoke-ai-dev-wus-100-proj |
| platform-shared-ai-ollama.bicep | platform-shared-ai-ollama-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Container App Environment | spoke-ai-dev-wus2-001-acaenv |
| platform-shared-ai-ollama.bicep | platform-shared-ai-ollama-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Container App | spoke-ai-dev-wus2-001-ollama |
| platform-shared-ai-ollama.bicep | platform-shared-ai-ollama-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Storage Account | spokeaidevwus2001oll |

## Platform Spoke AI

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| platform-spoke-ai-foundry.bicep | platform-spoke-ai-foundry-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Azure AI Foundry | spoke-ai-dev-wus2-001-aif |
| platform-spoke-ai-foundry.bicep | platform-spoke-ai-foundry-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Azure AI Foundry Project | spoke-ai-dev-wus2-001-proj |
| platform-spoke-ai-foundry.bicep | platform-spoke-ai-foundry-dev.bicepparam | spoke-ai-dev-wus2-001-rg | Private Endpoint | spoke-ai-dev-wus2-001-aif-pe |

## Workload Shared

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| workload-shared-func.bicep | workload-shared-func-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Function App | nursing-beacon-dev-001-func |
| workload-shared-web.bicep | workload-shared-web-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Web App | nursing-beacon-dev-001-web |

Both shared workload deployments reuse existing `spoke-management-dev-wus2-001-rg` services where specified by their parameter files.

## Workload Spoke

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| workload-spoke-api.bicep | workload-spoke-api-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | API App | nursing-beacon-dev-001-api |
| workload-spoke-api-sql.bicep | workload-spoke-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | API App | nursing-beacon-dev-001-api |
| workload-spoke-api-sql.bicep | workload-spoke-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Server | nursing-beacon-dev-001-sql |
| workload-spoke-api-sql.bicep | workload-spoke-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Database | nursing-beacon-dev-001-sqldb |
| workload-spoke-web.bicep | workload-spoke-web-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Web App | nursing-beacon-dev-001-web |
| workload-spoke-web-api.bicep | workload-spoke-web-api-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Web App | nursing-beacon-dev-001-web |
| workload-spoke-web-api.bicep | workload-spoke-web-api-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | API App | nursing-beacon-dev-001-api |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Web App | nursing-beacon-dev-001-web |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | API App | nursing-beacon-dev-001-api |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Server | nursing-beacon-dev-001-sql |
| workload-spoke-web-api-sql.bicep | workload-spoke-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Database | nursing-beacon-dev-001-sqldb |
| workload-spoke-web-sql.bicep | workload-spoke-web-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Web App | nursing-beacon-dev-001-web |
| workload-spoke-web-sql.bicep | workload-spoke-web-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Server | nursing-beacon-dev-001-sql |
| workload-spoke-web-sql.bicep | workload-spoke-web-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Database | nursing-beacon-dev-001-sqldb |
| workload-spoke-func.bicep | workload-spoke-func-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Function App | nursing-beacon-dev-001-func |

Workload spoke deployments reuse `spoke-management-dev-wus2-001-rg` and `spoke-network-dev-wus2-001-rg` for shared management and network resources where specified by their parameter files.

## Workload Standalone

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | Web App | nursing-beacon-dev-001-web |
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | API App | nursing-beacon-dev-001-api |
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Server | nursing-beacon-dev-001-sql |
| workload-standalone-web-api-sql.bicep | workload-standalone-web-api-sql-dev.bicepparam | devtest-nursing-beacon-dev-001-rg | SQL Database | nursing-beacon-dev-001-sqldb |