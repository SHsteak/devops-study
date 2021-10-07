locals {
  workspace = terraform.workspace == "default" ? "dev" : "prod"
}

module "vpc" {
  source = "./vpc"

  workspace  = local.workspace
  cidr_block = var.cidr_block
}


module "eks" {
  count = var.eks_enable

  source              = "./eks"
  eks_cluster_version = var.eks_cluster_version
  private_subnet_ids  = module.vpc.private_subnet_ids
  eks_node_group      = var.eks_node_group
  fargate_profiles    = var.fargate_profiles
  workspace           = local.workspace
  depends_on          = [module.vpc]
}

module "ec2-k8s" {
  count = var.eks_enable > 0 ? 0 : 1

  source                    = "./ec2-k8s"
  master_node_count         = var.master_node_count
  master_node_instance_type = var.master_node_instance_type
  worker_node_count         = var.worker_node_count
  worker_node_instance_type = var.worker_node_instance_type
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  linux_sg_id               = module.vpc.linux_sg_id
  global_name               = var.global_name
  workspace                 = local.workspace
  depends_on                = [module.vpc]
}

# # public, private 네트워크 테스트
# module "test" {
#   source             = "./test"
#   public_subnet_ids  = module.vpc.public_subnet_ids
#   private_subnet_ids = module.vpc.private_subnet_ids
#   linux_sg_id        = module.vpc.linux_sg_id
#   workspace          = local.workspace
#   depends_on = [
#     module.vpc
#   ]
# }
# output "public-ec2-public-ip" {
#   value = module.test.public-ec2-public-ip
# }
# output "private-ec2-private-ip" {
#   value = module.test.private-ec2-private-ip
# }

