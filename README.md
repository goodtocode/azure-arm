
# Azure ARM Bicep Atomic Design Repository

This repository implements an **atomic design** approach for Azure infrastructure-as-code using [Bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/overview). It is organized into three main categories:

## Atoms (Modules)
Located in the `bicep/modules/` directory, these are small, reusable Bicep modules representing individual Azure resources (e.g., storage accounts, key vaults, app services). Each module is designed to be composable and independently deployable.

## Organisms (Templates)
Located in the `bicep/templates/` directory, these are higher-level Bicep templates that combine multiple modules (atoms) to define more complex Azure solutions or environments. Organisms orchestrate the deployment of multiple resources as a cohesive unit.

## Variables
Located in the `bicep/variables/` directory, these are `.bicepparam` files that bind a template to one mode and one environment. They only set names, topology references, and feature selections.

---

## Who Uses This Repo

| Repo type | Owner | What it deploys | Templates |
| --- | --- | --- | --- |
| Platform | Cloud / platform engineers | Hub, spokes, and once per spoke shared resources: management RG (App Insights, Log Analytics, App Service plans, Key Vault), network, and the shared AI RG (Foundry and projects) | `platform-*` |
| Workload | Product teams | One home RG per product: web app, API, SQL server and database, optional Azure Function | `workload-*` |

## Modes

Every workload is deployed in one of four modes. The mode decides where shared resources come from and how traffic reaches the apps. It does not decide which components are deployed.

| # | Mode | Home RG contains | Reuses from another RG (same subscription) | Networking | Template |
| --- | --- | --- | --- | --- | --- |
| 1 | `standalone` | Everything: plan, Log Analytics, App Insights, apps, SQL, Function | Nothing (Microsoft Entra ID only) | Public Azure defaults | `workload-<archetype>` |
| 2 | `shared` | Apps, SQL, Function and its storage | App Service plan, App Insights (spoke mgmt RG) | Public Azure defaults | `workload-<archetype>` |
| 3 | `network` | Same as `shared` | Same as `shared`, plus an existing VNet subnet | Regional VNet integration, storage limited to the subnet | `workload-<archetype>` |
| 4 | `zerotrust` | Same as `network`, plus a private endpoint per app, SQL server and storage sub-resource | Same as `network`, plus a private endpoint subnet and Private DNS zones | Private endpoints, public access disabled, all outbound traffic through the VNet | `workload-<archetype>-zerotrust` |

Modes 1 to 3 share one template because they differ only in where the plan and App Insights come from and whether a subnet is supplied. Mode 4 needs private endpoints, DNS, and public access switched off on every resource, so it gets its own template instead of adding conditions to the others. Both templates import the same component types from `bicep/types/digitalproduct-types.bicep`, so a product moves from mode 3 to mode 4 by changing the variables file, not the component settings. Mode 4 does not yet cover Application Insights over Private Link, Entra-only SQL authentication, or inbound routing through Front Door or Application Gateway, and it must be deployed from a runner inside the VNet.

The platform side supports modes 2 to 4 by providing the spoke management RG, the spoke network RG, and the shared AI RG. Mode 2 does not need a hub or VNet, only the spoke management resources.

### Archetypes

An archetype says what kind of workload the home RG holds. Each archetype has its own template pair, component types, and the modes it supports.

| Archetype | Holds | Modes | Templates |
| --- | --- | --- | --- |
| `digitalproduct` | A digital product: web, API, SQL, Function in any combination | standalone, shared, network, zerotrust | `workload-digitalproduct`, `workload-digitalproduct-zerotrust` |
| `usermachines` | Machines for people: developer boxes, desktops, VDI-style VMs. Not a digital product | standalone, network, zerotrust | `workload-usermachines`, `workload-usermachines-zerotrust` |

For `usermachines` the modes mean:

| Mode | Meaning |
| --- | --- |
| `standalone` | Own VNet, subnet and NSG in the home RG. A public IP per machine is optional. |
| `network` | Machines join an existing spoke subnet. Never a public IP. |
| `zerotrust` | `network` plus Trusted Launch, encryption at host, Microsoft Entra ID login. Reach machines through Bastion. |

