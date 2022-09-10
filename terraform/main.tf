terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.13.1"
    }
  }
}

provider "kubernetes" {
  config_path = var.k8s_config_file
  config_context = var.k8s_context
}

module "k8s_dashboard" {
  source = "./modules/k8s/dashboard"
  providers = {
    kubernetes = kubernetes
  }
}

module "knative_operator" {
  source = "./modules/knative/operator"
  providers = {
    kubernetes = kubernetes
  }
}

module "knative_eventing" {
  source = "./modules/knative/eventing"
  providers = {
    kubernetes = kubernetes
  }
  depends_on = [
    module.k8s_dashboard,
    module.knative_operator,
  ]
}