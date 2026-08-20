# Azure CAF IaC Conventions

## Purpose

This document defines the repository conventions for Azure Infrastructure as Code (IaC), including ownership, deployment topology, resource-group boundaries, Bicep naming, networking defaults, and deployment composition.

The conventions align with the Azure Cloud Adoption Framework (CAF) and Enterprise Scale Architecture (ESA), while using more precise terms for platform services and digital product workloads.

## Terminology

| Term | Definition |
| --- | --- |
| Platform | Enterprise-managed foundational Azure services and controls shared across products. Examples include networking, DNS, firewalls, monitoring, identity integrations, App Configuration, Key Vault, Azure AI Foundry, Azure OpenAI, and Ollama. |
| Workload | Resources owned by one product, application, bounded context, or business capability. Examples include web apps, API apps, Functions, App Service plans, storage, SQL, and product-specific services. |
| Hub | Centralized network and connectivity boundary owned by the platform. A hub provides shared VNets, routing, DNS, firewalls, gateways, security controls, and management services. |
| Spoke | A VNet-onboarded deployment boundary connected to a hub. Spokes are normally created per environment, product, subsidiary tenant, or other isolation boundary. |
| Shared | A resource-group ownership model. A shared workload installs its product resources in the home resource group while consuming pre-existing shared services from another resource group. A shared platform deployment installs a reusable platform service without dedicated spoke networking. |
| Standalone | A fully self-contained resource-group ownership model. The complete product stack and its required operational resources are installed into one home resource group. Microsoft Entra ID is the only expected enterprise dependency. |
| Home resource group | The resource group that owns the resources installed by the current template. |
| Shared resource group | A separate resource group containing pre-existing platform services consumed by a workload, such as App Insights, Key Vault, App Configuration, or a shared App Service plan. |
| Landing Zone | A CAF/ESA architecture concept containing subscriptions, governance, connectivity, and workloads. The term is reserved for architecture discussions and is not a Bicep deployment prefix. |
| Module | A reusable Bicep deployment unit representing one resource or tightly scoped capability. |
| Template | A composite Bicep deployment that composes modules for a deployment scenario. |
| Variables | An environment-specific `.bicepparam` file that supplies names, locations, topology IDs, and deployment values to a template. |

## Ownership Prefixes

Use the owner prefix before the deployment model:

```text
platform-*
workload-*
```

Platform resources are enterprise-managed. Workload resources support one product or business capability. The ownership prefix is independent of whether the deployment is shared, standalone, hub, or spoke.

## Deployment Models

### Hub and Spoke

Use hub and spoke when a deployment requires enterprise networking, segmentation, private connectivity, centralized security, or controlled east-west traffic.

Platform hub responsibilities commonly include:

- Hub VNets and shared connectivity
- DNS and Private DNS zones
- Firewalls and route tables
- Application gateways and Front Door integration
- Network security groups and security controls
- Shared monitoring and management services
- Identity and policy integrations

A spoke is not one global deployment. Deploy multiple spokes when isolation requires it, for example:

- Development and test
- Production
- A subsidiary tenant
- A large product or business capability

Each spoke can have its own subscription, resource group, VNet, subnets, policies, quotas, diagnostics, and platform resources. The same template may be deployed repeatedly with different parameter files.

Spoke deployments must be onboarded to a VNet and the required subnet. Spoke templates should require the relevant subnet, private endpoint, private DNS, or hub resource IDs instead of silently creating public access.

### Shared

Shared means the template does not own every resource needed by the workload in its home resource group.

For a shared workload:

- Web, API, Function, storage, or other product resources are installed in the home resource group.
- App Insights, Key Vault, App Configuration, App Service plans, or other platform services may be existing resources in another resource group.
- The workload template consumes those existing resources and does not install them.
- Shared does not inherently mean private or public networking. Networking is controlled independently by the template and module settings.

Current repository example:

```text
workload-shared-web
workload-shared-func
```