`shared` is not offered for `usermachines` because a VM always needs a subnet, so there is nothing to share without a network. The validator enforces the modes each archetype supports.

## Slot system

Template and variables names are built from fixed slots. `scripts/validation/Test-IacConventions.ps1` enforces them.

| File | Pattern | Example |
| --- | --- | --- |
| Workload template | `workload-{archetype}[-zerotrust].bicep` | `workload-digitalproduct.bicep` |
| Workload variables | `workload-{archetype}-{mode}-{env}.bicepparam` | `workload-digitalproduct-shared-dev.bicepparam` |
| Platform template | `platform-(hub\|spoke\|shared)-{capability}[-{variant}].bicep` | `platform-shared-mgmt.bicep`, `platform-shared-edge-frontdoor.bicep` |
| Platform variables | `platform-{template name}-{env}.bicepparam` | `platform-shared-mgmt-dev.bicepparam` |

| Slot | Allowed values |
| --- | --- |
| `archetype` | `digitalproduct` (web, API, SQL, Function) or `usermachines` (user VMs, VDI-style desktops) |
| `mode` | `standalone`, `shared`, `network`, `zerotrust` |
| `env` | `dev`, `test`, `stage`, `prod`; `plat` for platform files that are not tied to an environment |
| `scope` (platform only) | `hub`, `spoke`, or `shared`. See below. |
| `capability` | What the template provides: `network`, `mgmt`, `edge`, `ai`, `analytics` |
| `variant` | Optional route or flavor of the capability: `publicroute`, `zerotrust`, `frontdoor`, `appgateway`, `foundry`, `ollama` |

### Platform vs workload prefix

The first word says who owns the deployment and where it lands.

| Prefix | Owner | Lands in | Naming |
| --- | --- | --- | --- |
| `platform-` | Platform engineers | Platform or spoke subscriptions and resource groups shared by many products | `platform-{scope}-{capability}[-{variant}]` |
| `workload-` | One product team | One home resource group for one product | `workload-{archetype}[-zerotrust]`, with the mode in the variables file |

### Scope slot: `hub`, `spoke` and `shared`

The scope slot of a platform template says how it relates to the hub-and-spoke network.

| Scope | Meaning | Needs a hub or spoke VNet | Typical target |
| --- | --- | --- | --- |
| `hub` | Part of the hub: central connectivity and controls | Creates or extends the hub VNet | Platform (hub) management group or subscription |
| `spoke` | Part of a spoke: onboarded to a spoke VNet and peered to the hub | Yes, a spoke VNet and subnet | Spoke management group or subscription |
| `shared` | Not part of hub and spoke. Complements `standalone`: deployable with no hub, no spoke, and no VNet | No | Any subscription |

Use `shared` for capabilities that do not depend on a VNet, such as Azure Front Door and Azure AI Foundry with public access. A capability that has both forms gets two templates, for example `platform-shared-ai-foundry` and `platform-spoke-ai-foundry`. `hub` and `spoke` mean the template is integrated with hub-and-spoke networking, so a repo that has no hub and spoke yet can still use every `shared` template and every `workload-` template in `standalone` mode. Shared platform resource groups such as management, AI and edge are `shared` (for example `platform-shared-mgmt`); a standalone product has no platform templates.

This `shared` scope is about topology. It is not the workload `shared` mode, which is about where the App Service plan and App Insights come from.

Rules the validator checks:

- The `using` line must point at an existing template.
- A workload variables file's `mode` slot must match `param mode`, `zerotrust` must use the `-zerotrust` template, and the mode must be one the archetype supports.
- A platform variables file must be the template name plus `-{env}`.
- Every template and variables file must compile.

To add a new archetype, add a template named `workload-{archetype}.bicep` (plus `-zerotrust` if needed), a `bicep/types/{archetype}-types.bicep`, register the archetype and its modes in `$workloadArchetypes` and `$archetypeModes` in the validator, and add one variables file per mode.

## Bundles

A bundle is the set of templates, variables and pipelines deployed together for one maturity phase. Each phase adds to the previous one; nothing is redesigned or replatformed. Pick the phase that matches the customer and deploy only its bundle. This repository contains every template; a customer's own repo copies only the templates of its phase (see `github-actions` for the matching pipelines).

