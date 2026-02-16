# Licensing Notice

## This Repository

The code in this repository (Packer templates, Terraform modules, shell scripts, GitHub Actions workflows, and documentation) is licensed under the **MIT License** — see [LICENSE](./LICENSE).

## Teleport Software

This repository provides tooling to deploy [Teleport](https://goteleport.com/) agents on AWS. **Teleport itself has its own licensing terms** that you must review and comply with independently.

### Teleport Licensing Change (v16+)

Starting with Teleport 16 (released mid-2024), Gravitational changed the Teleport Community Edition license from Apache 2.0 to a **commercial license** with the following terms:

- **Individuals**: Free for personal and hobby use with no restrictions.
- **Companies with <100 employees AND <$10M annual revenue**: Free to use.
- **Companies with >=100 employees OR >=$10M annual revenue**: Must contact [Teleport sales](https://goteleport.com/signup/enterprise/) for a commercial license.
- **Resale/Embedding**: Companies cannot resell or embed Teleport Community Edition in their products or services.

Teleport Enterprise (self-hosted and cloud) has always required a commercial license.

### What This Means for You

- **This bootstrap code** (MIT): You can freely use, modify, and distribute this infrastructure-as-code.
- **Teleport software**: You must independently evaluate and comply with [Teleport's licensing terms](https://goteleport.com/pricing/) based on your organization's size and usage.

### References

- [Teleport Pricing & Licensing](https://goteleport.com/pricing/)
- [Teleport 16 Blog Post (licensing announcement)](https://goteleport.com/blog/teleport-16/)
- [Teleport Community Edition License](https://github.com/gravitational/teleport/blob/master/LICENSE)
