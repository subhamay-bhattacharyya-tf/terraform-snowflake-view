variable "views" {
  description = "Map of Snowflake views to create. Map key is a logical Terraform identifier; the actual Snowflake view name is the `name` field."

  type = map(object({
    name      = string
    database  = string
    schema    = string
    statement = string
    is_secure = optional(bool, false)
    comment   = optional(string, null)
  }))

  default = {}

  validation {
    condition     = alltrue([for k, v in var.views : length(v.name) > 0])
    error_message = "Each view must have a non-empty `name`."
  }

  validation {
    condition     = alltrue([for k, v in var.views : length(v.database) > 0 && length(v.schema) > 0])
    error_message = "Each view must specify both `database` and `schema`."
  }

  validation {
    condition     = alltrue([for k, v in var.views : length(trimspace(v.statement)) > 0])
    error_message = "Each view must have a non-empty SQL `statement`."
  }

  validation {
    condition     = alltrue([for k, v in var.views : can(regex("^[A-Za-z_][A-Za-z0-9_$]{0,254}$", v.name))])
    error_message = "Each view `name` must match Snowflake unquoted identifier rules: start with a letter or underscore, contain only letters/digits/underscore/dollar, max 255 chars."
  }

  validation {
    condition = alltrue([
      for k, v in var.views :
      can(regex("^[A-Za-z_][A-Za-z0-9_$]{0,254}$", v.database)) &&
      can(regex("^[A-Za-z_][A-Za-z0-9_$]{0,254}$", v.schema))
    ])
    error_message = "Each view `database` and `schema` must match Snowflake unquoted identifier rules."
  }
}
