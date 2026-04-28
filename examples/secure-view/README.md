# secure-view — Secure Snowflake View Example

Demonstrates the security-oriented use case for the `terraform-snowflake-view` module: a single **secure** view (`is_secure = true`) that exposes a curated subset of columns from a sensitive base table.

A secure view hides its underlying SQL definition from non-owners and prevents the optimizer from leaking row-level information through query plans. Use this example as the reference when exposing PII, financial, or otherwise sensitive data through views.

## What it provisions

| Resource         | Logical key            | Snowflake name             | Type   |
| ---------------- | ---------------------- | -------------------------- | ------ |
| `snowflake_view` | `customer_pii_secure`  | `CUSTOMER_PII_SECURE_VW`   | Secure |

The view selects `cust_key`, `name`, `nation_name`, and `mkt_segment` from `${database}.${source_schema}.${source_table}`. Only the listed columns are exposed; everything else in the base table remains hidden from consumers of the view.

## Prerequisites

- A reachable Snowflake account with key-pair authentication configured for the local `snowflake` provider.
- The target database (`var.database`), the view schema (`var.schema`), and the source schema (`var.source_schema`) must already exist.
- The base table (`var.source_table`) must already exist in `${database}.${source_schema}` and expose the columns referenced in the SQL `statement`.
- The session role must have `USAGE` on the database and both schemas, `SELECT` on the base table, and `CREATE VIEW` on the view schema.
- Downstream consumers (e.g. `ANALYST_ROLE`) must be granted `SELECT` on the secure view via a separate grants module — grants are intentionally out of scope for this module.

## Usage

```bash
terraform init
terraform apply \
  -var database=ANALYTICS_DB \
  -var schema=CONSUMPTION \
  -var source_schema=CLEAN \
  -var source_table=CUSTOMER_CLEAN_DT
```

## Variables

| Name            | Description                                            | Default               |
| --------------- | ------------------------------------------------------ | --------------------- |
| `database`      | Database that owns the secure view and the source.    | `ANALYTICS_DB`        |
| `schema`        | Schema where the secure view will be created.         | `CONSUMPTION`         |
| `source_schema` | Schema that contains the base table.                   | `CLEAN`               |
| `source_table`  | Base table that the secure view selects from.         | `CUSTOMER_CLEAN_DT`   |

## Outputs

| Name                         | Description                                                     |
| ---------------------------- | --------------------------------------------------------------- |
| `view_ids`                   | Map of view map keys to fully-qualified Snowflake view IDs.     |
| `view_fully_qualified_names` | Map of view map keys to `database.schema.name`.                 |
| `view_names`                 | Map of view map keys to Snowflake view names.                   |
| `view_is_secure`             | Map of view map keys to the `is_secure` flag of each view.      |
