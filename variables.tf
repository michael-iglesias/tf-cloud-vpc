variable "ATLAS_WORKSPACE_NAME" {}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "workspace_to_environment_map" {
  type = "map"
  default = {
    dev     = "dev"
    qa      = "qa"
    staging = "staging"
    prod    = "prod"
  }
}

variable "environment_to_size_map" {
  type = "map"
  default = {
    dev     = "small"
    qa      = "medium"
    staging = "large"
    prod    = "xlarge"
  }
}

variable "workspace_to_size_map" {
  type = "map"
  default = {
    dev = "small"
  }
}

variable "env" {
  type    = string
  default = "dev"
}
