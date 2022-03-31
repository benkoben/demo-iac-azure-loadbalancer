variable "env" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tags" {
  type = map
}

variable "web_tier_source_image_id" {
  type = string
}
variable "business_tier_001_source_image_id" {
  type = string
}
variable "business_tier_002_source_image_id" {
  type = string
}
