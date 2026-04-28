# Terraform Snowflake View Module

A Terraform module for creating and managing Snowflake **views** — both **standard** and **secure** — using a single map-based input consumed via `for_each`.

![Release](https://github.com/subhamay-bhattacharyya-tf/terraform-snowflake-view/actions/workflows/ci.yaml/badge.svg)&nbsp;![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?logo=snowflake&logoColor=white)&nbsp;![Commit Activity](https://img.shields.io/github/commit-activity/t/subhamay-bhattacharyya-tf/terraform-snowflake-view)&nbsp;![Last Commit](https://img.shields.io/github/last-commit/subhamay-bhattacharyya-tf/terraform-snowflake-view)&nbsp;![Release Date](https://img.shields.io/github/release-date/subhamay-bhattacharyya-tf/terraform-snowflake-view)&nbsp;![Repo Size](https://img.shields.io/github/repo-size/subhamay-bhattacharyya-tf/terraform-snowflake-view)&nbsp;![File Count](https://img.shields.io/github/directory-file-count/subhamay-bhattacharyya-tf/terraform-snowflake-view)&nbsp;![Issues](https://img.shields.io/github/issues/subhamay-bhattacharyya-tf/terraform-snowflake-view)&nbsp;![Top Language](https://img.shields.io/github/languages/top/subhamay-bhattacharyya-tf/terraform-snowflake-view)&nbsp;![Custom Endpoint](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/bsubhamay/73bb06aedb3721ff9a98cfe96f71647a/raw/terraform-snowflake-view.json?)

## Features

- Single `views` map input — provision many `snowflake_view` resources from one module call
- First-class support for **standard** and **secure** views via `is_secure`
- Built-in input validation (non-empty `name` / `database` / `schema` / `statement`, identifier shape)
- Outputs keyed by the same map key used as input for stable downstream lookups
- Grants are intentionally **out of scope** — pair with a separate grants module to align with Snowflake's privilege model and avoid drift

## Usage

```hcl
module "snowflake_view" {
  source = "github.com/subhamay-bhattacharyya-tf/terraform-snowflake-view?ref=main"

  views = {
    customer_basic = {
      name      = "CUSTOMER_BASIC_VW"
      database  = "ANALYTICS_DB"
      schema    = "CONSUMPTION"
      is_secure = false

      statement = <<-SQL
        SELECT cust_key, name, nation_name, mkt_segment
        FROM ANALYTICS_DB.CLEAN.CUSTOMER_CLEAN_DT
      SQL

      comment = "Standard view exposing curated customer attributes."
    }

    customer_pii_secure = {
      name      = "CUSTOMER_PII_SECURE_VW"
      database  = "ANALYTICS_DB"
      schema    = "CONSUMPTION"
      is_secure = true

      statement = <<-SQL
        SELECT cust_key, name, nation_name, mkt_segment
        FROM ANALYTICS_DB.CLEAN.CUSTOMER_CLEAN_DT
      SQL

      comment = "Secure view; underlying SQL hidden from non-owners."
    }
  }
}
```

The map key (e.g. `customer_basic`) is a logical Terraform identifier used in `for_each` and in the module's output maps. The actual Snowflake view name (e.g. `CUSTOMER_BASIC_VW`) lives inside the object as `name`. This separation lets the same Terraform identifier survive a Snowflake-side rename without forcing a destroy/create.

## Examples

| Example                             | Description                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| [basic](examples/basic)             | Single standard view (`is_secure = false`) over a base table — minimum viable usage. |
| [secure-view](examples/secure-view) | Secure view (`is_secure = true`) for restricted/PII data exposure.                   |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.5.0 |
| snowflake | >= 1.0.0 |

## Inputs

| Name    | Description                                                                                                               | Type                 | Default | Required |
| ------- | ------------------------------------------------------------------------------------------------------------------------- | -------------------- | ------- | -------- |
| `views` | Map of Snowflake views to create. Map key is a logical Terraform identifier; the Snowflake view name is the `name` field. | `map(object({...}))` | `{}`    | no       |

### `views` object properties

| Property    | Type     | Default | Description                                                                                  |
| ----------- | -------- | ------- | -------------------------------------------------------------------------------------------- |
| `name`      | `string` | —       | Snowflake view name. Required. Must match unquoted identifier rules.                         |
| `database`  | `string` | —       | Database that owns the view. Required.                                                       |
| `schema`    | `string` | —       | Schema that owns the view. Required.                                                         |
| `statement` | `string` | —       | SQL `SELECT` statement that defines the view. Required and must be non-empty after trimming. |
| `is_secure` | `bool`   | `false` | When `true`, creates the view as **secure** (hides underlying SQL from non-owners).          |
| `comment`   | `string` | `null`  | Optional comment attached to the view; surfaces in `INFORMATION_SCHEMA.VIEWS.COMMENT`.       |

## Outputs

| Name                         | Description                                                            |
| ---------------------------- | ---------------------------------------------------------------------- |
| `view_ids`                   | Map of view map keys to fully-qualified Snowflake view IDs.            |
| `view_fully_qualified_names` | Map of view map keys to fully-qualified view names (`db.schema.name`). |
| `view_names`                 | Map of view map keys to Snowflake view names.                          |
| `view_is_secure`             | Map of view map keys to the resolved `is_secure` flag of each view.    |

## Resources Created

| Type             | Name   | Provisioned via        |
| ---------------- | ------ | ---------------------- |
| `snowflake_view` | `this` | `for_each = var.views` |

## Validation

`variables.tf` enforces the following on every entry of the `views` map:

- `name` is non-empty and matches Snowflake unquoted-identifier rules
- `database` and `schema` are non-empty and match Snowflake unquoted-identifier rules
- `statement` is non-empty after trimming whitespace

Validation errors surface at `terraform plan` time with descriptive messages.

## Testing

Integration tests live under [`tests/`](tests/) and use **Terratest** to exercise the module against a real Snowflake account.

```bash
cd tests
go test -v -timeout 30m -run TestSnowflakeViewBasic ./snowflake_view_basic_test.go ./helpers_test.go
```

Required environment variables:

| Variable                  | Purpose                                                        |
| ------------------------- | -------------------------------------------------------------- |
| `SNOWFLAKE_ACCOUNT`       | Target Snowflake account identifier.                           |
| `SNOWFLAKE_USER`          | Service-account user with `CREATE VIEW` on the target schema.  |
| `SNOWFLAKE_PRIVATE_KEY`   | Key-pair authentication private key (preferred over password). |
| `SNOWFLAKE_ROLE`          | Role used for the test session.                                |
| `SNOWFLAKE_WAREHOUSE`     | Warehouse used to compile view definitions during apply.       |
| `SNOWFLAKE_TEST_DATABASE` | Database under which test views are created and torn down.     |
| `SNOWFLAKE_TEST_SCHEMA`   | Schema under which test views are created and torn down.       |

Tests `terraform apply` real `snowflake_view` resources, assert their state in `INFORMATION_SCHEMA.VIEWS`, verify `terraform plan` is empty (idempotency), and `terraform destroy` on teardown to leave no leaked views behind.

## CI/CD

`.github/workflows/ci.yaml` runs the following on pushes/PRs to `main`, `feature/**`, and `bug/**` when root-level `*.tf`, `examples/**`, `tests/**`, or `utils/**` files change:

1. **terraform-validate** — `fmt -check`, `init`, `validate` on the root module + `utils/lint.sh` (tflint + trivy)
2. **examples-validate** — `init` + `validate` on every directory under `examples/`
3. **snowflake-view-terratest** — real Snowflake integration test from `tests/`; on success, refreshes the README badge via `utils/update-badge.sh`
4. **docs-drift** — runs `utils/generate-docs.sh` and `utils/align-md-tables.py`, fails if `README.md` has a diff
5. **generate-changelog** — runs `git-cliff` on non-`main` branches
6. **semantic-release** — on `main` only; auto-versions via Conventional Commits and refreshes the badge with the new version

Required repo secrets/variables: `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_TEST_DATABASE`, `SNOWFLAKE_TEST_SCHEMA`, plus `BADGE_GIST_ID` for the shields.io endpoint badge.

## License

MIT License — see [LICENSE](LICENSE) for details.
