module "snowflake_view" {
  source = "../.."

  views = {
    customer_pii_secure = {
      name      = "CUSTOMER_PII_SECURE_VW"
      database  = var.database
      schema    = var.schema
      is_secure = true

      statement = <<-SQL
        SELECT
          cust_key,
          name,
          nation_name,
          mkt_segment
        FROM ${var.database}.${var.source_schema}.${var.source_table}
      SQL

      comment = "Secure view exposing curated customer attributes; consumed by ANALYST_ROLE only. Underlying SQL hidden from non-owners."
    }
  }
}
