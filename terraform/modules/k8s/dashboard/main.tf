terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.13"
    }
  }
}

resource "kubernetes_namespace" "namespace_kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
  }
}

resource "kubernetes_service_account" "serviceaccount_kubernetes_dashboard_kubernetes_dashboard" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_service" "service_kubernetes_dashboard_kubernetes_dashboard" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }

  spec {
    selector = {
      "k8s-app" = "kubernetes-dashboard"
    }
    port {
      port = 443
      target_port = 8443
    }
  }
}

resource "kubernetes_secret" "secret_kubernetes_dashboard_kubernetes_dashboard_certs" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard-certs"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
  type = "Opaque"
}

resource "kubernetes_secret" "secret_kubernetes_dashboard_kubernetes_dashboard_csrf" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard-csrf"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
  data = {
    "csrf" = ""
  }
  type = "Opaque"
}

resource "kubernetes_secret" "secret_kubernetes_dashboard_kubernetes_dashboard_key_holder" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard-key-holder"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
  type = "Opaque"
}

resource "kubernetes_config_map" "configmap_kubernetes_dashboard_kubernetes_dashboard_settings" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard-settings"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_role" "role_kubernetes_dashboard_kubernetes_dashboard" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
  rule {
    api_groups = [
      "",
    ]
    resource_names = [
      kubernetes_secret.secret_kubernetes_dashboard_kubernetes_dashboard_key_holder.metadata[0].name,
      kubernetes_secret.secret_kubernetes_dashboard_kubernetes_dashboard_certs.metadata[0].name,
      kubernetes_secret.secret_kubernetes_dashboard_kubernetes_dashboard_csrf.metadata[0].name,
    ]
    resources = [
      "secrets",
    ]
    verbs = [
      "get",
      "update",
      "delete",
    ]
  }
  rule {
    api_groups = [
      "",
    ]
    resource_names = [
      kubernetes_config_map.configmap_kubernetes_dashboard_kubernetes_dashboard_settings.metadata[0].name,
    ]
    resources = [
      "configmaps",
    ]
    verbs = [
      "get",
      "update",
    ]
  }
  rule {
    api_groups = [
      "",
    ]
    resource_names = [
      "heapster",
      "dashboard-metrics-scraper",
    ]
    resources = [
      "services",
    ]
    verbs = [
      "proxy",
    ]
  }
  rule {
    api_groups = [
      "",
    ]
    resource_names = [
      "heapster",
      "http:heapster:",
      "https:heapster:",
      "dashboard-metrics-scraper",
      "http:dashboard-metrics-scraper",
    ]
    resources = [
      "services/proxy",
    ]
    verbs = [
      "get",
    ]
  }
}

resource "kubernetes_cluster_role" "clusterrole_kubernetes_dashboard" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard"
  }
  rule {
    api_groups = [
      "metrics.k8s.io",
    ]
    resources = [
      "pods",
      "nodes",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
}

resource "kubernetes_role_binding" "rolebinding_kubernetes_dashboard_kubernetes_dashboard" {
  metadata {
    labels = {
        "k8s-app" = "kubernetes-dashboard"
      }
    name = "kubernetes-dashboard"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "kubernetes-dashboard"
  }
  subject {
    kind = "ServiceAccount"
    name = "kubernetes-dashboard"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "clusterrolebinding_kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "kubernetes-dashboard"
  }
  subject {
    kind = "ServiceAccount"
    name = "kubernetes-dashboard"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_deployment" "deployment_kubernetes_dashboard_kubernetes_dashboard" {
  metadata {
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
    name = "kubernetes-dashboard"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }
  spec {
    replicas = 1
    revision_history_limit = 10
    selector {
      match_labels = {
        "k8s-app" = "kubernetes-dashboard"
      }
    }
    template {
      metadata {
        labels = {
          "k8s-app" = "kubernetes-dashboard"
        }
      }

      spec {
        container {
          name = "kubernetes-dashboard"
          image = "kubernetesui/dashboard:v2.6.1"
          image_pull_policy = "Always"
          
          args = [
            "--auto-generate-certificates",
            "--namespace=${kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name}",
          ]

          liveness_probe {
            http_get {
              path = "/"
              port = 8443
              scheme = "HTTPS"
            }
            initial_delay_seconds = 30
            timeout_seconds = 30
          }

          port {
            container_port = 8443
            protocol = "TCP"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem = true
            run_as_group = 2001
            run_as_user = 1001
          }

          volume_mount {
            mount_path = "/certs"
            name = kubernetes_secret.secret_kubernetes_dashboard_kubernetes_dashboard_certs.metadata[0].name
          }
          volume_mount {
            mount_path = "/tmp"
            name = "tmp-volume"
          }
        }
        
        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        security_context {
          seccomp_profile {
            type = "RuntimeDefault"            
          }
        }
        service_account_name = "kubernetes-dashboard"
        toleration {
          effect = "NoSchedule"
          key = "node-role.kubernetes.io/master"
        }
        volume {
          name = kubernetes_secret.secret_kubernetes_dashboard_kubernetes_dashboard_certs.metadata[0].name
          secret {
            secret_name = kubernetes_secret.secret_kubernetes_dashboard_kubernetes_dashboard_certs.metadata[0].name
          }
        }
        volume {
          empty_dir {
            
          }
          name = "tmp-volume"
        }
      }
    }
  }
}

resource "kubernetes_service" "service_kubernetes_dashboard_dashboard_metrics_scraper" {
  metadata {
    labels = {
      "k8s-app" = "dashboard-metrics-scraper"
    }
    name = "dashboard-metrics-scraper"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }

  spec {
    port {
      port = 8000
      target_port = 8000
    }
    selector = {
      "k8s-app" = "dashboard-metrics-scraper"
    }
  }
}

resource "kubernetes_deployment" "deployment_kubernetes_dashboard_dashboard_metrics_scraper" {
  metadata {
    labels = {
      "k8s-app" = "dashboard-metrics-scraper"
    }
    name = "dashboard-metrics-scraper"
    namespace = kubernetes_namespace.namespace_kubernetes_dashboard.metadata[0].name
  }

  spec {
    replicas = 1
    revision_history_limit = 10

    selector {
      match_labels = {
        "k8s-app" = "dashboard-metrics-scraper"
      }
    }

    template {
      metadata {
        labels = {
          "k8s-app" = "dashboard-metrics-scraper"
        }
      }

      spec {
              node_selector = {
        "kubernetes.io/os" = "linux"
      }

      security_context {
        seccomp_profile {
          type = "RuntimeDefault"            
        }
      }

      service_account_name = "kubernetes-dashboard"

      toleration {
        effect = "NoSchedule"
        key = "node-role.kubernetes.io/master"
      }

      volume {
        empty_dir {}
        name = "tmp-volume"
      }

      container {
        image = "kubernetesui/metrics-scraper:v1.0.8"
        liveness_probe {
          http_get {
            path = "/"
            port = 8000
            scheme = "HTTP"
          }
          initial_delay_seconds = 30
          timeout_seconds = 30
        }

        name = "dashboard-metrics-scraper"

        port {
          container_port = 8000
          protocol = "TCP"
        }

        security_context {
          allow_privilege_escalation = false
          read_only_root_filesystem = true
          run_as_group = 2001
          run_as_user = 1001
        }

        volume_mount {
          mount_path = "/tmp"
          name = "tmp-volume"
        }
      }
      }
    }
  }
}
