---
name: scaffold-terraform
description: Use this skill to scaffold the standard Terraform module structure for `terraform-snowflake-view`. Trigger when the user wants to create or restore the root-level Terraform config files (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`), bootstrap the `examples/`, `tests/`, or `utils/` directories, or generate boilerplate for a new Snowflake view example. Also trigger when the user says "scaffold", "bootstrap", "set up the module", "regenerate the structure", or "generate the terraform files" — even if they don't mention specific filenames.
---

# scaffold-terraform — terraform-snowflake-view

Scaffold the standard structure for the `terraform-snowflake-view` Terraform module. This module is **flat** (root-level `*.tf` files, no `modules/` subdirectory) and provisions only `snowflake_view` resources via a single `views` map input consumed by `for_each`.

This skill is the canonical reference for what every scaffolded file should contain, what conventions every example must follow, and what cross-file invariants must hold. Use it whenever generating boilerplate so the output is consistent with the rest of the repository and with `CLAUDE.md`.

## When to use this skill

Trigger this skill when the user wants to:

- Create the four root Terraform files from scratch (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`)
- Restore or align files that have drifted from the standard layout
- Bootstrap a new example under `examples/` (e.g. `examples/materialized-view/`)
- Bootstrap a new Terratest file under `tests/` to cover a new example
- Bootstrap a new helper script under `utils/`
- Regenerate the entire structure after a destructive change

Do **not** trigger this skill for unrelated work — view SQL changes, grant management (which lives in a separate module), CI workflow tweaks, or README-only edits.

## Module shape

The module is a single flat Terraform module rooted at the repository root. Files live at the root, **not** under `modules/`.

```text
.
├── main.tf            # Creates snowflake_view resources via for_each over var.views
├── variables.tf       # Defines var.views — map(object({...})) with validation blocks
├── outputs.tf         # Exposes maps of view attributes keyed by var.views map keys
├── versions.tf        # Pins required Terraform and Snowflake provider versions
├── examples/
│   ├── basic/         # Single standard view over a base table
│   └── secure-view/   # Secure view with is_secure = true
├── tests/
│   ├── snowflake_view_basic_test.go
│   └── helpers_test.go
└── utils/
    ├── generate-docs.sh
    ├── lint.sh
    ├── align-md-tables.py
    └── update-badge.sh
```

## Root-level Terraform files

### `versions.tf`

Pin required Terraform and Snowflake provider versions. Always emit this first — it constrains what the rest of the module can use.

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = ">= 0.95.0, < 1.0.0"
    }
  }
}
```

### `variables.tf`

Defines a single map-based input named `views`. Every field on the object lives here, every constraint lives in a `validation` block here.

```hcl
variable "views" {
  description = "Map of Snowflake views to create. Map key is a logical Terraform identifier; the actual Snowflake view name is the `name` field."

  type = map(object({
    name      = string
    database  = string
    schema    = string
    statement = string
    is_secure = optional(bool, false)
    comment   = optional(string, null)
  }))

  default = {}

  validation {
    condition     = alltrue([for k, v in var.views : length(v.name) > 0])
    error_message = "Each view must have a non-empty `name`."
  }

  validation {
    condition     = alltrue([for k, v in var.views : length(v.database) > 0 && length(v.schema) > 0])
    error_message = "Each view must specify both `database` and `schema`."
  }

  validation {
    condition     = alltrue([for k, v in var.views : length(trimspace(v.statement)) > 0])
    error_message = "Each view must have a non-empty SQL `statement`."
  }
}
```

Validation rules to always include:

- `name` is non-empty
- `database` and `schema` are both non-empty
- `statement` is non-empty after trimming whitespace
- (Optional) `name`, `database`, `schema` match Snowflake identifier rules (alphanumeric + `_`, max 255 chars) — add when stricter validation is requested

### `main.tf`

Creates `snowflake_view` resources via `for_each` over `var.views`. Keep this file thin — no inline grants, no `count`, no nested modules.

```hcl
resource "snowflake_view" "this" {
  for_each = var.views

  name      = each.value.name
  database  = each.value.database
  schema    = each.value.schema
  statement = each.value.statement
  is_secure = each.value.is_secure
  comment   = each.value.comment
}
```

### `outputs.tf`

Expose maps keyed by the `var.views` map keys, so downstream callers can look up attributes by the same logical identifier they used as input.

```hcl
output "view_ids" {
  description = "Map of view map keys to fully-qualified Snowflake view IDs."
  value       = { for k, v in snowflake_view.this : k => v.id }
}

output "view_fully_qualified_names" {
  description = "Map of view map keys to fully-qualified view names (database.schema.name)."
  value       = { for k, v in snowflake_view.this : k => "${v.database}.${v.schema}.${v.name}" }
}

output "view_names" {
  description = "Map of view map keys to Snowflake view names."
  value       = { for k, v in snowflake_view.this : k => v.name }
}

