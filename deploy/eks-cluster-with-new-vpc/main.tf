provider "aws" {
  region = "us-east-2"
  shared_credentials_file = "/home/mitchac/.aws/credentials"
  profile                 = "cmr"
}

terraform {
  required_version = ">= 1.0.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.6.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
  }
}

terraform {
  backend "local" {
    path = "local_tf_state/terraform-main.tfstate"
  }
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

locals {
  tenant      = "aws001"  # AWS account name or unique id for tenant
  environment = "preprod" # Environment area eg., preprod or prod
  zone        = "dev"     # Environment with in one sub_tenant or business unit

  kubernetes_version = "1.21"

  vpc_cidr     = "10.0.0.0/16"
  vpc_name     = join("-", [local.tenant, local.environment, local.zone, "vpc"])
  cluster_name = join("-", [local.tenant, local.environment, local.zone, "eks"])

  terraform_version = "Terraform v1.0.1"
}

module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.2.0"

  name = local.vpc_name
  cidr = local.vpc_cidr
  azs  = data.aws_availability_zones.available.names

  public_subnets  = [for k, v in data.aws_availability_zones.available.names : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in data.aws_availability_zones.available.names : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

}
#---------------------------------------------------------------
# Example to consume aws-eks-accelerator-for-terraform module
#---------------------------------------------------------------
module "aws-eks-accelerator-for-terraform" {
  source = "../.."

  tenant            = local.tenant
  environment       = local.environment
  zone              = local.zone
  terraform_version = local.terraform_version

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.aws_vpc.vpc_id
# nb modified 
  private_subnet_ids = module.aws_vpc.private_subnets

  # EKS CONTROL PLANE VARIABLES
  create_eks         = true
  kubernetes_version = local.kubernetes_version

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand22"
      instance_types  = ["c5.large"]
      subnet_ids      = module.aws_vpc.public_subnets
      desired_size    = 1
      max_size        = 3
      min_size        = 1
        }
    wj8 = {
      node_group_name = "workflow-jobs-8cpu"
      instance_types  = ["c4.2xlarge","c5.2xlarge","c6i.2xlarge"]
      subnet_ids      = module.aws_vpc.public_subnets
      desired_size    = 1
      max_size        = 8
      min_size        = 1
      capacity_type  = "SPOT"
      disk_size      = 300
      k8s_taints      = [{key = "reserved-pool", value = "true", effect = "NO_SCHEDULE"}]
      k8s_labels = {
        purpose = "workflow-jobs"
          }
        }
    wj16 = {  
      node_group_name = "workflow-jobs-16cpu"
      instance_types  = ["c4.4xlarge","c5.4xlarge","c6i.4xlarge"]
      subnet_ids      = module.aws_vpc.public_subnets
      desired_size    = 1  
      max_size        = 4
      min_size        = 1    
      capacity_type  = "SPOT"
      disk_size      = 300
      k8s_taints      = [{key = "reserved-pool", value = "true", effect = "NO_SCHEDULE"}]
      k8s_labels = {
        purpose = "workflow-jobs"
          }
        }
  }

  #ADDON
  aws_lb_ingress_controller_enable = true
  metrics_server_enable            = true
  cluster_autoscaler_enable        = true

}
