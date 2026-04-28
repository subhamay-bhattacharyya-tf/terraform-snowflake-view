resource "snowflake_view" "this" {
  for_each = var.views

  name      = each.value.name
  database  = each.value.database
  schema    = each.value.schema
  statement = each.value.statement
  is_secure = each.value.is_secure
  comment   = each.value.comment
}
