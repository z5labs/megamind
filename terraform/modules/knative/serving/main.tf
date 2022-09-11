terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.13"
    }
  }
}

resource "kubernetes_namespace" "knative_serving" {
  metadata {
    name = "knative-serving"
  }
}

resource "kubernetes_manifest" "knative_serving" {
  manifest = {
    "apiVersion" = "operator.knative.dev/v1beta1"
    "kind" = "KnativeServing"
    "metadata" = {
      "name" = "knative-serving"
      "namespace" = kubernetes_namespace.knative_serving.metadata[0].name
    }
    "spec" = {
      "ingress" = {
        "kourier" = {
          "enabled" = true
        }
      }
      "config" = {
        "network" = {
          "ingress-class" = "kourier.ingress.networking.knative.dev"
        }
      }
    }
  }
}