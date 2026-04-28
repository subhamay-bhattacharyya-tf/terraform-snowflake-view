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