output "view_is_secure" {
  description = "Map of view map keys to the `is_secure` flag of each view."
  value       = { for k, v in snowflake_view.this : k => v.is_secure }
}
```

## Examples

Every example under `examples/` must:

- Be self-contained (its own `terraform`, `provider`, and module call blocks)
- Call the root module via `source = "../.."` — never copy the resource inline
- Use the `views` map input — never inline `snowflake_view` resources
- Include a short `README.md` explaining what it demonstrates
- Validate cleanly via `terraform init -backend=false && terraform validate`

### Standard scaffold for a new example

```hcl
# examples/<name>/main.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = ">= 0.95.0, < 1.0.0"
    }
  }
}

provider "snowflake" {}

module "snowflake_view" {
  source = "../.."

  views = {
    # Map key is a logical Terraform identifier
    example_view = {
      name      = "EXAMPLE_VW"
      database  = "ANALYTICS_DB"
      schema    = "CONSUMPTION"
      is_secure = false

      statement = <<-SQL
        SELECT col1, col2
        FROM ANALYTICS_DB.CLEAN.SOURCE_TABLE
      SQL

      comment = "Describe what this example demonstrates."
    }
  }
}
```

### `examples/basic/`

Single standard view over a base table. `is_secure = false`. The reference for new users learning the module's input shape.

### `examples/secure-view/`

Single secure view (`is_secure = true`) for restricted data exposure. The `comment` should explain why the view is secure and which roles are expected to consume it.

## Tests

Every Terratest file under `tests/` must:

- Live under `tests/` (plural), never `test/`
- Use the helpers in `helpers_test.go` for setup, teardown, and assertions
- Target one of the configurations under `examples/` as its working directory
- Clean up via `defer terraform.Destroy(...)` — failures must not leak views into the target Snowflake account
- Reference Snowflake views in test names, log messages, and assertion errors

### Standard scaffold for a new test file

```go
// tests/<example>_test.go
package tests

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestSnowflakeView<Example>(t *testing.T) {
    t.Parallel()

    opts := buildTerraformOptions(t, "../examples/<example>")
    defer terraform.Destroy(t, opts)

    terraform.InitAndApply(t, opts)

    // 1. Output assertions
    ids := terraform.OutputMap(t, opts, "view_ids")
    assert.NotEmpty(t, ids)

    // 2. Snowflake-side verification via helpers
    db := newSnowflakeClient(t)
    defer db.Close()

    for _, fqn := range terraform.OutputMap(t, opts, "view_fully_qualified_names") {
        assertViewExists(t, db, fqn)
    }

    // 3. Idempotency
    plan := terraform.InitAndPlan(t, opts)
    assert.Contains(t, plan, "No changes")
}
```

The helper contract (`buildTerraformOptions`, `newSnowflakeClient`, `assertViewExists`, `assertViewIsSecure`, `assertViewDestroyed`, `uniqueSuffix`) is fixed — do not reinvent these per test.

## Utility scripts

Every script under `utils/` must:

- Be runnable from the repository root
- Be idempotent (no diff on a clean tree when run twice)
- Exit non-zero on failure so it can gate CI and pre-commit
- Reference Snowflake views in user-facing output

The four standard scripts are `generate-docs.sh`, `lint.sh`, `align-md-tables.py`, and `update-badge.sh` — see `CLAUDE.md` for what each one does and when it's invoked. New scripts should follow the same shape: a header comment describing purpose and invocation, strict mode (`set -euo pipefail` for bash), and a final success or failure log line.

## Cross-file invariants

After scaffolding any file, the following must hold:

- `variables.tf` declares exactly one variable named `views` of type `map(object({...}))`
- `main.tf` contains exactly one resource block: `resource "snowflake_view" "this"` with `for_each = var.views`
- `outputs.tf` declares output map names that match what `tests/helpers_test.go` reads (`view_ids`, `view_fully_qualified_names`, `view_names`, `view_is_secure`)
- `versions.tf` is the only place that pins Terraform or provider versions — examples must inherit, not redeclare with different versions
- Every example's `source = "../.."` resolves to the repository root (not `../../modules/<name>`)
- `package.json` `name` field equals `terraform-snowflake-view`
- `README.md` headings are unique (markdownlint MD024) and all GFM tables are pipe-aligned (MD060) — run `utils/generate-docs.sh` then `utils/align-md-tables.py` after any change to `variables.tf` / `outputs.tf` / `main.tf`

## Quick checklist before declaring scaffolding complete

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform init -backend=false && terraform validate` passes at the repo root
- [ ] Each `examples/*` directory passes `terraform init -backend=false && terraform validate`
- [ ] `utils/generate-docs.sh` runs cleanly and `utils/align-md-tables.py` produces no diff on `README.md`
- [ ] `pre-commit run --all-files` passes
- [ ] No leftover references to the upstream template (e.g. `terraform-aws-dynamodb`, `tables`, `autoscaling`, `s3_config`) anywhere in the scaffolded files
