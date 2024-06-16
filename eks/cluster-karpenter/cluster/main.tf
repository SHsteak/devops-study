locals {
  eks_discovery_tag = var.eks_discovery_tag
}

data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true


  cluster_addons = var.cluster_addons

  vpc_id                   = var.vpc_id
  control_plane_subnet_ids = var.control_plane_subnet_ids
  subnet_ids = var.subnet_ids

  # Fargate profiles use the cluster primary security group so these are not utilized
  cluster_security_group_additional_rules = {
    node_to_cluster = {
      description                = "Node to Cluster"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
    cluster_to_node = {
      description                = "Cluster to Node"
      protocol                   = "all"
      from_port                  = 0
      to_port                    = 0
      type                       = "egress"
      source_node_security_group = true
    }
  }

  create_node_security_group = false
  node_security_group_id     = aws_security_group.eks_node.id


  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = "choshsh"
      groups = ["system:masters"]
    },
  ]
  aws_auth_roles = [
    # We need to add in the Karpenter node IAM role for nodes launched by Karpenter
    {
      rolearn  = module.karpenter.role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]
  kms_key_administrators = [data.aws_caller_identity.current.arn]

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" },
        {
          namespace = "kube-system"
          labels = {
            "eks.amazonaws.com/component" = "coredns"
          }
        }
      ]
      timeouts = {
        create = "15m"
        delete = "15m"
      }
    }
  }

  tags = merge(var.tags, local.eks_discovery_tag)
}

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type                        = "gp3"
    "csi.storage.k8s.io/fstype" = "ext4"
  }
}