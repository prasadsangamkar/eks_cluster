variable "cidr" {
  description = "The CIDR block for the VPC."
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  default     = "default"
}

variable "tag_name" {
  description = "Tag of the VPC"
}

variable "app_subnet" {
  description = "A list of app subnets inside the VPC"
  type = list(string)
  default     = []
}

variable "azs" {
  description = "List of AZ"
  type = list(string)
  default     = []
}