These templates consume existing platform resources from another resource group, then install product resources in the home resource group. `workload-shared-web` consumes an existing App Insights resource and App Service plan, then installs the Web App. `workload-shared-func` consumes an existing App Insights resource and App Service plan, optionally installs a Storage Account in the home resource group, and installs the Function App in the home resource group.

For a shared platform service:

- The service is installed as a reusable default deployment.
- It does not require dedicated hub-and-spoke networking.
- It uses portal-style public defaults unless the template explicitly adds network isolation.

Current repository examples:

```text
platform-shared-ai-foundry
platform-shared-ai-ollama
```

### Standalone

Use standalone when the complete product stack is installed into one home resource group.

A standalone template may install:

- Log Analytics
- Application Insights
- App Service plan
- Web App
- API App
- Function App
- Storage
- SQL Server and database
- Product-specific operational resources

Current repository example:

```text
workload-standalone-web-api-sql
```

This template creates its own Log Analytics workspace, App Insights, App Service plan, Web App, API App, SQL Server, and SQL Database in the home resource group.

Standalone is not synonymous with private networking. A standalone template may use public Azure defaults. Standalone describes ownership and deployment boundaries, not network exposure.

A standalone deployment must not depend on separately managed App Insights, Key Vault, App Configuration, Foundry, Ollama, Azure OpenAI, hub networking, or spoke networking.

## Naming Convention

Template and parameter names use:

```text
{owner}-{deployment-model}-{resource-or-scenario}
```

Valid forms are:

```text
platform-hub-*
platform-spoke-*
platform-shared-*
platform-standalone-*

workload-hub-*       # use only when a workload-owned hub composition is required
workload-spoke-*
workload-shared-*
workload-standalone-*
```

The suffix describes the actual resource or scenario. Do not use `landingzone-` as a deployment prefix.

Examples:

```text
platform-hub-mgmt
platform-hub-network-publicroute
platform-hub-network-zerotrust
platform-shared-ai-foundry
platform-shared-ai-ollama
platform-spoke-ai-foundry
platform-spoke-ai-ollama
platform-spoke-mgmt
workload-shared-web
workload-standalone-web-api-sql
workload-shared-func
workload-spoke-web
workload-spoke-web-api
workload-spoke-web-api-sql
```

Parameter files use the matching template name and append the environment or operating scope:

```text
platform-shared-ai-foundry-dev.bicepparam
platform-spoke-ai-foundry-dev.bicepparam
workload-shared-web-dev.bicepparam
workload-standalone-web-api-sql-dev.bicepparam
workload-spoke-web-api-dev.bicepparam
platform-hub-mgmt-plat.bicepparam
```

## Resource Group Naming

Use:

```text
rg-{owner}-{deployment-model}-{workload}-{environment}-{sequence}
```

Examples:

```text
rg-platform-hub-networking-prod-001
rg-platform-shared-ai-prod-001
rg-platform-spoke-management-dev-001
rg-workload-shared-web-dev-001
rg-workload-standalone-web-api-sql-dev-001
rg-workload-spoke-beacon-prod-001
```

The resource group is a lifecycle and ownership boundary. A shared workload may have product resources in its home resource group and consume platform resources from a separate management resource group. A standalone workload owns all resources in its home resource group.

## Networking and Security Defaults

### Module Defaults

Reusable modules must default to portal-style public deployment behavior unless the resource has a strong platform-specific reason otherwise:

- Public network access enabled
- Network ACL default action `Allow`
- Compatible local authentication enabled
- No mandatory VNet, subnet, private endpoint, or Private DNS input
- Safe Azure defaults for TLS and encryption

This makes modules reusable for shared and standalone deployments and keeps their public API predictable.

### Hub and Spoke Overrides

Hub and spoke templates must explicitly override module defaults where the resource supports restrictions:

- Disable public network access where private access is configured.
- Set network ACLs to `Deny` by default.
- Disable local or key-based authentication where managed identity and RBAC are available.
- Require subnet resource IDs for VNet-integrated services.
- Require private endpoint resource IDs or private endpoint subnet IDs where private link is used.
- Require Private DNS zone IDs and DNS links where private endpoints are used.
- Restrict Storage, Key Vault, App Configuration, Application Insights, Foundry, and Ollama access to the intended network path.
- Configure diagnostics and alerting for platform and production spokes.

