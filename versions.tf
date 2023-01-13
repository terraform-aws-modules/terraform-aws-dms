terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.17"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.7.2"
    }
  }
}