### Resource group slot

Resource groups are named `{product}-{env}-{region}-{instance}-rg`, for example `crucible-dev-wus2-001-rg`, `mgmt-dev-wus2-001-rg` and `edge-plat-wus2-001-rg`. There is no tenant prefix. Use `plat` for platform-subscription groups and `dev`, `prod` for environments. Resource names inside follow `{product}-{env}-{region}-{instance}-{type}`.

| Phase | Goal | Subscriptions | Resource groups | Templates deployed | Pipelines |
| --- | --- | --- | --- | --- | --- |
| 1. Cloud native startup | Ship fast with minimal operations | 1 | `shared-dev-...`, `{product}-dev-...` | `workload-digitalproduct` (`standalone` mode: workspace, App Insights, plan, web, API, SQL); optional `platform-shared-edge-frontdoor`, `platform-shared-ai-foundry` | `PRODUCT-standalone-iac.yml` |
| 2. Subscription segmentation | Separate platform, development and production | 3 (platform, development, production) | `edge-plat-...`; `mgmt-dev-...`, `{product}-dev-...`; `mgmt-prod-...`, `{product}-prod-...` | `platform-shared-edge-frontdoor` (platform); `platform-shared-mgmt` per environment (workspace created locally); `workload-digitalproduct` in `shared` mode per product | `platform-shared-edge-iac.yml`, `platform-shared-mgmt-iac.yml`, `PRODUCT-iac.yml` |
| 3. Enterprise network foundation | Network boundaries and shared operations | 3 | Phase 2 plus `network-plat-...`, `mgmt-plat-...`, `network-dev-...`, `network-prod-...` | Phase 2 plus `platform-hub-network-publicroute`, `platform-hub-mgmt`, `platform-spoke-network-publicroute`; `platform-shared-mgmt` points at the hub workspace; workloads move to `network` mode | `platform-hub-iac.yml`, `platform-spoke-iac.yml` |
| 4. Zero trust private services | Private endpoints, public access disabled | 3 | Same as Phase 3 | `platform-hub-network-zerotrust`, plus workloads in `zerotrust` mode (`workload-digitalproduct-zerotrust`) | Phase 3 pipelines with the zero-trust templates |

Within a phase, public ingress is one of two routes and they are not mixed: `platform-shared-edge-frontdoor` (default, needs no VNet) or `platform-hub-edge-appgateway` (Application Gateway WAF, Azure Firewall and optional DDoS IP Protection in the hub VNet, Phase 3 and up).

Phase 2 notes:

- AI resources belong to the product that uses them (for example in `crucible-dev-...`), not a shared AI group, unless several products share models or you need central AI governance.
- Phase 2 and Phase 3 use the same `platform-shared-mgmt` template. Leave `hubMgmtResourceGroupName` empty to create the Log Analytics workspace in the same group (Phase 2). Set it to use the platform workspace (Phase 3).
- `platform-hub-mgmt` (Sentinel-enabled workspace) is only needed from Phase 3.

## Module naming

Modules are named `{abbreviation}-{resource}.bicep`. Abbreviations follow the Cloud Adoption Framework (CAF) resource abbreviations where one exists, for example `law-loganalyticsworkspace`, `appi-applicationinsights` and `kv-keyvault`. `sent-loganalyticsworkspace` is kept for the Sentinel-enabled workspace, which composes `law-loganalyticsworkspace`.

## Bicep folder

```text
bicep/
  modules/     atoms: one resource or tightly scoped capability, named {abbreviation}-{resource}.bicep
  templates/   organisms: compose modules for one platform scenario or workload archetype
  types/       user-defined types imported by templates (workload-types, digitalproduct-types, usermachines-types)
  variables/   .bicepparam files, one per template, mode, and environment
```

How a workload template is configured (`workload-digitalproduct`):

- `mode` selects standalone, shared, or network.
- `hosting` names the App Service plan and App Insights. Standalone mode creates them (with `planSku` and `workspaceName`); the other modes look them up.
- `shared` points to the RG that already holds the plan and App Insights (modes 2 and 3).
- `vnet` points to an existing subnet (mode 3).
- `web`, `api`, `sql`, and `func` are each optional objects. Supply one to deploy that component; omit it to skip.

