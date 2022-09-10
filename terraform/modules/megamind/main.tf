terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.13"
    }
  }
}

resource "kubernetes_namespace" "megamind" {
  metadata {
    name = "megamind"
  }
}