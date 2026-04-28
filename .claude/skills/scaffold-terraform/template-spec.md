# template-spec.md — terraform-snowflake-view

This document is the **canonical specification** for every file the `scaffold-terraform` skill emits in this repository. The `SKILL.md` describes *when* and *why* to scaffold; this file describes *exactly what* the scaffolded files must contain — field by field, line by line, where it matters.

When `SKILL.md` and `template-spec.md` disagree on a literal value, **this file wins**. Treat it as the source of truth for templates.

---

## 1. Repository identity

| Field                    | Value                                                                          |
|--------------------------|--------------------------------------------------------------------------------|
| Repo name                | `terraform-snowflake-view`                                                     |
| Repo owner / org         | `subhamay-bhattacharyya-tf`                                                    |
| Full slug                | `subhamay-bhattacharyya-tf/terraform-snowflake-view`                           |
| Module shape             | Flat — root-level `*.tf` files, no `modules/` subdirectory                     |
| Snowflake resource type  | `snowflake_view` only                                                          |
| Out of scope             | Grants, roles, warehouses, databases, schemas, base tables                     |
| Module input             | Single `map(object({...}))` named `views`, consumed via `for_each`             |
| Badge gist JSON filename | `terraform-snowflake-view.json`                                                |

Every scaffolded file must be self-consistent with this table. If a scaffolded file references a different repo name, owner, or input variable name, it is **broken** and must be regenerated.

---

## 2. File inventory

The scaffolder emits exactly the following files. Anything else is either a user-edited file (preserved as-is) or an error.