Example variables file (mode 2, API and SQL only):

```bicep
using '../templates/workload-digitalproduct.bicep'

param mode = 'shared'
param location = 'westus2'
param environmentApp = 'Development'
param tags = { Environment: 'dev', CostCenter: '0000' }
param shared = { resourceGroupName: 'ScopeOrTenant-mgmt-dev-wus2-001-rg' }
param hosting = {
  appiName: 'mgmt-dev-wus2-001-appi'
  planName: 'mgmt-dev-wus2-F1-001-plan'
}
param api = { name: 'PRODUCT-dev-wus2-001-api' }
param sql = {
  serverName: 'PRODUCT-dev-wus2-001-sql'
  databaseName: 'PRODUCT-dev-wus2-001-sqldb'
  adminLogin: 'LocalAdmin'
  adminPassword: readEnvironmentVariable('SQL_ADMIN_PASSWORD')
}
```

Compile checks write no files:

```sh
az bicep build --stdout --file bicep/templates/workload-digitalproduct.bicep
az bicep build-params --stdout --file bicep/variables/workload-digitalproduct-shared-dev.bicepparam
```

## Scripts

PowerShell scripts under `scripts/` automate the work around the templates. Paths inside the hub-and-spoke scripts are relative to the `scripts/hub-and-spoke` folder.

| Folder | Purpose |
| --- | --- |
| `scripts/validation/` | `Test-IacConventions.ps1` checks the slot system and compiles every template and variables file. Run it before every commit and in CI. |
| `scripts/hub-and-spoke/` | `New-PlatformHub.ps1` deploys the hub mgmt and network templates, `New-PlatformSpoke.ps1` deploys the spoke mgmt and network templates, and `New-VnetPeering.ps1` peers a spoke VNet with the hub. Each runs what-if first. |
| `scripts/New-EntraDotnetSolution.ps1` | Orchestrator for a .NET solution: calls `entra/New-EntraAppRegistration.ps1` for the API, Web and optional E2E registrations, then writes each project's dotnet user-secrets. |
| `scripts/entra/` | Microsoft Entra only (no dotnet, no Key Vault): `New-EntraAppRegistration.ps1` creates or reconciles one registration idempotently, `Grant-EntraConsent.ps1` grants admin consent, `Test-EntraAppRegistration.ps1` checks redirect URIs, scopes and consent. |
| `scripts/dotnet/` | Local project configuration: `Set-DotnetUserSecret.ps1` writes user-secrets, `Sync-DotnetUserSecretKeyVault.ps1` copies them to or from Key Vault. |
| `scripts/lib/` | Helpers the scripts above dot-source (`Entra.Common.ps1`, `Dotnet.Common.ps1`). |

---

## Key Features

- **Atomic Design**: Promotes reusability, maintainability, and clarity by separating infrastructure into atoms (modules) and organisms (templates).
- **Validation**: Supports validation of deployments using Azure's deployment group what-if operation, allowing you to preview changes before applying them.
- **Deployment**: Deploys resources using `az deployment group create` for robust, repeatable, and auditable infrastructure provisioning.

---

## Architecture Conventions

This repository uses **Platform** and **Workload** terminology for Azure infrastructure. The term **Landing Zone** is reserved for broader CAF and Enterprise Scale Architecture discussions and is not used as a Bicep deployment prefix.

### Ownership

- **Platform**: Enterprise-managed foundational services and controls shared across products, including networking, connectivity, DNS, firewalls, monitoring, identity integrations, App Configuration, Key Vault, and shared AI services.
- **Workload**: Resources owned by one product, application, bounded context, or business capability, including web apps, API apps, Functions, App Service plans, and product databases.
- **Hub** and **Spoke**: Network topology terms. The hub provides centralized connectivity and controls; spokes are workload or platform deployments connected to the hub.
- **Shared**: A platform deployment that is not part of hub and spoke. It needs no hub or spoke VNet, so it complements `standalone` and works without any hub-and-spoke architecture. Use the `platform-shared-` prefix for these. This is separate from the workload `shared` mode, which only means the App Service plan and App Insights are consumed from another resource group.
- **Standalone**: A fully self-contained deployment boundary where the complete product stack is installed into one home resource group. Microsoft Entra ID is the only expected enterprise dependency.