A template must not disable public access without providing or requiring a supported private access path.

### Current Security Overrides

The repository currently applies restricted settings in these compositions:

- `platform-spoke-ai-foundry`: public access disabled, network default action denied, local authentication disabled, private endpoint required, and Private DNS zone required.
- `platform-spoke-ai-ollama`: VNet-integrated Container Apps environment and internal ingress.
- `platform-spoke-mgmt`: restricted Application Insights, Key Vault subnet rules, and disabled App Configuration public access/local authentication.
- `platform-hub-mgmt`: restricted Application Insights and optional Key Vault subnet rules.
- `workload-spoke-func`: restricted Storage network access through an explicit application subnet.

Shared and standalone templates inherit module public defaults unless their own scenario explicitly requires another behavior.

## AI Service Variants

Foundry and Ollama support both deployment paths:

```text
platform-shared-ai-foundry
platform-spoke-ai-foundry
platform-shared-ai-ollama
platform-spoke-ai-ollama
```

The shared path is suitable for a default public installation without dedicated spoke networking. The spoke path is suitable for a separately isolated deployment in a development, test, production, subsidiary, or large-product spoke.

Each spoke may have its own Foundry hub, project, model deployments, quota, subscription, private endpoint, RBAC, and diagnostics. Multiple independent hubs can be deployed in different subscriptions when tenant, residency, quota, or network isolation requires it.

## Bicep Organization

Use the repository structure:

```text
bicep/
  modules/       # atoms: single resources or tightly scoped capabilities
  templates/     # organisms: scenario compositions
  variables/     # environment-specific .bicepparam files
```

Modules should remain focused. Templates own deployment topology and composition. Parameter files should remain lightweight and should not duplicate resource definitions.

## Strong Typing and Quality Baseline

- Use explicit parameter types: `string`, `int`, `bool`, `array`, or `object`.
- Add `@description(...)` to every parameter and output.
- Use `@allowed`, `@minLength`, `@maxLength`, and `@minValue` constraints where practical.
- Use `@secure()` for passwords, keys, and other secrets.
- Use explicit resource API versions.
- Keep module output contracts explicit and typed.
- Keep names deterministic and parameterized from template inputs.
- Use structured Bicep/resource properties rather than ad hoc string conventions.
- Do not introduce hub, spoke, VNet, private endpoint, or DNS dependencies into shared or standalone templates unless the deployment model is intentionally changed.

## Deployment Workflow

Validate with what-if before deployment:

```sh
az deployment group what-if \
  --resource-group <resource-group> \
  --template-file bicep/templates/<template>.bicep \
  --parameters bicep/variables/<parameters>.bicepparam
```

Deploy after validation:

```sh
az deployment group create \
  --resource-group <resource-group> \
  --template-file bicep/templates/<template>.bicep \
  --parameters bicep/variables/<parameters>.bicepparam
```

For hub and spoke deployments, validate that the deployment identity has permissions on every referenced subscription, resource group, subnet, private endpoint, and Private DNS zone.

## Decision Rules

1. If the template installs the complete product and operational stack into one home resource group, name it `workload-standalone-*`.
2. If the template installs product resources into the home resource group but consumes pre-existing platform services elsewhere, name it `workload-shared-*`.
3. If the template installs a reusable enterprise service without dedicated spoke networking, name it `platform-shared-*`.
4. If the template is VNet/subnet onboarded and participates in hub-and-spoke networking, name it `platform-spoke-*` or `workload-spoke-*` according to ownership.
5. Use `platform-hub-*` for centralized connectivity and platform network services.
6. Do not use `landingzone-` as a Bicep template or parameter prefix.
7. Keep module defaults portal-style and public; put restrictive network and identity settings in hub/spoke compositions.
8. Do not make a deployment private unless its private access path, DNS, identity, and RBAC requirements are supplied.
