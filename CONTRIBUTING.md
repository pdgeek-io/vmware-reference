# Contributing

This repository is customer-facing. Keep the supported surface accurate, validated, and documented.

## Contribution Rules

- Use GitHub Issues for planned work, defects, security hardening, and roadmap items.
- Use pull requests for all customer-facing changes.
- Keep repository documentation current with the code changed in the same pull request.
- Do not add runnable workflows for unvalidated features.
- Do not commit secrets, local environment files, generated inventories, Terraform state, VM media, or customer data.
- Do not add separate contributor agreements or CLA requirements unless the repository owner explicitly approves them.

Unless explicitly stated otherwise, contributions intentionally submitted to this repository are provided under the Apache License 2.0.

## Pull Request Expectations

Each pull request should include:

- the GitHub Issue or reason for the change
- implementation summary
- validation performed
- documentation impact
- security impact
- rollback or destroy notes when infrastructure behavior changes

## Supported Documentation Locations

- `README.md`: supported customer-facing workflow
- `docs/`: operator documentation for supported code
- GitHub Issues: backlog, roadmap, defects, and future work
- Pull requests: change evidence and review history

