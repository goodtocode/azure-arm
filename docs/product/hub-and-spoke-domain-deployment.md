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
| platform-hub-network-zerotrust.bicep | platform-hub-network-zerotrust-plat.bicepparam | hub-network-plat-wus2-001-rg | VNet | hub-network-plat-wus2-001-vnet |
| platform-hub-network-zerotrust.bicep | platform-hub-network-zerotrust-plat.bicepparam | hub-network-plat-wus2-001-rg | Front Door Premium, API Management | (see template) |
| platform-hub-mgmt.bicep | platform-hub-mgmt-plat.bicepparam | hub-management-plat-wus2-001-rg | Sentinel Workspace | hub-management-plat-wus2-001-sent |
| platform-hub-mgmt.bicep | platform-hub-mgmt-plat.bicepparam | hub-management-plat-wus2-001-rg | Application Insights | hub-management-plat-wus2-001-appi |
| platform-hub-mgmt.bicep | platform-hub-mgmt-plat.bicepparam | hub-management-plat-wus2-001-rg | Key Vault | hub-management-plat-001-kv |

The zero-trust hub network template is a work in progress: its private DNS zones and API Management private endpoint are still open items in the template.

## Platform Spoke

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| platform-spoke-network-publicroute.bicep | platform-spoke-network-publicroute-dev.bicepparam | spoke-network-dev-wus2-001-rg | VNet | spoke-network-dev-wus2-001-vnet |
| platform-spoke-network-publicroute.bicep | platform-spoke-network-publicroute-dev.bicepparam | spoke-network-dev-wus2-001-rg | Subnet | spoke-network-hub-management-001-snet |
| platform-spoke-network-publicroute.bicep | platform-spoke-network-publicroute-dev.bicepparam | spoke-network-dev-wus2-001-rg | Apps subnet (optional: `snetNameApps`/`snetCidrApps`; delegated to Microsoft.Web/serverFarms, Microsoft.Storage service endpoint) | spoke-network-apps-001-snet |
| platform-spoke-mgmt.bicep | platform-spoke-mgmt-dev.bicepparam | spoke-management-dev-wus2-001-rg | Application Insights | spoke-management-dev-wus2-001-appi |
| platform-spoke-mgmt.bicep | platform-spoke-mgmt-dev.bicepparam | spoke-management-dev-wus2-001-rg | App Configuration | spoke-management-dev-wus2-001-appcs |
| platform-spoke-mgmt.bicep | platform-spoke-mgmt-dev.bicepparam | spoke-management-dev-wus2-001-rg | Key Vault | spoke-management-dev-001-kv |
| platform-spoke-mgmt.bicep | platform-spoke-mgmt-dev.bicepparam | spoke-management-dev-wus2-001-rg | App Service Plan | spoke-management-dev-wus2-f1-001-plan |
| platform-spoke-mgmt.bicep | platform-spoke-mgmt-dev.bicepparam | hub-management-plat-wus2-001-rg | Sentinel Workspace | hub-management-plat-wus2-001-sent |

## Platform Spoke Analytics

| Bicep Template | Parameter File | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|
| platform-spoke-analytics-fabric.bicep | platform-spoke-analytics-fabric-prod.bicepparam | spoke-analytics-prod-westus-300-rg | Fabric Capacity | spokeanalyticsprodwestus300 |

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

## Workload Digital Product

One template serves modes 1-3. The mode and the component objects (web, api, sql, func) are set in the parameter file, so a product that has no web app, no SQL, or an extra Function App uses the same template.

| Bicep Template | Parameter File | Mode | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|----------|
| workload-digitalproduct.bicep | workload-digitalproduct-standalone-dev.bicepparam | standalone | devtest-nursing-beacon-dev-001-rg | Log Analytics, App Insights, App Service Plan | nursing-beacon-dev-001-work / -appi / -plan |
| workload-digitalproduct.bicep | workload-digitalproduct-shared-dev.bicepparam | shared | devtest-nursing-beacon-dev-001-rg | Web App, API App | nursing-beacon-dev-001-web / -api |
| workload-digitalproduct.bicep | workload-digitalproduct-network-dev.bicepparam | network | devtest-nursing-beacon-dev-001-rg | SQL Server, SQL Database | nursing-beacon-dev-001-sql / -sqldb |
| workload-digitalproduct.bicep | any of the above | any | devtest-nursing-beacon-dev-001-rg | Function App and Storage | nursing-beacon-dev-001-func |
| workload-digitalproduct-zerotrust.bicep | workload-digitalproduct-zerotrust-dev.bicepparam | zerotrust | devtest-nursing-beacon-dev-001-rg | Private endpoints | nursing-beacon-dev-001-web-pe / -api-pe / -sql-pe |

Shared and network modes reuse the plan and App Insights in `spoke-management-dev-wus2-001-rg`. Network mode also integrates the apps with a subnet in `spoke-network-dev-wus2-001-rg`.

## Workload User Machines

Machines for people (developer boxes, desktops, VDI-style VMs). This archetype is not a digital product and does not use the plan, App Insights, or SQL. `shared` is not a mode here because a VM always needs a subnet.

| Bicep Template | Parameter File | Mode | Resource Group Example | Resource Type | Resource Name Example |
|----------|----------|----------|----------|----------|----------|
| workload-usermachines.bicep | workload-usermachines-standalone-dev.bicepparam | standalone | devtest-devboxes-dev-001-rg | VNet, Subnet, NSG | devboxes-dev-wus2-001-vnet / -machines-snet |
| workload-usermachines.bicep | workload-usermachines-standalone-dev.bicepparam | standalone | devtest-devboxes-dev-001-rg | VM, NIC, optional public IP | devboxes-dev-vm01 / -nic / -pip |
| workload-usermachines.bicep | workload-usermachines-network-dev.bicepparam | network | devtest-devboxes-dev-001-rg | VM, NIC (subnet in the spoke network RG) | devboxes-dev-vm01 / -nic |
| workload-usermachines-zerotrust.bicep | workload-usermachines-zerotrust-dev.bicepparam | zerotrust | devtest-devboxes-dev-001-rg | VM (Trusted Launch, encryption at host, Entra login), NIC | devboxes-dev-vm01 / -nic |

Network and zerotrust modes attach to a subnet in `spoke-network-dev-wus2-001-rg`. Zero trust never attaches a public IP; reach machines through Bastion.

## Public Endpoint Variant

`platform-hub-mgmt` and `platform-spoke-mgmt` take `networkAccess` (`restricted` default, `public`). `public` leaves Application Insights ingestion/query and App Configuration open with local auth enabled, for hub-and-spoke deployments that do not use private endpoints yet. Workloads use `network` mode against the apps subnet so NSGs and route tables can be added later without changing the workload.
