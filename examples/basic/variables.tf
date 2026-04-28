variable "database" {
  description = "Snowflake database that owns the example view."
  type        = string
  default     = "ANALYTICS_DB"
}

variable "schema" {
  description = "Snowflake schema that owns the example view."
  type        = string
  default     = "CONSUMPTION"
}

variable "source_table" {
  description = "Base table that the example view selects from. Must already exist in the same database/schema as the view."
  type        = string
  default     = "CUSTOMER_CLEAN_DT"
}
