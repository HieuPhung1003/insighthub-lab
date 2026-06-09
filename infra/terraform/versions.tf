terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Uncomment sau khi tạo S3 bucket cho remote state (Day 3)
  # backend "s3" {
  #   bucket = "insighthub-tfstate"
  #   key    = "eks/terraform.tfstate"
  #   region = "ap-southeast-1"
  # }
}
