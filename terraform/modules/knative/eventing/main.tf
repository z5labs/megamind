terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.13"
    }
  }
}

resource "kubernetes_namespace" "namespace_knative_eventing" {
  metadata {
    name = "knative-eventing"
  }
}

resource "kubernetes_manifest" "manifest_knative_eventing" {
  manifest = {
    "apiVersion" = "operator.knative.dev/v1beta1"
    "kind" = "KnativeEventing"
    "metadata" = {
      "name" = "knative-eventing"
      "namespace" = kubernetes_namespace.namespace_knative_eventing.metadata[0].name
    }
  }
}