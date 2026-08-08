
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

## Why This Repo Is Useful (What Is In It For Me?)

This repository helps you stand up production-ready Azure foundations faster, with less copy-paste and fewer one-off templates.

- **Faster time to first deployment**: Start from opinionated templates instead of building every resource definition from scratch.
- **Safer changes in shared environments**: Use `what-if` before deployment to reduce infrastructure drift and surprise breakage.
- **Composable architecture**: Reuse modules across workloads so web, API, and AI stacks stay consistent.
- **Clear evolution path**: Begin standalone for speed, then move to hub-and-spoke templates as security and scale requirements grow.

### High-Value Modules You Can Reuse

- **AI Foundry**: `bicep/modules/aif-foundry.bicep` for Azure AI Foundry hub/project/model deployment with integration-friendly outputs.
- **Web and API apps**: `bicep/modules/web-appservice.bicep` and `bicep/modules/api-appservice.bicep` for common App Service hosting patterns.
- **App Service plans**: `bicep/modules/plan-appserviceplan.bicep` to standardize compute sizing and hosting tiers.
- **SQL foundation**: `bicep/modules/sql-sqlserver.bicep`, `bicep/modules/sqldb-sqldatabase.bicep`, and `bicep/modules/sql-sqlserverdatabase.bicep` for SQL server and database deployment.
- **Operational baseline**: `bicep/modules/appi-applicationinsights.bicep`, `bicep/modules/work-loganalyticsworkspace.bicep`, and `bicep/modules/kv-keyvault.bicep` for observability and secrets.

### Template Tracks by Architecture Style

- **Standalone templates (speed and simplicity)**:
	`bicep/templates/platform-standalone-ai-foundry.bicep`,
	`bicep/templates/platform-standalone-ai-ollama.bicep`,
	`bicep/templates/landingzone-standalone-web-api-sql.bicep`
- **Hub templates (shared platform services)**:
	`bicep/templates/platform-hub-mgmt.bicep`,
	`bicep/templates/platform-hub-network-publicroute.bicep`,
	`bicep/templates/platform-hub-network-zerotrust.bicep`
- **Spoke templates (workload isolation and scale-out)**:
	`bicep/templates/platform-spoke-mgmt.bicep`,
	`bicep/templates/platform-spoke-network-publicroute.bicep`,
	`bicep/templates/platform-spoke-ai-ollama.bicep`
- **Landing zone workload templates (web, API, SQL combos)**:
	`bicep/templates/landingzone-web.bicep`,
	`bicep/templates/landingzone-api.bicep`,
	`bicep/templates/landingzone-web-api.bicep`,
	`bicep/templates/landingzone-web-sql.bicep`,
	`bicep/templates/landingzone-api-sql.bicep`,
	`bicep/templates/landingzone-web-api-sql.bicep`

If you are deciding where to begin, start with a standalone template to validate app behavior quickly, then adopt hub-and-spoke templates when governance, segmentation, and multi-team operations become priorities.

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

## Azure AI Foundry (Standalone)

This repository includes a standalone Azure AI Foundry deployment path that avoids private networking and enterprise landing-zone dependencies.

### New Assets

- Module: `bicep/modules/aif-foundry.bicep`
- Template: `bicep/templates/platform-standalone-ai-foundry.bicep`
- Variables: `bicep/variables/platform-standalone-ai-foundry-dev.bicepparam`

### Scope

- Deploys Azure AI Foundry hub (`Microsoft.CognitiveServices/accounts`, kind `AIServices`).
- Deploys Azure AI Foundry project resource.
- Deploys a configurable model deployment.
- Outputs endpoint and deployment identifiers for provider integration.

### Validate

```sh
az deployment group what-if \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-standalone-ai-foundry.bicep \
	--parameters bicep/variables/platform-standalone-ai-foundry-dev.bicepparam
```

### Deploy

```sh
az deployment group create \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-standalone-ai-foundry.bicep \
	--parameters bicep/variables/platform-standalone-ai-foundry-dev.bicepparam
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

## Azure Ollama (Standalone)

This repository includes a standalone Ollama deployment path using Azure Container Apps with internal ingress and persistent model storage.

### New Assets

- Module: `bicep/modules/aca-ollama.bicep`
- Template: `bicep/templates/platform-standalone-ai-ollama.bicep`
- Variables: `bicep/variables/platform-standalone-ai-ollama-dev.bicepparam`

### Scope

- Deploys Azure Container Apps managed environment.
- Deploys Azure Container App running `ollama/ollama`.
- Configures internal-only ingress (`external: false`).
- Pulls configured model at startup.
- Persists downloaded models to Azure Files mounted into the container.

### Validate

```sh
az deployment group what-if \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-standalone-ai-ollama.bicep \
	--parameters bicep/variables/platform-standalone-ai-ollama-dev.bicepparam
```

### Deploy

```sh
az deployment group create \
	--resource-group <your-resource-group> \
	--template-file bicep/templates/platform-standalone-ai-ollama.bicep \
	--parameters bicep/variables/platform-standalone-ai-ollama-dev.bicepparam
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
