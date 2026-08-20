# Copilot Instructions for azure-arm

## Repository IaC Model

- This repository uses an atomic IaC design:
- `bicep/modules` are atoms (single-resource or tightly scoped reusable modules).
- `bicep/templates` are organisms (compositions of modules for a scenario/landing zone).
- `bicep/variables` contains `.bicepparam` files aligned to templates.

## Bicep Quality Baseline (Strongly Typed)

- Always use explicit parameter types (`string`, `int`, `bool`, `object`) and avoid untyped dynamic patterns.
- Prefer `@description(...)` on every parameter and output.
- Use bounded constraints wherever possible:
- `@allowed([...])` for enums and SKU/model options.
- `@minLength`, `@maxLength`, `@minValue` for guardrails.
- Use `@secure()` for secrets.
- Use explicit resource API versions in every resource declaration.
- Keep module output contracts explicit and typed (avoid broad object outputs unless necessary).

## Naming and Composition Conventions

- Keep names deterministic and parameterized from template-level inputs.
- Follow the existing composition style:
- template declares environment inputs.
- template calls one or more modules with mapped parameters.
- template surfaces key outputs required by downstream systems.
- Keep modules focused: one primary capability per module.

## Review Findings Applied

- Existing modules already use strong typing and constraints well; continue this pattern consistently for all new modules.
- Existing templates validate SKU and region values using `@allowed` and length attributes; new templates should do the same.
- Variables files are environment-specific and should stay lightweight, only setting template params and naming conventions.

## New Foundry Module Pattern

- New module: `bicep/modules/aif-foundry.bicep`
- New template: `bicep/templates/platform-shared-ai-foundry.bicep`
- New parameters: `bicep/variables/platform-shared-ai-foundry-dev.bicepparam`
- New spoke template: `bicep/templates/platform-spoke-ai-foundry.bicep`
- New spoke parameters: `bicep/variables/platform-spoke-ai-foundry-dev.bicepparam`
- Shared scope excludes private networking; spoke scope requires a private endpoint subnet and Private DNS zone.
- Spoke defaults disable public network access, deny network traffic by default, and disable local authentication.
- Reusable modules should default to portal-style public access; hub and spoke compositions must explicitly pass restrictive settings and required VNet/private endpoint inputs.
- Outputs are designed for provider wiring:
- `endpoint`
- `deploymentName`
- `projectName`
- `resourceId`

## Do / Do Not

- Do keep resource definitions public-access by default for shared scenarios unless explicitly asked otherwise.
- Do keep model/deployment settings configurable through parameters with safe defaults.
- Standalone templates install the complete product stack into one home resource group and do not consume separately managed App Insights, Key Vault, App Configuration, or network resources.
- Do not loosen existing typing/constraints for convenience.

## Deployment Workflow

- Validate first:
- `az deployment group what-if --resource-group <rg> --template-file bicep/templates/<template>.bicep --parameters bicep/variables/<params>.bicepparam`
- Deploy:
- `az deployment group create --resource-group <rg> --template-file bicep/templates/<template>.bicep --parameters bicep/variables/<params>.bicepparam`
