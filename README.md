
# Azure ARM Bicep Atomic Design Repository

This repository implements an **atomic design** approach for Azure infrastructure-as-code using [Bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/overview). It is organized into two main categories:

## Atoms (Modules)
Located in the `bicep/modules/` directory, these are small, reusable Bicep modules representing individual Azure resources (e.g., storage accounts, key vaults, app services). Each module is designed to be composable and independently deployable.

## Organisms (Templates)
Located in the `bicep/templates/` directory, these are higher-level Bicep templates that combine multiple modules (atoms) to define more complex Azure solutions or environments. Organisms orchestrate the deployment of multiple resources as a cohesive unit.

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
- **Shared**: A default deployment model for resources that do not require dedicated VNet/SNet onboarding. Shared does not mean every resource is owned by the platform team; use the `platform-` or `workload-` prefix to identify ownership.
- **Standalone**: A fully self-contained deployment boundary with no hub, spoke, or shared-resource dependency. Microsoft Entra ID is the only expected enterprise dependency.

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

Use shared when the deployment is a default Azure installation without VNet/SNet onboarding. Shared services are not connected to a hub-and-spoke network.

Examples include:

- `platform-shared-*`: Shared App Insights, Key Vault, App Configuration, Azure AI Foundry, Azure OpenAI, or Ollama services owned by the platform.
- `workload-shared-*`: A product stack such as web, API, Function, and SQL resources that is deployed without dedicated networking.

Some shared services may have a corresponding spoke template. For example, the repository contains both the default-install [platform-shared-ai-ollama.bicep](bicep/templates/platform-shared-ai-ollama.bicep) and the network-enabled [platform-spoke-ai-ollama.bicep](bicep/templates/platform-spoke-ai-ollama.bicep).

### Default and Restricted Module Settings

Reusable modules default to portal-style public deployment settings: public network access is enabled, network ACLs allow traffic, and compatible local authentication remains available. `platform-hub-*`, `platform-spoke-*`, and `workload-spoke-*` templates explicitly override those defaults where the resource supports network restriction or identity-based access.

Restricted settings are only complete when the deployment also supplies the required connectivity. Private Key Vault, App Configuration, Storage, Application Insights, Foundry, and Ollama settings require the appropriate VNet/subnet rules, private endpoints, private DNS zones, managed identities, or RBAC assignments. A template must not disable public access without providing a supported private access path.

#### Standalone

Use standalone only when all application resources are contained within one deployment boundary and the deployment does not consume or provision shared platform resources. A standalone deployment must not depend on shared App Insights, Key Vault, App Configuration, Foundry, Ollama, Azure OpenAI, hub networking, or spoke networking.

Standalone is an isolation boundary, not a synonym for a default install. Default installs of shared services use `platform-shared-*` or `workload-shared-*`.

### Naming

Template and parameter names follow this format:

```text
{owner}-{deployment-model}-{resource-or-scenario}
```

Valid prefixes are:

```text
platform-hub-*
platform-spoke-*
platform-shared-*
platform-standalone-*

workload-spoke-*
workload-shared-*
workload-standalone-*
```

Resource groups follow this format:

```text
rg-{deployment-model}-{workload}-{environment}-{sequence}
```

Examples:

```text
rg-platform-hub-networking-prod-001
rg-platform-shared-ai-prod-001
rg-workload-spoke-beacon-prod-001
rg-workload-shared-integration-prod-001
rg-workload-standalone-poc-dev-001
```

The resource suffix should describe the actual deployment, not the architecture term. For example, use `workload-spoke-web-api` for a network-bound product stack and `workload-shared-web-api-sql` for the same type of stack without VNet/SNet onboarding.

## Why This Repo Is Useful (What Is In It For Me?)

This repository helps you stand up production-ready Azure foundations faster, with less copy-paste and fewer one-off templates.

- **Faster time to first deployment**: Start from opinionated templates instead of building every resource definition from scratch.
- **Safer changes in shared environments**: Use `what-if` before deployment to reduce infrastructure drift and surprise breakage.
- **Composable architecture**: Reuse modules across workloads so web, API, and AI stacks stay consistent.
- **Clear evolution path**: Begin with a shared default install, then move to hub-and-spoke templates as security, segmentation, and scale requirements grow.

### High-Value Modules You Can Reuse

- **AI Foundry**: `bicep/modules/aif-foundry.bicep` for Azure AI Foundry hub/project/model deployment with integration-friendly outputs.
- **Web and API apps**: `bicep/modules/web-appservice.bicep` and `bicep/modules/api-appservice.bicep` for common App Service hosting patterns.
- **App Service plans**: `bicep/modules/plan-appserviceplan.bicep` to standardize compute sizing and hosting tiers.
- **SQL foundation**: `bicep/modules/sql-sqlserver.bicep`, `bicep/modules/sqldb-sqldatabase.bicep`, and `bicep/modules/sql-sqlserverdatabase.bicep` for SQL server and database deployment.
- **Operational baseline**: `bicep/modules/appi-applicationinsights.bicep`, `bicep/modules/work-loganalyticsworkspace.bicep`, and `bicep/modules/kv-keyvault.bicep` for observability and secrets.

### Template Tracks by Architecture Style

- **Shared platform templates (default installs without VNet/SNet onboarding)**:
	`bicep/templates/platform-shared-ai-foundry.bicep`,
	`bicep/templates/platform-shared-ai-ollama.bicep`
- **Shared workload templates (product stacks without VNet/SNet onboarding)**:
	`bicep/templates/workload-shared-web.bicep`,
	`bicep/templates/workload-shared-web-api-sql.bicep`
- **Hub templates (shared platform services)**:
	`bicep/templates/platform-hub-mgmt.bicep`,
	`bicep/templates/platform-hub-network-publicroute.bicep`,
	`bicep/templates/platform-hub-network-zerotrust.bicep`
- **Spoke templates (workload isolation and scale-out)**:
	`bicep/templates/platform-spoke-mgmt.bicep`,
	`bicep/templates/platform-spoke-network-publicroute.bicep`,
	`bicep/templates/platform-spoke-ai-ollama.bicep`,
	`bicep/templates/platform-spoke-ai-foundry.bicep`
- **Spoke workload templates (web, API, SQL combos)**:
	`bicep/templates/workload-spoke-web.bicep`,
	`bicep/templates/workload-spoke-api.bicep`,
	`bicep/templates/workload-spoke-web-api.bicep`,
	`bicep/templates/workload-spoke-web-sql.bicep`,
	`bicep/templates/workload-spoke-api-sql.bicep`,
	`bicep/templates/workload-spoke-web-api-sql.bicep`

If you are deciding where to begin, start with the shared model for a default install without VNet/SNet onboarding. Adopt the spoke model when governance, segmentation, private connectivity, or multi-team operations require hub-and-spoke networking. Use standalone only for genuinely self-contained deployments.

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

---

## Repository Structure

- `bicep/modules/` — Atomic Bicep modules (atoms)
- `bicep/templates/` — Composite Bicep templates (organisms)
- `bicep/variables/` — Environment-specific `.bicepparam` files for templates
- `scripts/` — PowerShell and CLI scripts for automation
- `variables/` — Parameter and variable files

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
