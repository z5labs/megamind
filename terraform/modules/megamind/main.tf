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

resource "kubernetes_manifest" "subgraph_ingester" {
  manifest = {
    "apiVersion" = "serving.knative.dev/v1"
    "kind" = "Service"
    "metadata" = {
      "name" = "subgraph-ingester"
      "namespace" = kubernetes_namespace.megamind.metadata[0].name
    }
    "spec" = {
      "template" = {
        "spec" = {
          "containers" = [
            {
              "image" = "ghcr.io/z5labs/megamind/subgraph-ingester:${var.image_version}"
              "args" = ["serve", "http"]
              "ports" = [
                {
                  "containerPort" = 8080
                  "name" = "h2c"
                },
              ]
            },
          ]
        }
      }
    }
  }
}
