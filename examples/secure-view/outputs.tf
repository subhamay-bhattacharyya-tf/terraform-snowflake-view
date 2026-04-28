output "view_ids" {
  description = "Map of view map keys to fully-qualified Snowflake view IDs."
  value       = module.snowflake_view.view_ids
}

output "view_fully_qualified_names" {
  description = "Map of view map keys to fully-qualified view names (database.schema.name)."
  value       = module.snowflake_view.view_fully_qualified_names
}

output "view_names" {
  description = "Map of view map keys to Snowflake view names."
  value       = module.snowflake_view.view_names
}

output "view_is_secure" {
  description = "Map of view map keys to the `is_secure` flag of each view."
  value       = module.snowflake_view.view_is_secure
}
