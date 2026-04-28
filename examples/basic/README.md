# basic — Standard Snowflake View Example

Minimum viable usage of the `terraform-snowflake-view` module: a single **standard** view (`is_secure = false`) selecting a curated column list from an existing base table.

Use this example as the reference when learning the module's `views` map input shape.

## What it provisions

| Resource         | Logical key      | Snowflake name        | Type     |
| ---------------- | ---------------- | --------------------- | -------- |
| `snowflake_view` | `customer_basic` | `CUSTOMER_BASIC_VW`   | Standard |

The view selects `cust_key`, `name`, `nation_name`, and `mkt_segment` from the base table `${database}.${schema}.${source_table}`.

## Prerequisites

- A reachable Snowflake account with key-pair authentication configured for the local `snowflake` provider.
- The target database (`var.database`) and schema (`var.schema`) must already exist.
- The base table (`var.source_table`) must already exist in `${database}.${schema}` and expose the columns referenced in the SQL `statement`.
- The session role must have `USAGE` on the database and schema, and `CREATE VIEW` on the schema.

## Usage

```bash
terraform init
terraform apply \
  -var database=ANALYTICS_DB \
  -var schema=CONSUMPTION \
  -var source_table=CUSTOMER_CLEAN_DT
```

## Variables

| Name           | Description                                   | Default               |
| -------------- | --------------------------------------------- | --------------------- |
| `database`     | Database that owns the example view.          | `ANALYTICS_DB`        |
| `schema`       | Schema that owns the example view.            | `CONSUMPTION`         |
| `source_table` | Base table the example view selects from.    | `CUSTOMER_CLEAN_DT`   |

## Outputs

| Name                         | Description                                                     |
| ---------------------------- | --------------------------------------------------------------- |
| `view_ids`                   | Map of view map keys to fully-qualified Snowflake view IDs.     |
| `view_fully_qualified_names` | Map of view map keys to `database.schema.name`.                 |
| `view_names`                 | Map of view map keys to Snowflake view names.                   |
| `view_is_secure`             | Map of view map keys to the `is_secure` flag of each view.      |