### Deployment Models

#### Hub and Spoke

Use hub-and-spoke when the deployment must participate in enterprise networking, segmentation, private connectivity, or centralized security controls.

Platform hub responsibilities include:

- Hub VNets and shared connectivity
- DNS and private DNS zones
- Firewalls, application gateways, and route tables
- Network security controls
- Shared monitoring and management services

Spoke deployments are expected to be onboarded to a VNet and subnet. A spoke template may therefore require hub or delegated subnet resource IDs. Spoke resources include product web apps, APIs, Functions, storage, Key Vaults, Service Bus, SQL, and network-enabled AI services.

#### Shared

Use shared when a platform capability must work without hub-and-spoke networking, for example a Front Door profile or an Azure AI Foundry account with public access. Shared templates do not reference a hub or spoke VNet.

Examples include:

- `platform-shared-*`: Azure Front Door, Azure AI Foundry, Azure OpenAI or Ollama services that are deployed without VNet integration.
- `workload-{archetype}`: A product stack in the home resource group. In its `shared` and `network` modes it consumes pre-existing platform services from another resource group. The current archetype is `workload-digitalproduct`.

Some shared capabilities have a corresponding spoke template. For example, the repository contains both the default-install [platform-shared-ai-ollama.bicep](bicep/templates/platform-shared-ai-ollama.bicep) and the network-enabled [platform-spoke-ai-ollama.bicep](bicep/templates/platform-spoke-ai-ollama.bicep).

### Default and Restricted Module Settings

Reusable modules default to portal-style public deployment settings: public network access is enabled, network ACLs allow traffic, and compatible local authentication remains available. `platform-hub-*`, `platform-spoke-*`, and `workload-digitalproduct` in network mode explicitly override those defaults where the resource supports network restriction or identity-based access.

Restricted settings are only complete when the deployment also supplies the required connectivity. Private Key Vault, App Configuration, Storage, Application Insights, Foundry, and Ollama settings require the appropriate VNet/subnet rules, private endpoints, private DNS zones, managed identities, or RBAC assignments. A template must not disable public access without providing a supported private access path.

#### Standalone

Use standalone when all application and operational resources required by the product stack are installed into one home resource group. A standalone deployment may use public Azure defaults, but it must not rely on separately managed App Insights, Key Vault, App Configuration, Foundry, Ollama, Azure OpenAI, hub networking, or spoke networking.

Standalone is a resource-group ownership boundary, not a synonym for private networking. Shared and standalone templates may both use public Azure defaults; the distinction is whether required resources are consumed externally or installed locally.

### Naming

#### Core Conventions

Resource group and resource names use five slots, in order, joined by hyphens: `{product}-{env}-{region}-{instance}-{type}`.

| Slot | Meaning | Example |
| --- | --- | --- |
| `product` | The product or platform service (`mgmt`, `ai`, `network`, `edge`, or a product name) | `mgmt` |
| `env` | `dev`, `test`, `stage`, `prod`, or `plat` for the platform subscription | `dev` |
| `region` | Short region code | `wus2` |
| `instance` | Three-digit instance number, constant within a repository | `100` |
| `type` | Short resource type abbreviation, based on the CAF abbreviation; `rg` for resource groups | `appi` |

