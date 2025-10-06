# MACM-Agent-Tools

Agent tools for Multi-purpose Application Composition Model (MACM).

## GPT Actions: `actions.yaml`

This repository includes an OpenAPI-style actions descriptor `actions.yaml` that documents the GPT Actions for the MACM (Model Architecture Catalog Management) toolset. The file serves as the source of truth for programmatic agents and developer integrations.

What `actions.yaml` provides
- API metadata (title, version, server URL)
- Catalog endpoints exposing asset types, relationships, protocols and relationship patterns
- Validation checkers for architecture models (syntax and semantic checks)
- A labels endpoint that enriches nodes with primary and secondary labels derived from their asset `type`.

Key endpoints (high level)
- POST `/catalogs/labels` — Assigns primary and secondary labels to nodes using their `type` (Primary.Secondary format). Returns `enriched_nodes`, `errors`, and `warnings`.
- GET `/catalogs/asset_types` — Lists valid asset types with descriptions.
- GET `/catalogs/relationships` — Lists available relationship types.
- GET `/catalogs/relationship_pattern` — Lists valid relationship patterns between asset types.
- GET `/catalogs/protocols` — Lists supported network protocols.
- POST `/checkers/syntax` — Validates nodes and relationships against MACM syntax rules. Accepts `ArchitectureModel` and returns `ValidationResult`.
- POST `/checkers/semantic` — Validates semantic consistency (type mapping, hosting constraints) and returns `ValidationResult`.

Data models
The OpenAPI `components.schemas` define the primary data shapes used by the API:
- `Node` — { component_id, name, type, primary_label }
- `Relationship` — { source, target, type, protocol }
- `ArchitectureModel` — { nodes: Node[], relationships: Relationship[] }
- `ValidationResult` — { valid, errors[], warnings[], summary }

Usage patterns
- As a description file for GPT-style agents that can call actions defined by the OpenAPI document.
- To generate client SDKs, mocks, or server stubs using OpenAPI tooling.
- As integration documentation for developers wiring the MACM API server into CI pipelines or test suites.

Simple examples
- Validate syntax (pseudo-curl): POST your `ArchitectureModel` JSON to `/checkers/syntax` and inspect the `ValidationResult`.
- Assign labels (pseudo-curl): POST `{ "nodes": [ { "component_id": 1, "name": "Web Server", "type": "Service.Web" } ] }` to `/catalogs/labels` and check `enriched_nodes`.

Developer notes and tips
- The server URL in `actions.yaml` defaults to `https://localhost:8080/api`. Change it to match your deployed environment before generating clients or running integration tests.
- The file uses OpenAPI 3.1. Tools that support OpenAPI 3.x should work (codegen, validators, mock servers).
- The schemas provide a convenient source of truth when creating test fixtures or validating client payloads.

Next steps (optional)
- Add curated curl/HTTPie examples for each endpoint.
- Provide a Postman collection or OpenAPI mock server for local testing.
- Generate TypeScript/Python client SDKs from `actions.yaml` and include quick usage snippets.

If you'd like, I can add any of the optional artifacts above (examples, Postman collection, mock server or generated SDKs).