| Path                                                                                                                                                | Purpose                                                           | Owner   |
|-----------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|---------|
| `versions.tf`                                                                                                                                       | Pin Terraform and Snowflake provider versions                     | Skill   |
| `variables.tf`                                                                                                                                      | Declare `var.views` with validation blocks                        | Skill   |
| `main.tf`                                                                                                                                           | Single `snowflake_view.this` resource with `for_each = var.views` | Skill   |
| `outputs.tf`                                                                                                                                        | Four output maps keyed by `var.views` keys                        | Skill   |
| `examples/basic/main.tf`                                                                                                                            | Single standard view example                                      | Skill   |
| `examples/basic/README.md`                                                                                                                          | What the example demonstrates                                     | Skill   |
| `examples/secure-view/main.tf`                                                                                                                      | Single secure view example (`is_secure = true`)                   | Skill   |
| `examples/secure-view/README.md`                                                                                                                    | What the example demonstrates                                     | Skill   |
| `tests/snowflake_view_basic_test.go`                                                                                                                | Terratest covering `examples/basic/`                              | Skill   |
| `tests/helpers_test.go`                                                                                                                             | Shared test helpers (fixed contract)                              | Skill   |
| `utils/generate-docs.sh`                                                                                                                            | Refresh terraform-docs tables in `README.md`                      | Skill   |
| `utils/lint.sh`                                                                                                                                     | tflint + trivy wrapper                                            | Skill   |
| `utils/align-md-tables.py`                                                                                                                          | Align all GFM tables in `README.md` (MD060)                       | Skill   |
| `utils/update-badge.sh`                                                                                                                             | Update shields.io custom-endpoint gist JSON                       | Skill   |
| `package.json` / `package-lock.json`                                                                                                                | semantic-release config; `name` must equal repo name              | User    |
| `README.md`                                                                                                                                         | Generated content (auto-doc tables) + hand-written prose          | Mixed   |
| `CHANGELOG.md`                                                                                                                                      | Auto-generated by semantic-release / git-cliff                    | Tooling |
| `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, `.editorconfig`, `.gitignore`, `.pre-commit-config.yaml`, `.releaserc.json`, `install-tools.sh` | Repo hygiene; preserved as-is once scaffolded                     | User    |

---

## 3. `versions.tf` — exact spec

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

**Hard requirements:**

- Exactly one `terraform { ... }` block
- Exactly one provider declared: `snowflake`
- `source` must be `Snowflake-Labs/snowflake` (not `snowflakedb/snowflake` until the repo migrates)
- `version` must use a range with both lower and upper bounds — never an unpinned `>= x.y.z` alone
- `required_version` for Terraform itself is `>= 1.5.0` (matches the lowest version that supports `optional()` defaults in object types)

**Forbidden:**

- Any `provider "snowflake" { ... }` block — provider configuration belongs in examples and consumers, not in the module
- Any `backend` block — modules never declare backends

---

## 4. `variables.tf` — exact spec

The module declares **exactly one** variable: `views`.

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

**Field-level spec:**

| Field       | Type     | Required | Default | Notes                                                              |
|-------------|----------|----------|---------|--------------------------------------------------------------------|
| `name`      | `string` | Yes      | —       | Actual Snowflake view name; conventionally upper-case              |
| `database`  | `string` | Yes      | —       | Target Snowflake database (must already exist)                     |
| `schema`    | `string` | Yes      | —       | Target Snowflake schema (must already exist)                       |
| `statement` | `string` | Yes      | —       | SQL `SELECT` body; trimmed-empty values fail validation            |
| `is_secure` | `bool`   | No       | `false` | When `true`, view definition is hidden from non-owners             |
| `comment`   | `string` | No       | `null`  | Free-text description; required by `lint.sh` for production usage  |

**Forbidden in this file:**

- Any variable other than `views` (no `database`, `schema`, `tags`, `region` top-level vars)
- Any `validation` block that references resources or data sources — validation is pure on `var.views` only
- Any `sensitive = true` flag — view metadata is not secret

---

## 5. `main.tf` — exact spec

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

**Hard requirements:**

- Exactly one resource block, with the local name `this`
- `for_each = var.views` — never `count`, never a hand-written list
- Field assignments map 1:1 to the object schema in `variables.tf`
- No `lifecycle` blocks unless a specific drift problem requires it (and then it must be commented inline explaining why)

**Forbidden:**

- Inline grant resources (`snowflake_grant_*`) — grants live in a separate module
- Data sources for databases or schemas — those are caller responsibilities
- `depends_on` — `for_each` over an input map produces correct dependency ordering by itself

---

## 6. `outputs.tf` — exact spec

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

**Hard requirements:**

- Exactly four outputs, with these exact names — `tests/helpers_test.go` reads them by name
- Every output is a `map(...)` keyed by `var.views` map keys (never a list, never a single value)
- Every output has a non-empty `description`

**Forbidden:**

- `sensitive = true` on any output — view metadata is not secret
- Outputs that expose raw resource objects (`output "views" { value = snowflake_view.this }`) — too brittle, tests pin against attribute-level outputs

---

## 7. Example spec

Every directory under `examples/` follows the same template. Below is the canonical `main.tf`; the literal values in the `views` map are the only thing that varies between examples.

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

provider "snowflake" {}

module "snowflake_view" {
  source = "../.."

  views = {
    # ↓ example-specific entries go here
  }
}
```

**Hard requirements for every example:**

