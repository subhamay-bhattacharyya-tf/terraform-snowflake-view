module "snowflake_view" {
  source = "../.."

  views = {
    customer_basic = {
      name      = "CUSTOMER_BASIC_VW"
      database  = var.database
      schema    = var.schema
      is_secure = false

      statement = <<-SQL
        SELECT
          cust_key,
          name,
          nation_name,
          mkt_segment
        FROM ${var.database}.${var.schema}.${var.source_table}
      SQL

      comment = "Standard view exposing curated customer attributes for downstream analytics."
    }
  }
}
