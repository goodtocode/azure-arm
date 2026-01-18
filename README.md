
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
- `scripts/` — PowerShell and CLI scripts for automation
- `variables/` — Parameter and variable files

---

## Contributing

Contributions are welcome! Please ensure new modules and templates follow the atomic design principles and include documentation and sample parameters.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