There is no tenant, owner or scope prefix. `hub`, `spoke` and `shared` appear only in template and variables file names. Examples: `mgmt-dev-wus2-100-rg`, `network-plat-wus2-100-vnet`, `crucible-prod-wus2-100-web`. See [Azure CAF IaC Conventions](docs/governance/azure-caf-iac-conventions.md#core-conventions) for the exceptions (Key Vault, Front Door, storage).
Template and variables file names follow the slot system described in [Slot system](#slot-system):

```text
workload-{archetype}[-zerotrust].bicep
platform-(hub|spoke|shared)-{capability}[-{variant}].bicep
workload-{archetype}-{mode}-{env}.bicepparam
platform-{template name}-{env}.bicepparam
```

The workload archetype describes what the product is (`digitalproduct`), and the mode describes how it is hosted (`standalone`, `shared`, `network`, `zerotrust`). Components such as web, API, SQL, and Function App are switched on by supplying their object in the variables file, never by creating another template.

## Why This Repo Is Useful (What Is In It For Me?)

This repository helps you stand up production-ready Azure foundations faster, with less copy-paste and fewer one-off templates.

- **Faster time to first deployment**: Start from opinionated templates instead of building every resource definition from scratch.
- **Safer changes in shared environments**: Use `what-if` before deployment to reduce infrastructure drift and surprise breakage.
- **Composable architecture**: Reuse modules across workloads so web, API, and AI stacks stay consistent.
- **Clear evolution path**: Use shared when platform services already exist in another resource group, standalone when the product must install its complete stack locally, and hub-and-spoke when security, segmentation, and scale requirements require network onboarding.

### High-Value Modules You Can Reuse

- **AI Foundry**: `bicep/modules/aif-foundry.bicep` for Azure AI Foundry hub/project/model deployment with integration-friendly outputs.
- **Web and API apps**: `bicep/modules/web-appservice.bicep` and `bicep/modules/api-appservice.bicep` for common App Service hosting patterns.
- **App Service plans**: `bicep/modules/plan-appserviceplan.bicep` to standardize compute sizing and hosting tiers.
- **SQL foundation**: `bicep/modules/sql-sqlserver.bicep` and `bicep/modules/sqldb-sqldatabase.bicep` are the server and database atoms; `bicep/modules/sql-sqlserverdatabase.bicep` is the combined server and database module the workload templates use.
- **Operational baseline**: `bicep/modules/appi-applicationinsights.bicep`, `bicep/modules/work-loganalyticsworkspace.bicep` (`sent-loganalyticsworkspace.bicep` wraps it and adds Sentinel onboarding), and `bicep/modules/kv-keyvault.bicep` for observability and secrets.
- **Virtual machines**: `bicep/modules/vm-virtualmachine.bicep`, `nic-networkinterface.bicep`, and `pip-publicipaddress.bicep` for user machines.

### Template Tracks by Architecture Style

- **Shared platform templates (default installs without VNet/SNet onboarding)**:
	`bicep/templates/platform-shared-ai-foundry.bicep`,
	`bicep/templates/platform-shared-ai-ollama.bicep`
- **Workload templates (one per archetype; mode and components set in the variables file)**:
	`bicep/templates/workload-digitalproduct.bicep` (modes: standalone, shared, network), `bicep/templates/workload-digitalproduct-zerotrust.bicep` (mode: zerotrust),
	`bicep/templates/workload-usermachines.bicep` (modes: standalone, network), and `bicep/templates/workload-usermachines-zerotrust.bicep` (mode: zerotrust)
- **Hub templates (shared platform services)**:
	`bicep/templates/platform-hub-mgmt.bicep`,
	`bicep/templates/platform-hub-network-publicroute.bicep`,
	`bicep/templates/platform-hub-network-zerotrust.bicep` (variables: `platform-hub-network-zerotrust-plat.bicepparam`)
- **Spoke templates (workload isolation and scale-out)**:
	`bicep/templates/platform-shared-mgmt.bicep`,
	`bicep/templates/platform-spoke-network-publicroute.bicep`,
	`bicep/templates/platform-spoke-ai-ollama.bicep`,
	`bicep/templates/platform-spoke-ai-foundry.bicep`

If you are deciding where to begin, use the `standalone` mode when the product must install its complete stack into one home resource group. Use `shared` when the platform already owns the plan and App Insights in another resource group of the same subscription. Use `network` when the apps also need VNet integration, and `zerotrust` when private endpoints are required.

### Spoke Subscription and Environment Model

A spoke is a deployment boundary, not a single global instance. Deploy one or more spokes for the environments or ownership boundaries that require isolation, such as:

- Development and test
- Production
- A subsidiary tenant
- A large product or business capability

Each spoke may have its own subscription, resource group, VNet, subnet, Foundry hub, project, model deployments, private endpoint, RBAC assignments, quotas, and diagnostics. The same template can be deployed repeatedly with different parameter files. A shared platform service can remain centralized when cross-spoke access is acceptable; a spoke Foundry hub should be created per spoke when data residency, quota isolation, tenant isolation, or network boundaries require it.

---

## Usage

### 1. Validate a Deployment (What-If)

Preview the impact of a deployment without making changes:

```sh
az deployment group what-if \
	--resource-group <your-resource-group> \
	--template-file <path-to-template.bicep> \
	--parameters <parameters-file>
```

### 2. Deploy to a Resource Group

Deploy a Bicep template (organism) to your Azure resource group:

```sh
az deployment group create \
	--resource-group <your-resource-group> \
	--template-file <path-to-template.bicep> \
	--parameters <parameters-file>
```

### 3. Supply Secrets and Per-Run Overrides

Never store passwords in a variables file. The workload variables files read secrets from environment variables at build time, with the placeholder `PASS_FROM_CLI_PARAMETERS` as the fallback so the file still compiles:

| Variable | Used by | Parameter |
| --- | --- | --- |
| `SQL_ADMIN_PASSWORD` | `workload-digitalproduct-*` | `sql.adminPassword` |
| `VM_ADMIN_PASSWORD` | `workload-usermachines-*` | `adminPassword` |

Set the variable for the session, then deploy as usual. Do not echo it, and do not commit it.

```powershell
# PowerShell: prompt for the secret so it never appears in history or files
$env:SQL_ADMIN_PASSWORD = Read-Host -Prompt 'SQL admin password' -MaskInput

az deployment group create `
	--resource-group <your-resource-group> `
	--template-file bicep/templates/workload-digitalproduct.bicep `
	--parameters bicep/variables/workload-digitalproduct-shared-dev.bicepparam
```

```sh
# bash: read without echo
read -rsp 'SQL admin password: ' SQL_ADMIN_PASSWORD; export SQL_ADMIN_PASSWORD

az deployment group create \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/workload-digitalproduct.bicep \
	--parameters bicep/variables/workload-digitalproduct-shared-dev.bicepparam
```

In CI, map the variable from the pipeline secret store (for example `SQL_ADMIN_PASSWORD: ${{ secrets.SQL_ADMIN_PASSWORD }}` in GitHub Actions). Prefer a Key Vault-backed secret where the pipeline supports it.

To override a top-level parameter for one run, add inline `name=value` pairs after the `.bicepparam` file. Inline values win over the file, and the file must be a `.bicepparam` (do not mix it with a JSON parameters file). This needs a recent Azure CLI and Bicep CLI.

```powershell
az deployment group create `
	--resource-group <your-resource-group> `
	--template-file bicep/templates/workload-usermachines.bicep `
	--parameters bicep/variables/workload-usermachines-standalone-dev.bicepparam `
	--parameters adminUsername=<user> adminPassword=$env:VM_ADMIN_PASSWORD
```

Inline overrides replace a whole top-level parameter. Object parameters such as `sql` cannot have one property overridden (`sql.adminPassword=...` is not supported), so use the environment variable for secrets nested inside `sql`. Passing secrets as inline arguments can expose them in process listings and shell history; prefer the environment variable or a prompt.

---

## Repository Structure

- `bicep/modules/` — Atomic Bicep modules (atoms)
- `bicep/templates/` — Composite Bicep templates (organisms)
- `bicep/types/` — Shared user-defined types (modes, shared and VNet references)
- `bicep/variables/` — Environment-specific `.bicepparam` files for templates
- `scripts/` — PowerShell automation (see [Scripts](#scripts))
- `docs/` — Governance conventions and product deployment examples

---

## Azure AI Foundry (Shared)

This repository includes a shared Azure AI Foundry deployment path that avoids private networking and enterprise hub-and-spoke dependencies.

### New Assets

- Module: `bicep/modules/aif-foundry.bicep`
- Template: `bicep/templates/platform-shared-ai-foundry.bicep`
- Variables: `bicep/variables/platform-shared-ai-foundry-dev.bicepparam`

### Scope

- Deploys Azure AI Foundry hub (`Microsoft.CognitiveServices/accounts`, kind `AIServices`).
- Deploys Azure AI Foundry project resource.
- Deploys a configurable model deployment.
- Outputs endpoint and deployment identifiers for provider integration.

### Validate

```sh
az deployment group what-if \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-shared-ai-foundry.bicep \
	--parameters bicep/variables/platform-shared-ai-foundry-dev.bicepparam
```

### Deploy

```sh
az deployment group create \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-shared-ai-foundry.bicep \
	--parameters bicep/variables/platform-shared-ai-foundry-dev.bicepparam
```

### Provider Configuration Example

Use deployment outputs with your provider abstraction:

```json
{
	"AgentProvider": {
		"Provider": "Foundry",
		"Endpoint": "<foundry-endpoint>",
		"Deployment": "default"
	}
}
```

### Local vs Cloud Provider Selection

- Local/self-hosted option: Ollama
- Managed cloud option: Azure AI Foundry
- Existing managed option: Azure OpenAI

Switching providers should remain configuration-driven through your `AgentProviderOptions` pattern.

---

## Azure AI Foundry (Spoke)

The spoke Foundry deployment creates an independent Foundry hub and project with public access disabled, network ACLs set to deny by default, local authentication disabled, and a private endpoint connected to a subnet in the target spoke.

### New Assets

- Template: `bicep/templates/platform-spoke-ai-foundry.bicep`
- Variables: `bicep/variables/platform-spoke-ai-foundry-dev.bicepparam`

### Required Network Inputs

- A private-endpoint subnet in the target spoke VNet
- A Private DNS zone for `privatelink.cognitiveservices.azure.com`
- DNS zone linking from the clients' VNets to the private DNS zone
- RBAC assignments for the calling managed identities or security principals

The private endpoint and Foundry hub may be deployed in different resource groups and, where supported by the Azure resource relationship, different subscriptions. The deployment identity must have permission to create the Foundry resources and the private endpoint. The DNS zone resource ID must point to the zone used by the spoke's DNS architecture.

### Validate

```sh
az deployment group what-if \
	--resource-group <spoke-resource-group> \
	--template-file bicep/templates/platform-spoke-ai-foundry.bicep \
	--parameters bicep/variables/platform-spoke-ai-foundry-dev.bicepparam
```

### Deploy

```sh
az deployment group create \
	--resource-group <spoke-resource-group> \
	--template-file bicep/templates/platform-spoke-ai-foundry.bicep \
	--parameters bicep/variables/platform-spoke-ai-foundry-dev.bicepparam
```

Deploy the same template independently for development/test, production, subsidiary, or large-product spokes by supplying a parameter file with that spoke's subscription, resource group, subnet, DNS zone, model capacity, and naming values.

---

## Azure Ollama (Shared)

This repository includes a shared Ollama deployment path using Azure Container Apps with persistent model storage and no VNet/SNet onboarding.

### New Assets

- Module: `bicep/modules/aca-ollama.bicep`
- Template: `bicep/templates/platform-shared-ai-ollama.bicep`
- Variables: `bicep/variables/platform-shared-ai-ollama-dev.bicepparam`

### Scope

- Deploys Azure Container Apps managed environment.
- Deploys Azure Container App running `ollama/ollama`.
- Configures optional public ingress; networking is not attached to a hub or spoke.
- Pulls configured model at startup.
- Persists downloaded models to Azure Files mounted into the container.

### Validate

```sh
az deployment group what-if \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-shared-ai-ollama.bicep \
	--parameters bicep/variables/platform-shared-ai-ollama-dev.bicepparam
```

### Deploy

```sh
az deployment group create \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-shared-ai-ollama.bicep \
	--parameters bicep/variables/platform-shared-ai-ollama-dev.bicepparam
```

### Provider Configuration Mapping

Azure-hosted Ollama:

```json
{
	"AgentProvider": {
		"Provider": "Ollama",
		"Endpoint": "http://<ollama-internal-fqdn>",
		"Model": "phi4"
	}
}
```

Local development:

```json
{
	"AgentProvider": {
		"Provider": "Ollama",
		"Endpoint": "http://localhost:11434",
		"Model": "phi4"
	}
}
```

Both use the same provider shape and differ only by environment-specific configuration values.

---

## Contributing

Contributions are welcome! Please ensure new modules and templates follow the atomic design principles and include documentation and sample parameters.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
