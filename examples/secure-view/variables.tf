variable "database" {
  description = "Snowflake database that owns the secure view and the source table."
  type        = string
  default     = "ANALYTICS_DB"
}

variable "schema" {
  description = "Snowflake schema where the secure view will be created."
  type        = string
  default     = "CONSUMPTION"
}

variable "source_schema" {
  description = "Schema in the database that contains the base table the secure view selects from."
  type        = string
  default     = "CLEAN"
}

variable "source_table" {
  description = "Base table that the secure view selects from. Must already exist in the configured database and source schema."
  type        = string
  default     = "CUSTOMER_CLEAN_DT"
}