- `source = "../.."` — resolves to the repo root, never `../../modules/<name>`
- `terraform` and `required_providers` blocks must match `versions.tf` exactly (same lower/upper bounds)
- `provider "snowflake" {}` is empty — auth comes from env vars (`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, etc.) so the same example runs in every developer's account and in CI without edits
- An accompanying `README.md` (≤ 30 lines) explains: what the example demonstrates, what Snowflake objects it assumes exist, and how to run it
- `terraform init -backend=false && terraform validate` must pass

### 7.1 `examples/basic/` — exact spec

`views` map content:

```hcl
views = {
  customer_basic = {
    name      = "CUSTOMER_BASIC_VW"
    database  = "ANALYTICS_DB"
    schema    = "CONSUMPTION"
    is_secure = false

    statement = <<-SQL
      SELECT
        cust_key,
        name,
        nation_name,
        mkt_segment
      FROM ANALYTICS_DB.CLEAN.CUSTOMER_CLEAN_DT
    SQL

    comment = "Standard customer view exposing curated columns for downstream analytics."
  }
}
```

**Constraints:**

- Exactly one entry
- `is_secure = false` (or omitted; the explicit `false` is preferred for clarity)
- The SQL `statement` must reference real-looking objects (`ANALYTICS_DB.CLEAN.CUSTOMER_CLEAN_DT`) so Terratest can stand up matching seed data

### 7.2 `examples/secure-view/` — exact spec

`views` map content:

```hcl
views = {
  customer_pii_secure = {
    name      = "CUSTOMER_PII_SECURE_VW"
    database  = "ANALYTICS_DB"
    schema    = "CONSUMPTION"
    is_secure = true

    statement = <<-SQL
      SELECT
        cust_key,
        name,
        nation_name,
        mkt_segment
      FROM ANALYTICS_DB.CLEAN.CUSTOMER_CLEAN_DT
    SQL

    comment = "Secure view exposing curated customer attributes; consumed by ANALYST_ROLE only. Underlying SQL hidden from non-owners."
  }
}
```

**Constraints:**

- Exactly one entry
- `is_secure = true` (the entire point of the example)
- The `comment` must explain *why* the view is secure and *which role* is the intended consumer — `lint.sh` flags secure views without this disclosure

---

## 8. Test file spec

### 8.1 `tests/snowflake_view_basic_test.go` — required structure

```go
package tests

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestSnowflakeViewBasic(t *testing.T) {
    t.Parallel()

    opts := buildTerraformOptions(t, "../examples/basic")
    defer terraform.Destroy(t, opts)

    terraform.InitAndApply(t, opts)

    // 1. Output assertions
    ids := terraform.OutputMap(t, opts, "view_ids")
    assert.Len(t, ids, 1)
    assert.Contains(t, ids, "customer_basic")

    fqns := terraform.OutputMap(t, opts, "view_fully_qualified_names")
    assert.Contains(t, fqns, "customer_basic")

    isSecure := terraform.OutputMap(t, opts, "view_is_secure")
    assert.Equal(t, "false", isSecure["customer_basic"])

    // 2. Snowflake-side verification
    db := newSnowflakeClient(t)
    defer db.Close()

    assertViewExists(t, db, fqns["customer_basic"])
    assertViewIsSecure(t, db, fqns["customer_basic"], false)

    // 3. Idempotency
    plan := terraform.InitAndPlan(t, opts)
    assert.Contains(t, plan, "No changes")
}
```

**Hard requirements:**

- `package tests`
- `t.Parallel()` at the top of every top-level test
- `defer terraform.Destroy(t, opts)` is set up **before** `InitAndApply` — never after
- All Snowflake-side assertions go through helpers (`assertViewExists`, `assertViewIsSecure`, `assertViewDestroyed`) — never raw SQL inline
- Map-key assertions check both length and exact key membership

### 8.2 `tests/helpers_test.go` — fixed contract

Helpers must expose **exactly these symbols** with **exactly these signatures**:

```go
func buildTerraformOptions(t *testing.T, exampleDir string) *terraform.Options
func newSnowflakeClient(t *testing.T) *sql.DB
func assertViewExists(t *testing.T, db *sql.DB, fullyQualifiedName string)
func assertViewIsSecure(t *testing.T, db *sql.DB, fullyQualifiedName string, expected bool)
func assertViewDestroyed(t *testing.T, db *sql.DB, fullyQualifiedName string)
func uniqueSuffix(t *testing.T) string
```

**Constraints on helpers:**

- No test logic — helpers are pure setup, teardown, and assertion primitives
- Every helper takes `*testing.T` and uses `t.Fatalf` / `t.Helper()` so failures point at the calling test, not the helper
- `buildTerraformOptions` injects `SNOWFLAKE_*` env vars and a `uniqueSuffix(t)`-derived resource name suffix into `opts.Vars`
- `newSnowflakeClient` opens a single `*sql.DB` per test, scoped to `SNOWFLAKE_ROLE` and `SNOWFLAKE_WAREHOUSE`, with a context timeout

---

## 9. Utility script spec

Every script under `utils/` must satisfy:

| Constraint           | Bash scripts                                | Python scripts                                                     |
|----------------------|---------------------------------------------|--------------------------------------------------------------------|
| Strict mode          | `set -euo pipefail` on line 1 after shebang | `from __future__ import annotations` + explicit `sys.exit()` codes |
| Idempotent           | Re-running on a clean tree produces no diff | Same                                                               |
| Exit codes           | `0` success, non-zero failure               | Same                                                               |
| Header comment       | Purpose + invocation + required env vars    | Same (module docstring)                                            |
| User-facing strings  | Reference "Snowflake views"                 | Same                                                               |
| Repo-root invocation | `bash utils/<name>.sh`                      | `python utils/<name>.py`                                           |

### 9.1 `generate-docs.sh`

- Wraps `terraform-docs markdown table --output-file README.md --output-mode inject .`
- Re-invokes `align-md-tables.py` immediately after
- Fails if `terraform-docs` binary is missing (no silent skip)

### 9.2 `lint.sh`

- Runs `tflint --recursive` first, then `trivy config .`
- Exits with the **first** non-zero exit code (does not aggregate)
- Project-specific tflint config lives at `.tflint.hcl`; trivy config inline at the script top

### 9.3 `align-md-tables.py`

- Parses `README.md` with `markdown-it-py` (or equivalent), pads every cell in every table to its column max width, writes back in place
- Verifies post-write that every row in every table has identical `|` positions; fails with a diff if not

### 9.4 `update-badge.sh`

- Reads `BADGE_GIST_ID` from env (required)
- Builds the JSON payload: `{ "schemaVersion": 1, "label": "...", "message": "...", "color": "..." }`
- Writes to `terraform-snowflake-view.json` in the gist via `gh gist edit`
- Fails if `gh` CLI is not authenticated

---

## 10. Cross-file invariants (always check before declaring scaffolding done)

1. **Variable name** — `variables.tf` declares exactly one variable, named `views`. No other variable exists at the root level.
2. **Resource name** — `main.tf` contains exactly one resource: `snowflake_view.this` with `for_each = var.views`.
3. **Output names** — `outputs.tf` declares exactly four outputs: `view_ids`, `view_fully_qualified_names`, `view_names`, `view_is_secure`. These names are also referenced literally in `tests/snowflake_view_basic_test.go`.
4. **Module source paths** — every example uses `source = "../.."` and resolves to the repo root.
5. **Provider pin parity** — `versions.tf` and every `examples/*/main.tf` declare the **same** provider source and the **same** version range. A mismatch is a bug.
6. **Helper contract parity** — every test under `tests/` uses only the helpers listed in §8.2; if a test needs a new assertion, the new helper goes in `helpers_test.go`, not inline in the test file.
7. **`package.json` name** — equals `terraform-snowflake-view`. `package-lock.json` `name` field equals the same.
8. **`CONTRIBUTING.md`** — references `terraform-snowflake-view` and links its **Reporting Issues** section to this repo's issues page.
9. **`README.md` headings** — every heading text is unique across the document (markdownlint MD024). Every GFM table is pipe-aligned (MD060).
10. **No leftover template references** — search the entire scaffolded tree for `terraform-aws-dynamodb`, `terraform-aws-s3`, `tables`, `autoscaling`, `s3_config`, `gcs_`. Any hit is a regeneration bug.

---

## 11. Drift detection

After scaffolding, run all of the following. **Every command must exit `0`.**

```bash
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
( cd examples/basic && terraform init -backend=false && terraform validate )
( cd examples/secure-view && terraform init -backend=false && terraform validate )
bash utils/lint.sh
bash utils/generate-docs.sh && python utils/align-md-tables.py
git diff --exit-code README.md       # docs must be in sync
pre-commit run --all-files
```

If any of these fails on a freshly-scaffolded tree, the scaffolder produced inconsistent output — fix `template-spec.md` (this file) first, then regenerate.
