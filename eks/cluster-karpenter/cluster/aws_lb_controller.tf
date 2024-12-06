module "aws_load_balancer_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"

  role_name                              = "${module.eks.cluster_name}-lb-controller"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  depends_on = [
    module.eks
  ]
}

resource "kubernetes_service_account" "aws_load_balancer_service_account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.aws_load_balancer_irsa.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

resource "helm_release" "aws_load_balancer" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.helm_chart_versions.aws_load_balancer_controller
  wait       = false

  dynamic "set" {
    for_each = {
      "region"                = var.region
      "vpcId"                 = var.vpc_id
      "serviceAccount.create" = "false"
      "serviceAccount.name"   = kubernetes_service_account.aws_load_balancer_service_account.metadata[0].name
      "clusterName"           = module.eks.cluster_name
      "replicaCount"          = 1
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}
