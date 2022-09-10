terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.13"
    }
  }
}

resource "kubernetes_secret" "operator_webhook_certs" {
  metadata {
    labels = {
      "app.kubernetes.io/component" = "webhook",
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "operator-webhook-certs"
    namespace = "default"
  }
}

resource "kubernetes_deployment" "operator_webhook" {
  metadata {
    labels = {
      "app.kubernetes.io/component" = "operator-webhook"
      "app.kubernetes.io/name" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "operator-webhook"
    namespace = "default"
  }
  spec {
    selector {
      match_labels = {
        "app" = "operator-webhook"
        "role" = "operator-webhook"
      }
    }
    template {
      metadata {
        annotations = {
          "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
          "sidecar.istio.io/inject" = "false"
        }
        labels = {
          "app" = "operator-webhook"
          "app.kubernetes.io/component" = "operator-webhook"
          "app.kubernetes.io/name" = "knative-operator"
          "app.kubernetes.io/version" = "1.7.0"
          "operator.knative.dev/release" = "v1.7.0"
          "role" = "operator-webhook"
        }
      }
      spec {
        service_account_name = "operator-webhook"
        termination_grace_period_seconds = 300

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_labels = {
                    "app" = "webhook"
                  }
                }
              }
            }
          }
        }

        container {
          name = "operator-webhook"
          image = "gcr.io/knative-releases/knative.dev/operator/cmd/webhook@sha256:472442273a004fd6bc79afdb80d9cf968e3d052faa1f6f51769899a8010b446b"

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name = "SYSTEM_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }
          env {
            name = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }
          env {
            name = "WEBHOOK_NAME"
            value = "operator-webhook"
          }
          env {
            name = "WEBHOOK_PORT"
            value = "8443"
          }
          env {
            name = "METRICS_DOMAIN"
            value = "knative.dev/operator"
          }
        
          port {
            name = "metrics"
            container_port = 9090
          }
          port {
            name = "profiling"
            container_port = 8008
          }
          port {
            name = "https-webhook"
            container_port = 8443
          }

          readiness_probe {
            period_seconds = 1
            http_get {
              http_header {
                name = "k-kubelet-probe"
                value = "webhook"
              }
              port = 8443
              scheme = "HTTPS"
            }
          }

          liveness_probe {
            period_seconds = 1
            initial_delay_seconds = 120
            failure_threshold = 6
            http_get {
              http_header {
                name = "k-kubelet-probe"
                value = "webhook"
              }
              port = 8443
              scheme = "HTTPS"
            }
          }

          resources {
            limits = {
              "cpu" = "500m"
              "memory" = "500Mi"
            }
            requests = {
              "cpu" = "100m"
              "memory" = "100Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem = true
            run_as_non_root = true
            capabilities {
              drop = [ "all" ]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "operator_webhook" {
  metadata {
    labels = {
      "app.kubernetes.io/component" = "operator-webhook"
      "app.kubernetes.io/name" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
      "role" = "operator-webhook"
    }
    name = "operator-webhook"
    namespace = "default"
  }
  spec {
    selector = {
      "role" = "operator-webhook"
    }
    port {
      name = "http-metrics"
      port = 9090
      target_port = 9090
    }
    port {
      name = "http-profiling"
      port = 8008
      target_port = 8008
    }
    port {
      name = "https-webhook"
      port = 443
      target_port = 443
    }
  }
}

resource "kubernetes_manifest" "customresourcedefinition_knativeeventings_operator_knative_dev" {
  manifest = {
    "apiVersion" = "apiextensions.k8s.io/v1"
    "kind" = "CustomResourceDefinition"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/part-of" = "knative-operator"
        "app.kubernetes.io/version" = "1.7.0"
        "operator.knative.dev/release" = "v1.7.0"
      }
      "name" = "knativeeventings.operator.knative.dev"
    }
    "spec" = {
      "conversion" = {
        "strategy" = "Webhook"
        "webhook" = {
          "clientConfig" = {
            "service" = {
              "name" = "operator-webhook"
              "namespace" = "default"
              "path" = "/resource-conversion"
            }
          }
          "conversionReviewVersions" = [
            "v1beta1",
          ]
        }
      }
      "group" = "operator.knative.dev"
      "names" = {
        "kind" = "KnativeEventing"
        "listKind" = "KnativeEventingList"
        "plural" = "knativeeventings"
        "singular" = "knativeeventing"
      }
      "scope" = "Namespaced"
      "versions" = [
        {
          "additionalPrinterColumns" = [
            {
              "jsonPath" = ".status.version"
              "name" = "Version"
              "type" = "string"
            },
            {
              "jsonPath" = ".status.conditions[?(@.type==\"Ready\")].status"
              "name" = "Ready"
              "type" = "string"
            },
            {
              "jsonPath" = ".status.conditions[?(@.type==\"Ready\")].reason"
              "name" = "Reason"
              "type" = "string"
            },
          ]
          "name" = "v1beta1"
          "schema" = {
            "openAPIV3Schema" = {
              "description" = "Schema for the knativeeventings API"
              "properties" = {
                "apiVersion" = {
                  "description" = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#resources"
                  "type" = "string"
                }
                "kind" = {
                  "description" = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds"
                  "type" = "string"
                }
                "metadata" = {
                  "type" = "object"
                }
                "spec" = {
                  "description" = "Spec defines the desired state of KnativeEventing"
                  "properties" = {
                    "additionalManifests" = {
                      "description" = "A list of the additional eventing manifests, which will be installed by the operator"
                      "items" = {
                        "properties" = {
                          "URL" = {
                            "description" = "The link of the additional manifest URL"
                            "type" = "string"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "config" = {
                      "additionalProperties" = {
                        "additionalProperties" = {
                          "type" = "string"
                        }
                        "type" = "object"
                      }
                      "description" = "A means to override the corresponding entries in the upstream configmaps"
                      "type" = "object"
                    }
                    "defaultBrokerClass" = {
                      "description" = "The default broker type to use for the brokers Knative creates. If no value is provided, MTChannelBasedBroker will be used."
                      "type" = "string"
                    }
                    "deployments" = {
                      "description" = "A mapping of deployment name to override"
                      "items" = {
                        "properties" = {
                          "affinity" = {
                            "description" = "If specified, the pod's scheduling constraints."
                            "properties" = {
                              "nodeAffinity" = {
                                "description" = "Describes node affinity scheduling rules for the pod."
                                "properties" = {
                                  "preferredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "The scheduler will prefer to schedule pods to nodes that satisfy the affinity expressions specified by this field, but it may choose a node that violates one or more of the expressions. The node that is most preferred is the one with the greatest sum of weights, i.e. for each node that meets all of the scheduling requirements (resource request, requiredDuringScheduling affinity expressions, etc.), compute a sum by iterating through the elements of this field and adding \"weight\" to the sum if the node matches the corresponding matchExpressions; the node(s) with the highest sum are the most preferred."
                                    "items" = {
                                      "description" = "An empty preferred scheduling term matches all objects with implicit weight 0 (i.e. it's a no-op). A null preferred scheduling term matches no objects (i.e. is also a no-op)."
                                      "properties" = {
                                        "preference" = {
                                          "description" = "A node selector term, associated with the corresponding weight."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "A list of node selector requirements by node's labels."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchFields" = {
                                              "description" = "A list of node selector requirements by node's fields."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "weight" = {
                                          "description" = "Weight associated with matching the corresponding nodeSelectorTerm, in the range 1-100."
                                          "format" = "int32"
                                          "type" = "integer"
                                        }
                                      }
                                      "required" = [
                                        "preference",
                                        "weight",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "requiredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "If the affinity requirements specified by this field are not met at scheduling time, the pod will not be scheduled onto the node. If the affinity requirements specified by this field cease to be met at some point during pod execution (e.g. due to an update), the system may or may not try to eventually evict the pod from its node."
                                    "properties" = {
                                      "nodeSelectorTerms" = {
                                        "description" = "Required. A list of node selector terms. The terms are ORed."
                                        "items" = {
                                          "description" = "A null or empty node selector term matches no objects. The requirements of them are ANDed. The TopologySelectorTerm type implements a subset of the NodeSelectorTerm."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "A list of node selector requirements by node's labels."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchFields" = {
                                              "description" = "A list of node selector requirements by node's fields."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "type" = "array"
                                      }
                                    }
                                    "required" = [
                                      "nodeSelectorTerms",
                                    ]
                                    "type" = "object"
                                  }
                                }
                                "type" = "object"
                              }
                              "podAffinity" = {
                                "description" = "Describes pod affinity scheduling rules (e.g. co-locate this pod in the same node, zone, etc. as some other pod(s))."
                                "properties" = {
                                  "preferredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "The scheduler will prefer to schedule pods to nodes that satisfy the affinity expressions specified by this field, but it may choose a node that violates one or more of the expressions. The node that is most preferred is the one with the greatest sum of weights, i.e. for each node that meets all of the scheduling requirements (resource request, requiredDuringScheduling affinity expressions, etc.), compute a sum by iterating through the elements of this field and adding \"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the node(s) with the highest sum are the most preferred."
                                    "items" = {
                                      "description" = "The weights of all of the matched WeightedPodAffinityTerm fields are added per-node to find the most preferred node(s)"
                                      "properties" = {
                                        "podAffinityTerm" = {
                                          "description" = "Required. A pod affinity term, associated with the corresponding weight."
                                          "properties" = {
                                            "labelSelector" = {
                                              "description" = "A label query over a set of resources, in this case pods."
                                              "properties" = {
                                                "matchExpressions" = {
                                                  "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                                  "items" = {
                                                    "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                    "properties" = {
                                                      "key" = {
                                                        "description" = "key is the label key that the selector applies to."
                                                        "type" = "string"
                                                      }
                                                      "operator" = {
                                                        "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                        "type" = "string"
                                                      }
                                                      "values" = {
                                                        "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                        "items" = {
                                                          "type" = "string"
                                                        }
                                                        "type" = "array"
                                                      }
                                                    }
                                                    "required" = [
                                                      "key",
                                                      "operator",
                                                    ]
                                                    "type" = "object"
                                                  }
                                                  "type" = "array"
                                                }
                                                "matchLabels" = {
                                                  "additionalProperties" = {
                                                    "type" = "string"
                                                  }
                                                  "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                                  "type" = "object"
                                                }
                                              }
                                              "type" = "object"
                                            }
                                            "namespaces" = {
                                              "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                              "items" = {
                                                "type" = "string"
                                              }
                                              "type" = "array"
                                            }
                                            "topologyKey" = {
                                              "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                              "type" = "string"
                                            }
                                          }
                                          "required" = [
                                            "topologyKey",
                                          ]
                                          "type" = "object"
                                        }
                                        "weight" = {
                                          "description" = "weight associated with matching the corresponding podAffinityTerm, in the range 1-100."
                                          "format" = "int32"
                                          "type" = "integer"
                                        }
                                      }
                                      "required" = [
                                        "podAffinityTerm",
                                        "weight",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "requiredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "If the affinity requirements specified by this field are not met at scheduling time, the pod will not be scheduled onto the node. If the affinity requirements specified by this field cease to be met at some point during pod execution (e.g. due to a pod label update), the system may or may not try to eventually evict the pod from its node. When there are multiple elements, the lists of nodes corresponding to each podAffinityTerm are intersected, i.e. all terms must be satisfied."
                                    "items" = {
                                      "description" = "Defines a set of pods (namely those matching the labelSelector relative to the given namespace(s)) that this pod should be co-located (affinity) or not co-located (anti-affinity) with, where co-located is defined as running on a node whose value of the label with key <topologyKey> matches that of any node on which a pod of the set of pods is running"
                                      "properties" = {
                                        "labelSelector" = {
                                          "description" = "A label query over a set of resources, in this case pods."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                              "items" = {
                                                "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "key is the label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchLabels" = {
                                              "additionalProperties" = {
                                                "type" = "string"
                                              }
                                              "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                              "type" = "object"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "namespaces" = {
                                          "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                          "items" = {
                                            "type" = "string"
                                          }
                                          "type" = "array"
                                        }
                                        "topologyKey" = {
                                          "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                          "type" = "string"
                                        }
                                      }
                                      "required" = [
                                        "topologyKey",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                }
                                "type" = "object"
                              }
                              "podAntiAffinity" = {
                                "description" = "Describes pod anti-affinity scheduling rules (e.g. avoid putting this pod in the same node, zone, etc. as some other pod(s))."
                                "properties" = {
                                  "preferredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "The scheduler will prefer to schedule pods to nodes that satisfy the anti-affinity expressions specified by this field, but it may choose a node that violates one or more of the expressions. The node that is most preferred is the one with the greatest sum of weights, i.e. for each node that meets all of the scheduling requirements (resource request, requiredDuringScheduling anti-affinity expressions, etc.), compute a sum by iterating through the elements of this field and adding \"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the node(s) with the highest sum are the most preferred."
                                    "items" = {
                                      "description" = "The weights of all of the matched WeightedPodAffinityTerm fields are added per-node to find the most preferred node(s)"
                                      "properties" = {
                                        "podAffinityTerm" = {
                                          "description" = "Required. A pod affinity term, associated with the corresponding weight."
                                          "properties" = {
                                            "labelSelector" = {
                                              "description" = "A label query over a set of resources, in this case pods."
                                              "properties" = {
                                                "matchExpressions" = {
                                                  "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                                  "items" = {
                                                    "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                    "properties" = {
                                                      "key" = {
                                                        "description" = "key is the label key that the selector applies to."
                                                        "type" = "string"
                                                      }
                                                      "operator" = {
                                                        "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                        "type" = "string"
                                                      }
                                                      "values" = {
                                                        "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                        "items" = {
                                                          "type" = "string"
                                                        }
                                                        "type" = "array"
                                                      }
                                                    }
                                                    "required" = [
                                                      "key",
                                                      "operator",
                                                    ]
                                                    "type" = "object"
                                                  }
                                                  "type" = "array"
                                                }
                                                "matchLabels" = {
                                                  "additionalProperties" = {
                                                    "type" = "string"
                                                  }
                                                  "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                                  "type" = "object"
                                                }
                                              }
                                              "type" = "object"
                                            }
                                            "namespaces" = {
                                              "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                              "items" = {
                                                "type" = "string"
                                              }
                                              "type" = "array"
                                            }
                                            "topologyKey" = {
                                              "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                              "type" = "string"
                                            }
                                          }
                                          "required" = [
                                            "topologyKey",
                                          ]
                                          "type" = "object"
                                        }
                                        "weight" = {
                                          "description" = "weight associated with matching the corresponding podAffinityTerm, in the range 1-100."
                                          "format" = "int32"
                                          "type" = "integer"
                                        }
                                      }
                                      "required" = [
                                        "podAffinityTerm",
                                        "weight",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "requiredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "If the anti-affinity requirements specified by this field are not met at scheduling time, the pod will not be scheduled onto the node. If the anti-affinity requirements specified by this field cease to be met at some point during pod execution (e.g. due to a pod label update), the system may or may not try to eventually evict the pod from its node. When there are multiple elements, the lists of nodes corresponding to each podAffinityTerm are intersected, i.e. all terms must be satisfied."
                                    "items" = {
                                      "description" = "Defines a set of pods (namely those matching the labelSelector relative to the given namespace(s)) that this pod should be co-located (affinity) or not co-located (anti-affinity) with, where co-located is defined as running on a node whose value of the label with key <topologyKey> matches that of any node on which a pod of the set of pods is running"
                                      "properties" = {
                                        "labelSelector" = {
                                          "description" = "A label query over a set of resources, in this case pods."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                              "items" = {
                                                "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "key is the label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchLabels" = {
                                              "additionalProperties" = {
                                                "type" = "string"
                                              }
                                              "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                              "type" = "object"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "namespaces" = {
                                          "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                          "items" = {
                                            "type" = "string"
                                          }
                                          "type" = "array"
                                        }
                                        "topologyKey" = {
                                          "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                          "type" = "string"
                                        }
                                      }
                                      "required" = [
                                        "topologyKey",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                }
                                "type" = "object"
                              }
                            }
                            "type" = "object"
                          }
                          "annotations" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Annotations overrides labels for the deployment and its template."
                            "type" = "object"
                          }
                          "env" = {
                            "description" = "Env overrides env vars for the containers."
                            "items" = {
                              "properties" = {
                                "container" = {
                                  "description" = "The container name"
                                  "type" = "string"
                                }
                                "envVars" = {
                                  "description" = "The desired EnvVarRequirements"
                                  "items" = {
                                    "description" = "EnvVar represents an environment variable present in a Container."
                                    "properties" = {
                                      "name" = {
                                        "description" = "Name of the environment variable. Must be a C_IDENTIFIER."
                                        "type" = "string"
                                      }
                                      "value" = {
                                        "description" = "Variable references $(VAR_NAME) are expanded using the previously defined environment variables in the container and any service environment variables. If a variable cannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced to a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will produce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless of whether the variable exists or not. Defaults to \"\"."
                                        "type" = "string"
                                      }
                                      "value_from" = {
                                        "description" = "Source for the environment variable's value. Cannot be used if value is not empty."
                                        "properties" = {
                                          "configMapKeyRef" = {
                                            "description" = "Selects a key of a ConfigMap."
                                            "properties" = {
                                              "key" = {
                                                "description" = "The key to select."
                                                "type" = "string"
                                              }
                                              "name" = {
                                                "description" = "Name of the referent. More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names TODO: Add other useful fields. apiVersion, kind, uid?"
                                                "type" = "string"
                                              }
                                              "optional" = {
                                                "description" = "Specify whether the ConfigMap or its key must be defined"
                                                "type" = "boolean"
                                              }
                                            }
                                            "required" = [
                                              "key",
                                            ]
                                            "type" = "object"
                                          }
                                          "field_ref" = {
                                            "description" = "Selects a field of the pod: supports metadata.name, metadata.namespace, `metadata.labels['<KEY>']`, `metadata.annotations['<KEY>']`, spec.nodeName, spec.serviceAccountName, status.hostIP, status.podIP, status.podIPs."
                                            "properties" = {
                                              "apiVersion" = {
                                                "description" = "Version of the schema the field_path is written in terms of, defaults to \"v1\"."
                                                "type" = "string"
                                              }
                                              "field_path" = {
                                                "description" = "Path of the field to select in the specified API version."
                                                "type" = "string"
                                              }
                                            }
                                            "required" = [
                                              "field_path",
                                            ]
                                            "type" = "object"
                                          }
                                          "resourcefield_ref" = {
                                            "description" = "Selects a resource of the container: only resources limits and requests (limits.cpu, limits.memory, limits.ephemeral-storage, requests.cpu, requests.memory and requests.ephemeral-storage) are currently supported."
                                            "properties" = {
                                              "containerName" = {
                                                "description" = "Container name: required for volumes, optional for env vars"
                                                "type" = "string"
                                              }
                                              "divisor" = {
                                                "anyOf" = [
                                                  {
                                                    "type" = "integer"
                                                  },
                                                  {
                                                    "type" = "string"
                                                  },
                                                ]
                                                "description" = "Specifies the output format of the exposed resources, defaults to \"1\""
                                                "pattern" = "^(\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))))?$"
                                                "x-kubernetes-int-or-string" = true
                                              }
                                              "resource" = {
                                                "description" = "Required: resource to select"
                                                "type" = "string"
                                              }
                                            }
                                            "required" = [
                                              "resource",
                                            ]
                                            "type" = "object"
                                          }
                                          "secretKeyRef" = {
                                            "description" = "Selects a key of a secret in the pod's namespace"
                                            "properties" = {
                                              "key" = {
                                                "description" = "The key of the secret to select from.  Must be a valid secret key."
                                                "type" = "string"
                                              }
                                              "name" = {
                                                "description" = "Name of the referent. More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names TODO: Add other useful fields. apiVersion, kind, uid?"
                                                "type" = "string"
                                              }
                                              "optional" = {
                                                "description" = "Specify whether the Secret or its key must be defined"
                                                "type" = "boolean"
                                              }
                                            }
                                            "required" = [
                                              "key",
                                            ]
                                            "type" = "object"
                                          }
                                        }
                                        "type" = "object"
                                      }
                                    }
                                    "required" = [
                                      "name",
                                    ]
                                    "type" = "object"
                                  }
                                  "type" = "array"
                                }
                              }
                              "required" = [
                                "container",
                              ]
                              "type" = "object"
                            }
                            "type" = "array"
                          }
                          "labels" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Labels overrides labels for the deployment and its template."
                            "type" = "object"
                          }
                          "name" = {
                            "description" = "The name of the deployment"
                            "type" = "string"
                          }
                          "nodeSelector" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "NodeSelector overrides nodeSelector for the deployment."
                            "type" = "object"
                          }
                          "replicas" = {
                            "description" = "The number of replicas that HA parts of the control plane will be scaled to"
                            "minimum" = 1
                            "type" = "integer"
                          }
                          resources = {
                            "description" = "If specified, the container's resources."
                            "items" = {
                              "description" = "The pod this Resource is used to specify the requests and limits for a certain container based on the name."
                              "properties" = {
                                "container" = {
                                  "description" = "The name of the container"
                                  "type" = "string"
                                }
                                "limits" = {
                                  "properties" = {
                                    "cpu" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                    "memory" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                  }
                                  "type" = "object"
                                }
                                "requests" = {
                                  "properties" = {
                                    "cpu" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                    "memory" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                  }
                                  "type" = "object"
                                }
                              }
                              "type" = "object"
                            }
                            "type" = "array"
                          }
                          "tolerations" = {
                            "description" = "If specified, the pod's tolerations."
                            "items" = {
                              "description" = "The pod this Toleration is attached to tolerates any taint that matches the triple <key,value,effect> using the matching operator <operator>."
                              "properties" = {
                                "effect" = {
                                  "description" = "Effect indicates the taint effect to match. Empty means match all taint effects. When specified, allowed values are NoSchedule, PreferNoSchedule and NoExecute."
                                  "type" = "string"
                                }
                                "key" = {
                                  "description" = "Key is the taint key that the toleration applies to. Empty means match all taint keys. If the key is empty, operator must be Exists; this combination means to match all values and all keys."
                                  "type" = "string"
                                }
                                "operator" = {
                                  "description" = "Operator represents a key's relationship to the value. Valid operators are Exists and Equal. Defaults to Equal. Exists is equivalent to wildcard for value, so that a pod can tolerate all taints of a particular category."
                                  "type" = "string"
                                }
                                "tolerationSeconds" = {
                                  "description" = "TolerationSeconds represents the period of time the toleration (which must be of effect NoExecute, otherwise this field is ignored) tolerates the taint. By default, it is not set, which means tolerate the taint forever (do not evict). Zero and negative values will be treated as 0 (evict immediately) by the system."
                                  "format" = "int64"
                                  "type" = "integer"
                                }
                                "value" = {
                                  "description" = "Value is the taint value the toleration matches to. If the operator is Exists, the value should be empty, otherwise just a regular string."
                                  "type" = "string"
                                }
                              }
                              "type" = "object"
                            }
                            "type" = "array"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "high-availability" = {
                      "description" = "Allows specification of HA control plane"
                      "properties" = {
                        "replicas" = {
                          "description" = "The number of replicas that HA parts of the control plane will be scaled to"
                          "minimum" = 1
                          "type" = "integer"
                        }
                      }
                      "type" = "object"
                    }
                    "manifests" = {
                      "description" = "A list of eventing manifests, which will be installed by the operator"
                      "items" = {
                        "properties" = {
                          "URL" = {
                            "description" = "The link of the manifest URL"
                            "type" = "string"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "podDisruptionBudgets" = {
                      "description" = "A mapping of podDisruptionBudget name to override"
                      "items" = {
                        "properties" = {
                          "minAvailable" = {
                            "anyOf" = [
                              {
                                "type" = "integer"
                              },
                              {
                                "type" = "string"
                              },
                            ]
                            "description" = "An eviction is allowed if at least \"minAvailable\" pods selected by \"selector\" will still be available after the eviction, i.e. even in the absence of the evicted pod.  So for example you can prevent all voluntary evictions by specifying \"100%\"."
                            "x-kubernetes-int-or-string" = true
                          }
                          "name" = {
                            "description" = "The name of the podDisruptionBudget"
                            "type" = "string"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "registry" = {
                      "description" = "A means to override the corresponding deployment images in the upstream. This affects both apps/v1.Deployment and caching.internal.knative.dev/v1alpha1.Image."
                      "properties" = {
                        "default" = {
                          "description" = "The default image reference template to use for all knative images. Takes the form of example-registry.io/custom/path/$${NAME}:custom-tag"
                          "type" = "string"
                        }
                        "imagePullSecrets" = {
                          "description" = "A list of secrets to be used when pulling the knative images. The secret must be created in the same namespace as the knative-eventing deployments, and not the namespace of this resource."
                          "items" = {
                            "properties" = {
                              "name" = {
                                "description" = "The name of the secret."
                                "type" = "string"
                              }
                            }
                            "type" = "object"
                          }
                          "type" = "array"
                        }
                        "override" = {
                          "additionalProperties" = {
                            "type" = "string"
                          }
                          "description" = "A map of a container name or image name to the full image location of the individual knative image."
                          "type" = "object"
                        }
                      }
                      "type" = "object"
                    }
                    "services" = {
                      "description" = "A mapping of service name to override"
                      "items" = {
                        "properties" = {
                          "annotations" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Annotations overrides labels for the service"
                            "type" = "object"
                          }
                          "labels" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Labels overrides labels for the service"
                            "type" = "object"
                          }
                          "name" = {
                            "description" = "The name of the service"
                            "type" = "string"
                          }
                          "selector" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Selector overrides selector for the service"
                            "type" = "object"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "sinkBindingSelectionMode" = {
                      "description" = "Specifies the selection mode for the sinkbinding webhook. If the value is `inclusion`, only namespaces/objects labelled as `bindings.knative.dev/include:true` will be considered. If `exclusion` is selected, only `bindings.knative.dev/exclude:true` label is checked and these will NOT be considered. The default is `exclusion`."
                      "type" = "string"
                    }
                    "source" = {
                      "description" = "The source configuration for Knative Eventing"
                      "properties" = {
                        "ceph" = {
                          "description" = "Ceph settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                          }
                          "type" = "object"
                        }
                        "github" = {
                          "description" = "GitHub settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                          }
                          "type" = "object"
                        }
                        "gitlab" = {
                          "description" = "GitLab settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                          }
                          "type" = "object"
                        }
                        "kafka" = {
                          "description" = "Apache Kafka settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                          }
                          "type" = "object"
                        }
                        "rabbitmq" = {
                          "description" = "RabbitMQ settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                          }
                          "type" = "object"
                        }
                        "redis" = {
                          "description" = "Redis settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                          }
                          "type" = "object"
                        }
                      }
                      "type" = "object"
                    }
                    "version" = {
                      "description" = "The version of Knative Eventing to be installed"
                      "type" = "string"
                    }
                  }
                  "type" = "object"
                }
                "status" = {
                  "properties" = {
                    "conditions" = {
                      "description" = "The latest available observations of a resource's current state."
                      "items" = {
                        "properties" = {
                          "lastTransitionTime" = {
                            "description" = "LastTransitionTime is the last time the condition transitioned from one status to another. We use VolatileTime in place of metav1.Time to exclude this from creating equality.Semantic differences (all other things held constant)."
                            "type" = "string"
                          }
                          "message" = {
                            "description" = "A human readable message indicating details about the transition."
                            "type" = "string"
                          }
                          "reason" = {
                            "description" = "The reason for the condition's last transition."
                            "type" = "string"
                          }
                          "severity" = {
                            "description" = "Severity with which to treat failures of this type of condition. When this is not specified, it defaults to Error."
                            "type" = "string"
                          }
                          "status" = {
                            "description" = "Status of the condition, one of True, False, Unknown."
                            "type" = "string"
                          }
                          "type" = {
                            "description" = "Type of condition."
                            "type" = "string"
                          }
                        }
                        "required" = [
                          "type",
                          "status",
                        ]
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "manifests" = {
                      "description" = "The list of eventing manifests, which have been installed by the operator"
                      "items" = {
                        "type" = "string"
                      }
                      "type" = "array"
                    }
                    "observedGeneration" = {
                      "description" = "The generation last processed by the controller"
                      "type" = "integer"
                    }
                    "version" = {
                      "description" = "The version of the installed release"
                      "type" = "string"
                    }
                  }
                  "type" = "object"
                }
              }
              "type" = "object"
            }
          }
          "served" = true
          "storage" = true
          "subresources" = {
            "status" = {}
          }
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "customresourcedefinition_knativeservings_operator_knative_dev" {
  manifest = {
    "apiVersion" = "apiextensions.k8s.io/v1"
    "kind" = "CustomResourceDefinition"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/part-of" = "knative-operator"
        "app.kubernetes.io/version" = "1.7.0"
        "operator.knative.dev/release" = "v1.7.0"
      }
      "name" = "knativeservings.operator.knative.dev"
    }
    "spec" = {
      "conversion" = {
        "strategy" = "Webhook"
        "webhook" = {
          "clientConfig" = {
            "service" = {
              "name" = "operator-webhook"
              "namespace" = "default"
              "path" = "/resource-conversion"
            }
          }
          "conversionReviewVersions" = [
            "v1beta1",
          ]
        }
      }
      "group" = "operator.knative.dev"
      "names" = {
        "kind" = "KnativeServing"
        "listKind" = "KnativeServingList"
        "plural" = "knativeservings"
        "singular" = "knativeserving"
      }
      "scope" = "Namespaced"
      "versions" = [
        {
          "additionalPrinterColumns" = [
            {
              "jsonPath" = ".status.version"
              "name" = "Version"
              "type" = "string"
            },
            {
              "jsonPath" = ".status.conditions[?(@.type==\"Ready\")].status"
              "name" = "Ready"
              "type" = "string"
            },
            {
              "jsonPath" = ".status.conditions[?(@.type==\"Ready\")].reason"
              "name" = "Reason"
              "type" = "string"
            },
          ]
          "name" = "v1beta1"
          "schema" = {
            "openAPIV3Schema" = {
              "description" = "Schema for the knativeservings API"
              "properties" = {
                "apiVersion" = {
                  "description" = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#resources"
                  "type" = "string"
                }
                "kind" = {
                  "description" = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds"
                  "type" = "string"
                }
                "metadata" = {
                  "type" = "object"
                }
                "spec" = {
                  "description" = "Spec defines the desired state of KnativeServing"
                  "properties" = {
                    "additionalManifests" = {
                      "description" = "A list of the additional serving manifests, which will be installed by the operator"
                      "items" = {
                        "properties" = {
                          "URL" = {
                            "description" = "The link of the additional manifest URL"
                            "type" = "string"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "config" = {
                      "additionalProperties" = {
                        "additionalProperties" = {
                          "type" = "string"
                        }
                        "type" = "object"
                      }
                      "description" = "A means to override the corresponding entries in the upstream configmaps"
                      "type" = "object"
                    }
                    "controller-custom-certs" = {
                      "description" = "Enabling the controller to trust registries with self-signed certificates"
                      "properties" = {
                        "name" = {
                          "description" = "The name of the ConfigMap or Secret"
                          "type" = "string"
                        }
                        "type" = {
                          "description" = "One of ConfigMap or Secret"
                          "enum" = [
                            "ConfigMap",
                            "Secret",
                            "",
                          ]
                          "type" = "string"
                        }
                      }
                      "type" = "object"
                    }
                    "deployments" = {
                      "description" = "A mapping of deployment name to override"
                      "items" = {
                        "properties" = {
                          "affinity" = {
                            "description" = "If specified, the pod's scheduling constraints."
                            "properties" = {
                              "nodeAffinity" = {
                                "description" = "Describes node affinity scheduling rules for the pod."
                                "properties" = {
                                  "preferredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "The scheduler will prefer to schedule pods to nodes that satisfy the affinity expressions specified by this field, but it may choose a node that violates one or more of the expressions. The node that is most preferred is the one with the greatest sum of weights, i.e. for each node that meets all of the scheduling requirements (resource request, requiredDuringScheduling affinity expressions, etc.), compute a sum by iterating through the elements of this field and adding \"weight\" to the sum if the node matches the corresponding matchExpressions; the node(s) with the highest sum are the most preferred."
                                    "items" = {
                                      "description" = "An empty preferred scheduling term matches all objects with implicit weight 0 (i.e. it's a no-op). A null preferred scheduling term matches no objects (i.e. is also a no-op)."
                                      "properties" = {
                                        "preference" = {
                                          "description" = "A node selector term, associated with the corresponding weight."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "A list of node selector requirements by node's labels."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchFields" = {
                                              "description" = "A list of node selector requirements by node's fields."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "weight" = {
                                          "description" = "Weight associated with matching the corresponding nodeSelectorTerm, in the range 1-100."
                                          "format" = "int32"
                                          "type" = "integer"
                                        }
                                      }
                                      "required" = [
                                        "preference",
                                        "weight",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "requiredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "If the affinity requirements specified by this field are not met at scheduling time, the pod will not be scheduled onto the node. If the affinity requirements specified by this field cease to be met at some point during pod execution (e.g. due to an update), the system may or may not try to eventually evict the pod from its node."
                                    "properties" = {
                                      "nodeSelectorTerms" = {
                                        "description" = "Required. A list of node selector terms. The terms are ORed."
                                        "items" = {
                                          "description" = "A null or empty node selector term matches no objects. The requirements of them are ANDed. The TopologySelectorTerm type implements a subset of the NodeSelectorTerm."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "A list of node selector requirements by node's labels."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchFields" = {
                                              "description" = "A list of node selector requirements by node's fields."
                                              "items" = {
                                                "description" = "A node selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "The label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "type" = "array"
                                      }
                                    }
                                    "required" = [
                                      "nodeSelectorTerms",
                                    ]
                                    "type" = "object"
                                  }
                                }
                                "type" = "object"
                              }
                              "podAffinity" = {
                                "description" = "Describes pod affinity scheduling rules (e.g. co-locate this pod in the same node, zone, etc. as some other pod(s))."
                                "properties" = {
                                  "preferredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "The scheduler will prefer to schedule pods to nodes that satisfy the affinity expressions specified by this field, but it may choose a node that violates one or more of the expressions. The node that is most preferred is the one with the greatest sum of weights, i.e. for each node that meets all of the scheduling requirements (resource request, requiredDuringScheduling affinity expressions, etc.), compute a sum by iterating through the elements of this field and adding \"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the node(s) with the highest sum are the most preferred."
                                    "items" = {
                                      "description" = "The weights of all of the matched WeightedPodAffinityTerm fields are added per-node to find the most preferred node(s)"
                                      "properties" = {
                                        "podAffinityTerm" = {
                                          "description" = "Required. A pod affinity term, associated with the corresponding weight."
                                          "properties" = {
                                            "labelSelector" = {
                                              "description" = "A label query over a set of resources, in this case pods."
                                              "properties" = {
                                                "matchExpressions" = {
                                                  "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                                  "items" = {
                                                    "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                    "properties" = {
                                                      "key" = {
                                                        "description" = "key is the label key that the selector applies to."
                                                        "type" = "string"
                                                      }
                                                      "operator" = {
                                                        "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                        "type" = "string"
                                                      }
                                                      "values" = {
                                                        "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                        "items" = {
                                                          "type" = "string"
                                                        }
                                                        "type" = "array"
                                                      }
                                                    }
                                                    "required" = [
                                                      "key",
                                                      "operator",
                                                    ]
                                                    "type" = "object"
                                                  }
                                                  "type" = "array"
                                                }
                                                "matchLabels" = {
                                                  "additionalProperties" = {
                                                    "type" = "string"
                                                  }
                                                  "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                                  "type" = "object"
                                                }
                                              }
                                              "type" = "object"
                                            }
                                            "namespaces" = {
                                              "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                              "items" = {
                                                "type" = "string"
                                              }
                                              "type" = "array"
                                            }
                                            "topologyKey" = {
                                              "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                              "type" = "string"
                                            }
                                          }
                                          "required" = [
                                            "topologyKey",
                                          ]
                                          "type" = "object"
                                        }
                                        "weight" = {
                                          "description" = "weight associated with matching the corresponding podAffinityTerm, in the range 1-100."
                                          "format" = "int32"
                                          "type" = "integer"
                                        }
                                      }
                                      "required" = [
                                        "podAffinityTerm",
                                        "weight",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "requiredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "If the affinity requirements specified by this field are not met at scheduling time, the pod will not be scheduled onto the node. If the affinity requirements specified by this field cease to be met at some point during pod execution (e.g. due to a pod label update), the system may or may not try to eventually evict the pod from its node. When there are multiple elements, the lists of nodes corresponding to each podAffinityTerm are intersected, i.e. all terms must be satisfied."
                                    "items" = {
                                      "description" = "Defines a set of pods (namely those matching the labelSelector relative to the given namespace(s)) that this pod should be co-located (affinity) or not co-located (anti-affinity) with, where co-located is defined as running on a node whose value of the label with key <topologyKey> matches that of any node on which a pod of the set of pods is running"
                                      "properties" = {
                                        "labelSelector" = {
                                          "description" = "A label query over a set of resources, in this case pods."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                              "items" = {
                                                "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "key is the label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchLabels" = {
                                              "additionalProperties" = {
                                                "type" = "string"
                                              }
                                              "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                              "type" = "object"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "namespaces" = {
                                          "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                          "items" = {
                                            "type" = "string"
                                          }
                                          "type" = "array"
                                        }
                                        "topologyKey" = {
                                          "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                          "type" = "string"
                                        }
                                      }
                                      "required" = [
                                        "topologyKey",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                }
                                "type" = "object"
                              }
                              "podAntiAffinity" = {
                                "description" = "Describes pod anti-affinity scheduling rules (e.g. avoid putting this pod in the same node, zone, etc. as some other pod(s))."
                                "properties" = {
                                  "preferredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "The scheduler will prefer to schedule pods to nodes that satisfy the anti-affinity expressions specified by this field, but it may choose a node that violates one or more of the expressions. The node that is most preferred is the one with the greatest sum of weights, i.e. for each node that meets all of the scheduling requirements (resource request, requiredDuringScheduling anti-affinity expressions, etc.), compute a sum by iterating through the elements of this field and adding \"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the node(s) with the highest sum are the most preferred."
                                    "items" = {
                                      "description" = "The weights of all of the matched WeightedPodAffinityTerm fields are added per-node to find the most preferred node(s)"
                                      "properties" = {
                                        "podAffinityTerm" = {
                                          "description" = "Required. A pod affinity term, associated with the corresponding weight."
                                          "properties" = {
                                            "labelSelector" = {
                                              "description" = "A label query over a set of resources, in this case pods."
                                              "properties" = {
                                                "matchExpressions" = {
                                                  "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                                  "items" = {
                                                    "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                    "properties" = {
                                                      "key" = {
                                                        "description" = "key is the label key that the selector applies to."
                                                        "type" = "string"
                                                      }
                                                      "operator" = {
                                                        "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                        "type" = "string"
                                                      }
                                                      "values" = {
                                                        "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                        "items" = {
                                                          "type" = "string"
                                                        }
                                                        "type" = "array"
                                                      }
                                                    }
                                                    "required" = [
                                                      "key",
                                                      "operator",
                                                    ]
                                                    "type" = "object"
                                                  }
                                                  "type" = "array"
                                                }
                                                "matchLabels" = {
                                                  "additionalProperties" = {
                                                    "type" = "string"
                                                  }
                                                  "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                                  "type" = "object"
                                                }
                                              }
                                              "type" = "object"
                                            }
                                            "namespaces" = {
                                              "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                              "items" = {
                                                "type" = "string"
                                              }
                                              "type" = "array"
                                            }
                                            "topologyKey" = {
                                              "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                              "type" = "string"
                                            }
                                          }
                                          "required" = [
                                            "topologyKey",
                                          ]
                                          "type" = "object"
                                        }
                                        "weight" = {
                                          "description" = "weight associated with matching the corresponding podAffinityTerm, in the range 1-100."
                                          "format" = "int32"
                                          "type" = "integer"
                                        }
                                      }
                                      "required" = [
                                        "podAffinityTerm",
                                        "weight",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "requiredDuringSchedulingIgnoredDuringExecution" = {
                                    "description" = "If the anti-affinity requirements specified by this field are not met at scheduling time, the pod will not be scheduled onto the node. If the anti-affinity requirements specified by this field cease to be met at some point during pod execution (e.g. due to a pod label update), the system may or may not try to eventually evict the pod from its node. When there are multiple elements, the lists of nodes corresponding to each podAffinityTerm are intersected, i.e. all terms must be satisfied."
                                    "items" = {
                                      "description" = "Defines a set of pods (namely those matching the labelSelector relative to the given namespace(s)) that this pod should be co-located (affinity) or not co-located (anti-affinity) with, where co-located is defined as running on a node whose value of the label with key <topologyKey> matches that of any node on which a pod of the set of pods is running"
                                      "properties" = {
                                        "labelSelector" = {
                                          "description" = "A label query over a set of resources, in this case pods."
                                          "properties" = {
                                            "matchExpressions" = {
                                              "description" = "matchExpressions is a list of label selector requirements. The requirements are ANDed."
                                              "items" = {
                                                "description" = "A label selector requirement is a selector that contains values, a key, and an operator that relates the key and values."
                                                "properties" = {
                                                  "key" = {
                                                    "description" = "key is the label key that the selector applies to."
                                                    "type" = "string"
                                                  }
                                                  "operator" = {
                                                    "description" = "operator represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists and DoesNotExist."
                                                    "type" = "string"
                                                  }
                                                  "values" = {
                                                    "description" = "values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. This array is replaced during a strategic merge patch."
                                                    "items" = {
                                                      "type" = "string"
                                                    }
                                                    "type" = "array"
                                                  }
                                                }
                                                "required" = [
                                                  "key",
                                                  "operator",
                                                ]
                                                "type" = "object"
                                              }
                                              "type" = "array"
                                            }
                                            "matchLabels" = {
                                              "additionalProperties" = {
                                                "type" = "string"
                                              }
                                              "description" = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels map is equivalent to an element of matchExpressions, whose key field is \"key\", the operator is \"In\", and the values array contains only \"value\". The requirements are ANDed."
                                              "type" = "object"
                                            }
                                          }
                                          "type" = "object"
                                        }
                                        "namespaces" = {
                                          "description" = "namespaces specifies which namespaces the labelSelector applies to (matches against); null or empty list means \"this pod's namespace\""
                                          "items" = {
                                            "type" = "string"
                                          }
                                          "type" = "array"
                                        }
                                        "topologyKey" = {
                                          "description" = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching the labelSelector in the specified namespaces, where co-located is defined as running on a node whose value of the label with key topologyKey matches that of any node on which any of the selected pods is running. Empty topologyKey is not allowed."
                                          "type" = "string"
                                        }
                                      }
                                      "required" = [
                                        "topologyKey",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                }
                                "type" = "object"
                              }
                            }
                            "type" = "object"
                          }
                          "annotations" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Annotations overrides labels for the deployment and its template."
                            "type" = "object"
                          }
                          "env" = {
                            "description" = "Env overrides env vars for the containers."
                            "items" = {
                              "properties" = {
                                "container" = {
                                  "description" = "The container name"
                                  "type" = "string"
                                }
                                "envVars" = {
                                  "description" = "The desired EnvVarRequirements"
                                  "items" = {
                                    "description" = "EnvVar represents an environment variable present in a Container."
                                    "properties" = {
                                      "name" = {
                                        "description" = "Name of the environment variable. Must be a C_IDENTIFIER."
                                        "type" = "string"
                                      }
                                      "value" = {
                                        "description" = "Variable references $(VAR_NAME) are expanded using the previously defined environment variables in the container and any service environment variables. If a variable cannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced to a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will produce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless of whether the variable exists or not. Defaults to \"\"."
                                        "type" = "string"
                                      }
                                      "value_from" = {
                                        "description" = "Source for the environment variable's value. Cannot be used if value is not empty."
                                        "properties" = {
                                          "configMapKeyRef" = {
                                            "description" = "Selects a key of a ConfigMap."
                                            "properties" = {
                                              "key" = {
                                                "description" = "The key to select."
                                                "type" = "string"
                                              }
                                              "name" = {
                                                "description" = "Name of the referent. More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names TODO: Add other useful fields. apiVersion, kind, uid?"
                                                "type" = "string"
                                              }
                                              "optional" = {
                                                "description" = "Specify whether the ConfigMap or its key must be defined"
                                                "type" = "boolean"
                                              }
                                            }
                                            "required" = [
                                              "key",
                                            ]
                                            "type" = "object"
                                          }
                                          "field_ref" = {
                                            "description" = "Selects a field of the pod: supports metadata.name, metadata.namespace, `metadata.labels['<KEY>']`, `metadata.annotations['<KEY>']`, spec.nodeName, spec.serviceAccountName, status.hostIP, status.podIP, status.podIPs."
                                            "properties" = {
                                              "apiVersion" = {
                                                "description" = "Version of the schema the field_path is written in terms of, defaults to \"v1\"."
                                                "type" = "string"
                                              }
                                              "field_path" = {
                                                "description" = "Path of the field to select in the specified API version."
                                                "type" = "string"
                                              }
                                            }
                                            "required" = [
                                              "field_path",
                                            ]
                                            "type" = "object"
                                          }
                                          "resourcefield_ref" = {
                                            "description" = "Selects a resource of the container: only resources limits and requests (limits.cpu, limits.memory, limits.ephemeral-storage, requests.cpu, requests.memory and requests.ephemeral-storage) are currently supported."
                                            "properties" = {
                                              "containerName" = {
                                                "description" = "Container name: required for volumes, optional for env vars"
                                                "type" = "string"
                                              }
                                              "divisor" = {
                                                "anyOf" = [
                                                  {
                                                    "type" = "integer"
                                                  },
                                                  {
                                                    "type" = "string"
                                                  },
                                                ]
                                                "description" = "Specifies the output format of the exposed resources, defaults to \"1\""
                                                "pattern" = "^(\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))))?$"
                                                "x-kubernetes-int-or-string" = true
                                              }
                                              "resource" = {
                                                "description" = "Required: resource to select"
                                                "type" = "string"
                                              }
                                            }
                                            "required" = [
                                              "resource",
                                            ]
                                            "type" = "object"
                                          }
                                          "secretKeyRef" = {
                                            "description" = "Selects a key of a secret in the pod's namespace"
                                            "properties" = {
                                              "key" = {
                                                "description" = "The key of the secret to select from.  Must be a valid secret key."
                                                "type" = "string"
                                              }
                                              "name" = {
                                                "description" = "Name of the referent. More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names TODO: Add other useful fields. apiVersion, kind, uid?"
                                                "type" = "string"
                                              }
                                              "optional" = {
                                                "description" = "Specify whether the Secret or its key must be defined"
                                                "type" = "boolean"
                                              }
                                            }
                                            "required" = [
                                              "key",
                                            ]
                                            "type" = "object"
                                          }
                                        }
                                        "type" = "object"
                                      }
                                    }
                                    "required" = [
                                      "name",
                                    ]
                                    "type" = "object"
                                  }
                                  "type" = "array"
                                }
                              }
                              "required" = [
                                "container",
                              ]
                              "type" = "object"
                            }
                            "type" = "array"
                          }
                          "labels" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Labels overrides labels for the deployment and its template."
                            "type" = "object"
                          }
                          "name" = {
                            "description" = "The name of the deployment"
                            "type" = "string"
                          }
                          "nodeSelector" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "NodeSelector overrides nodeSelector for the deployment."
                            "type" = "object"
                          }
                          "replicas" = {
                            "description" = "The number of replicas that HA parts of the control plane will be scaled to"
                            "minimum" = 1
                            "type" = "integer"
                          }
                          resources = {
                            "description" = "If specified, the container's resources."
                            "items" = {
                              "description" = "The pod this Resource is used to specify the requests and limits for a certain container based on the name."
                              "properties" = {
                                "container" = {
                                  "description" = "The name of the container"
                                  "type" = "string"
                                }
                                "limits" = {
                                  "properties" = {
                                    "cpu" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                    "memory" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                  }
                                  "type" = "object"
                                }
                                "requests" = {
                                  "properties" = {
                                    "cpu" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                    "memory" = {
                                      "pattern" = "^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$"
                                      "type" = "string"
                                    }
                                  }
                                  "type" = "object"
                                }
                              }
                              "type" = "object"
                            }
                            "type" = "array"
                          }
                          "tolerations" = {
                            "description" = "If specified, the pod's tolerations."
                            "items" = {
                              "description" = "The pod this Toleration is attached to tolerates any taint that matches the triple <key,value,effect> using the matching operator <operator>."
                              "properties" = {
                                "effect" = {
                                  "description" = "Effect indicates the taint effect to match. Empty means match all taint effects. When specified, allowed values are NoSchedule, PreferNoSchedule and NoExecute."
                                  "type" = "string"
                                }
                                "key" = {
                                  "description" = "Key is the taint key that the toleration applies to. Empty means match all taint keys. If the key is empty, operator must be Exists; this combination means to match all values and all keys."
                                  "type" = "string"
                                }
                                "operator" = {
                                  "description" = "Operator represents a key's relationship to the value. Valid operators are Exists and Equal. Defaults to Equal. Exists is equivalent to wildcard for value, so that a pod can tolerate all taints of a particular category."
                                  "type" = "string"
                                }
                                "tolerationSeconds" = {
                                  "description" = "TolerationSeconds represents the period of time the toleration (which must be of effect NoExecute, otherwise this field is ignored) tolerates the taint. By default, it is not set, which means tolerate the taint forever (do not evict). Zero and negative values will be treated as 0 (evict immediately) by the system."
                                  "format" = "int64"
                                  "type" = "integer"
                                }
                                "value" = {
                                  "description" = "Value is the taint value the toleration matches to. If the operator is Exists, the value should be empty, otherwise just a regular string."
                                  "type" = "string"
                                }
                              }
                              "type" = "object"
                            }
                            "type" = "array"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "high-availability" = {
                      "description" = "Allows specification of HA control plane"
                      "properties" = {
                        "replicas" = {
                          "description" = "The number of replicas that HA parts of the control plane will be scaled to"
                          "minimum" = 1
                          "type" = "integer"
                        }
                      }
                      "type" = "object"
                    }
                    "ingress" = {
                      "description" = "The ingress configuration for Knative Serving"
                      "properties" = {
                        "contour" = {
                          "description" = "Contour settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                          }
                          "type" = "object"
                        }
                        "istio" = {
                          "description" = "Istio settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                            "knative-ingress-gateway" = {
                              "description" = "A means to override the knative-ingress-gateway"
                              "properties" = {
                                "selector" = {
                                  "additionalProperties" = {
                                    "type" = "string"
                                  }
                                  "description" = "The selector for the ingress-gateway."
                                  "type" = "object"
                                }
                                "servers" = {
                                  "description" = "A list of server specifications."
                                  "items" = {
                                    "properties" = {
                                      "hosts" = {
                                        "description" = "One or more hosts exposed by this gateway."
                                        "items" = {
                                          "format" = "string"
                                          "type" = "string"
                                        }
                                        "type" = "array"
                                      }
                                      "port" = {
                                        "properties" = {
                                          "name" = {
                                            "description" = "Label assigned to the port."
                                            "format" = "string"
                                            "type" = "string"
                                          }
                                          "number" = {
                                            "description" = "A valid non-negative integer port number."
                                            "type" = "integer"
                                          }
                                          "protocol" = {
                                            "description" = "The protocol exposed on the port."
                                            "format" = "string"
                                            "type" = "string"
                                          }
                                          "target_port" = {
                                            "description" = "A valid non-negative integer target port number."
                                            "type" = "integer"
                                          }
                                        }
                                        "type" = "object"
                                      }
                                    }
                                    "type" = "object"
                                  }
                                  "type" = "array"
                                }
                              }
                              "type" = "object"
                            }
                            "knative-local-gateway" = {
                              "description" = "A means to override the knative-local-gateway"
                              "properties" = {
                                "selector" = {
                                  "additionalProperties" = {
                                    "type" = "string"
                                  }
                                  "description" = "The selector for the ingress-gateway."
                                  "type" = "object"
                                }
                                "servers" = {
                                  "description" = "A list of server specifications."
                                  "items" = {
                                    "properties" = {
                                      "hosts" = {
                                        "description" = "One or more hosts exposed by this gateway."
                                        "items" = {
                                          "format" = "string"
                                          "type" = "string"
                                        }
                                        "type" = "array"
                                      }
                                      "port" = {
                                        "properties" = {
                                          "name" = {
                                            "description" = "Label assigned to the port."
                                            "format" = "string"
                                            "type" = "string"
                                          }
                                          "number" = {
                                            "description" = "A valid non-negative integer port number."
                                            "type" = "integer"
                                          }
                                          "protocol" = {
                                            "description" = "The protocol exposed on the port."
                                            "format" = "string"
                                            "type" = "string"
                                          }
                                          "target_port" = {
                                            "description" = "A valid non-negative integer target port number."
                                            "type" = "integer"
                                          }
                                        }
                                        "type" = "object"
                                      }
                                    }
                                    "type" = "object"
                                  }
                                  "type" = "array"
                                }
                              }
                              "type" = "object"
                            }
                          }
                          "type" = "object"
                        }
                        "kourier" = {
                          "description" = "Kourier settings"
                          "properties" = {
                            "enabled" = {
                              "type" = "boolean"
                            }
                            "service-type" = {
                              "type" = "string"
                            }
                          }
                          "type" = "object"
                        }
                      }
                      "type" = "object"
                    }
                    "manifests" = {
                      "description" = "A list of serving manifests, which will be installed by the operator"
                      "items" = {
                        "properties" = {
                          "URL" = {
                            "description" = "The link of the manifest URL"
                            "type" = "string"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "podDisruptionBudgets" = {
                      "description" = "A mapping of podDisruptionBudget name to override"
                      "items" = {
                        "properties" = {
                          "minAvailable" = {
                            "anyOf" = [
                              {
                                "type" = "integer"
                              },
                              {
                                "type" = "string"
                              },
                            ]
                            "description" = "An eviction is allowed if at least \"minAvailable\" pods selected by \"selector\" will still be available after the eviction, i.e. even in the absence of the evicted pod.  So for example you can prevent all voluntary evictions by specifying \"100%\"."
                            "x-kubernetes-int-or-string" = true
                          }
                          "name" = {
                            "description" = "The name of the podDisruptionBudget"
                            "type" = "string"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "registry" = {
                      "description" = "A means to override the corresponding deployment images in the upstream. This affects both apps/v1.Deployment and caching.internal.knative.dev/v1alpha1.Image."
                      "properties" = {
                        "default" = {
                          "description" = "The default image reference template to use for all knative images. Takes the form of example-registry.io/custom/path/$${NAME}:custom-tag"
                          "type" = "string"
                        }
                        "imagePullSecrets" = {
                          "description" = "A list of secrets to be used when pulling the knative images. The secret must be created in the same namespace as the knative-serving deployments, and not the namespace of this resource."
                          "items" = {
                            "properties" = {
                              "name" = {
                                "description" = "The name of the secret."
                                "type" = "string"
                              }
                            }
                            "type" = "object"
                          }
                          "type" = "array"
                        }
                        "override" = {
                          "additionalProperties" = {
                            "type" = "string"
                          }
                          "description" = "A map of a container name or image name to the full image location of the individual knative image."
                          "type" = "object"
                        }
                      }
                      "type" = "object"
                    }
                    "services" = {
                      "description" = "A mapping of service name to override"
                      "items" = {
                        "properties" = {
                          "annotations" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Annotations overrides labels for the service"
                            "type" = "object"
                          }
                          "labels" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Labels overrides labels for the service"
                            "type" = "object"
                          }
                          "name" = {
                            "description" = "The name of the service"
                            "type" = "string"
                          }
                          "selector" = {
                            "additionalProperties" = {
                              "type" = "string"
                            }
                            "description" = "Selector overrides selector for the service"
                            "type" = "object"
                          }
                        }
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "version" = {
                      "description" = "The version of Knative Serving to be installed"
                      "type" = "string"
                    }
                  }
                  "type" = "object"
                }
                "status" = {
                  "description" = "Status defines the observed state of KnativeServing"
                  "properties" = {
                    "conditions" = {
                      "description" = "The latest available observations of a resource's current state."
                      "items" = {
                        "properties" = {
                          "lastTransitionTime" = {
                            "description" = "LastTransitionTime is the last time the condition transitioned from one status to another. We use VolatileTime in place of metav1.Time to exclude this from creating equality.Semantic differences (all other things held constant)."
                            "type" = "string"
                          }
                          "message" = {
                            "description" = "A human readable message indicating details about the transition."
                            "type" = "string"
                          }
                          "reason" = {
                            "description" = "The reason for the condition's last transition."
                            "type" = "string"
                          }
                          "severity" = {
                            "description" = "Severity with which to treat failures of this type of condition. When this is not specified, it defaults to Error."
                            "type" = "string"
                          }
                          "status" = {
                            "description" = "Status of the condition, one of True, False, Unknown."
                            "type" = "string"
                          }
                          "type" = {
                            "description" = "Type of condition."
                            "type" = "string"
                          }
                        }
                        "required" = [
                          "type",
                          "status",
                        ]
                        "type" = "object"
                      }
                      "type" = "array"
                    }
                    "manifests" = {
                      "description" = "The list of serving manifests, which have been installed by the operator"
                      "items" = {
                        "type" = "string"
                      }
                      "type" = "array"
                    }
                    "observedGeneration" = {
                      "description" = "The generation last processed by the controller"
                      "type" = "integer"
                    }
                    "version" = {
                      "description" = "The version of the installed release"
                      "type" = "string"
                    }
                  }
                  "type" = "object"
                }
              }
              "type" = "object"
            }
          }
          "served" = true
          "storage" = true
          "subresources" = {
            "status" = {}
          }
        },
      ]
    }
  }
}

resource "kubernetes_cluster_role" "knative_serving_operator_aggregated" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-serving-operator-aggregated"
  }
  aggregation_rule {
    cluster_role_selectors {
      match_expressions {
        key = "serving.knative.dev/release"
        operator = "Exists"
      }
    }
  }
}

resource "kubernetes_cluster_role" "knative_serving_operator_aggregated_stable" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-serving-operator-aggregated-stable"
  }
  aggregation_rule {
    cluster_role_selectors {
      match_expressions {
        key = "app.kubernetes.io/name"
        operator = "In"
        values = [
          "knative-serving",
        ]
      }
    }
  }
}

resource "kubernetes_cluster_role" "knative_eventing_operator_aggregated" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-eventing-operator-aggregated"
  }
  aggregation_rule {
    cluster_role_selectors {
      match_expressions {
        key = "eventing.knative.dev/release"
        operator = "Exists"
      }
    }
  }
}

resource "kubernetes_cluster_role" "knative_eventing_operator_aggregated_stable" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-eventing-operator-aggregated-stable"
  }
  aggregation_rule {
    cluster_role_selectors {
      match_expressions {
        key = "app.kubernetes.io/name"
        operator = "In"
        values = [
          "knative-eventing",
        ]
      }
    }
  }
}

resource "kubernetes_cluster_role" "knative_serving_operator" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-serving-operator"
  }
  rule {
      api_groups = [
        "operator.knative.dev",
      ]
      resources = [
        "*",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "rbac.authorization.k8s.io",
      ]
      resource_names = [
        "system:auth-delegator",
      ]
      resources = [
        "clusterroles",
      ]
      verbs = [
        "bind",
        "get",
      ]
  }
  rule {
      api_groups = [
        "rbac.authorization.k8s.io",
      ]
      resource_names = [
        "extension-apiserver-authentication-reader",
      ]
      resources = [
        "roles",
      ]
      verbs = [
        "bind",
        "get",
      ]
  }
  rule {
      api_groups = [
        "rbac.authorization.k8s.io",
      ]
      resources = [
        "clusterroles",
        "roles",
      ]
      verbs = [
        "create",
        "delete",
        "escalate",
        "get",
        "list",
        "update",
      ]
  }
  rule {
      api_groups = [
        "rbac.authorization.k8s.io",
      ]
      resources = [
        "clusterrolebindings",
        "rolebindings",
      ]
      verbs = [
        "create",
        "delete",
        "list",
        "get",
        "update",
      ]
  }
  rule {
      api_groups = [
        "apiregistration.k8s.io",
      ]
      resources = [
        "apiservices",
      ]
      verbs = [
        "update",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "services",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "caching.internal.knative.dev",
      ]
      resources = [
        "images",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "namespaces",
      ]
      verbs = [
        "get",
        "update",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "events",
      ]
      verbs = [
        "create",
        "update",
        "patch",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "configmaps",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "security.istio.io",
        "apps",
        "policy",
      ]
      resources = [
        "poddisruptionbudgets",
        "peerauthentications",
        "deployments",
        "daemonsets",
        "replicasets",
        "statefulsets",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
        "watch",
        "update",
      ]
  }
  rule {
      api_groups = [
        "apiregistration.k8s.io",
      ]
      resources = [
        "apiservices",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
      ]
  }
  rule {
      api_groups = [
        "autoscaling",
      ]
      resources = [
        "horizontalpodautoscalers",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
      ]
  }
  rule {
      api_groups = [
        "coordination.k8s.io",
      ]
      resources = [
        "leases",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "apiextensions.k8s.io",
      ]
      resources = [
        "customresourcedefinitions",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resource_names = [
        "knative-ingressgateway",
      ]
      resources = [
        "services",
        "deployments",
        "horizontalpodautoscalers",
      ]
      verbs = [
        "delete",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resource_names = [
        "config-controller",
      ]
      resources = [
        "configmaps",
      ]
      verbs = [
        "delete",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resource_names = [
        "knative-serving-operator",
      ]
      resources = [
        "serviceaccounts",
      ]
      verbs = [
        "delete",
      ]
  }
}

resource "kubernetes_cluster_role" "knative_eventing_operator" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-eventing-operator"
  }
  rule {
      api_groups = [
        "operator.knative.dev",
      ]
      resources = [
        "*",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "rbac.authorization.k8s.io",
      ]
      resources = [
        "clusterroles",
        "roles",
      ]
      verbs = [
        "create",
        "delete",
        "escalate",
        "get",
        "list",
        "update",
      ]
  }
  rule {
      api_groups = [
        "rbac.authorization.k8s.io",
      ]
      resources = [
        "clusterrolebindings",
        "rolebindings",
      ]
      verbs = [
        "create",
        "delete",
        "list",
        "get",
        "update",
      ]
  }
  rule {
      api_groups = [
        "apiregistration.k8s.io",
      ]
      resources = [
        "apiservices",
      ]
      verbs = [
        "update",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "services",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "caching.internal.knative.dev",
      ]
      resources = [
        "images",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "namespaces",
      ]
      verbs = [
        "get",
        "update",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "events",
      ]
      verbs = [
        "create",
        "update",
        "patch",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resources = [
        "configmaps",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "apps",
      ]
      resources = [
        "deployments",
        "daemonsets",
        "replicasets",
        "statefulsets",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "apiregistration.k8s.io",
      ]
      resources = [
        "apiservices",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
      ]
  }
  rule {
      api_groups = [
        "autoscaling",
      ]
      resources = [
        "horizontalpodautoscalers",
      ]
      verbs = [
        "create",
        "delete",
        "update",
        "get",
        "list",
      ]
  }
  rule {
      api_groups = [
        "coordination.k8s.io",
      ]
      resources = [
        "leases",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "apiextensions.k8s.io",
      ]
      resources = [
        "customresourcedefinitions",
      ]
      verbs = [
        "*",
      ]
  }
  rule {
      api_groups = [
        "batch",
      ]
      resources = [
        "jobs",
      ]
      verbs = [
        "create",
        "delete",
        "update",
        "get",
        "list",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "",
      ]
      resource_names = [
        "knative-eventing-operator",
      ]
      resources = [
        "serviceaccounts",
      ]
      verbs = [
        "delete",
      ]
  }
  rule {
      api_groups = [
        "rabbitmq.com",
      ]
      resources = [
        "rabbitmqclusters",
      ]
      verbs = [
        "get",
        "list",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "rabbitmq.com",
      ]
      resources = [
        "bindings",
        "queues",
        "exchanges",
      ]
      verbs = [
        "create",
        "delete",
        "get",
        "list",
        "patch",
        "update",
        "watch",
      ]
  }
  rule {
      api_groups = [
        "rabbitmq.com",
      ]
      resources = [
        "bindings/status",
        "queues/status",
        "exchanges/status",
      ]
      verbs = [
        "get",
      ]
  }
}

resource "kubernetes_service_account" "knative_operator" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-operator"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "knative_serving_operator" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-serving-operator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "knative-serving-operator"
  }
  subject {
    kind = "ServiceAccount"
    name = "knative-operator"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "knative_eventing_operator" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "operator.knative.dev/release" = "v1.7.0",
    }
    name = "knative-eventing-operator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "knative-eventing-operator"
  }
  subject {
    kind = "ServiceAccount"
    name = "knative-operator"
    namespace = "default"
  }
}

resource "kubernetes_role" "knative_operator_webhook" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator",
      "app.kubernetes.io/version" = "1.7.0",
      "eventing.knative.dev/release" = "devel",
    }
    name = "knative-operator-webhook"
    namespace = "default"
  }
  rule {
    api_groups = [
      "",
    ]
    resources = [
      "secrets",
    ]
    verbs = [
      "get",
      "create",
      "update",
      "list",
      "watch",
      "patch",
    ]
  }
}

resource "kubernetes_cluster_role" "knative_operator_webhook" {
  metadata {
    labels = {
        "app.kubernetes.io/part-of" = "knative-operator"
        "app.kubernetes.io/version" = "1.7.0"
        "eventing.knative.dev/release" = "devel"
      }
      name = "knative-operator-webhook"
  }
  rule {
    api_groups = [
      "",
    ]
    resources = [
      "configmaps",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
  rule {
    api_groups = [
      "",
    ]
    resources = [
      "namespaces",
    ]
    verbs = [
      "get",
      "create",
      "update",
      "list",
      "watch",
      "patch",
    ]
  }
  rule {
    api_groups = [
      "",
    ]
    resources = [
      "namespaces/finalizers",
    ]
    verbs = [
      "update",
    ]
  }
  rule {
    api_groups = [
      "apps",
    ]
    resources = [
      "deployments",
    ]
    verbs = [
      "get",
    ]
  }
  rule {
    api_groups = [
      "apps",
    ]
    resources = [
      "deployments/finalizers",
    ]
    verbs = [
      "update",
    ]
  }
  rule {
    api_groups = [
      "admissionregistration.k8s.io",
    ]
    resources = [
      "mutatingwebhookconfigurations",
      "validatingwebhookconfigurations",
    ]
    verbs = [
      "get",
      "list",
      "create",
      "update",
      "delete",
      "patch",
      "watch",
    ]
  }
  rule {
    api_groups = [
      "coordination.k8s.io",
    ]
    resources = [
      "leases",
    ]
    verbs = [
      "get",
      "list",
      "create",
      "update",
      "delete",
      "patch",
      "watch",
    ]
  }
  rule {
    api_groups = [
      "apiextensions.k8s.io",
    ]
    resources = [
      "customresourcedefinitions",
    ]
    verbs = [
      "get",
      "list",
      "create",
      "update",
      "delete",
      "patch",
      "watch",
    ]
  }
}

resource "kubernetes_service_account" "operator_webhook" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "operator-webhook"
    namespace = "default"
  }
}

resource "kubernetes_role_binding" "operator_webhook" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "eventing.knative.dev/release" = "devel"
    }
    name = "operator-webhook"
    namespace = "default"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "knative-operator-webhook"
  }
  subject {
    kind = "ServiceAccount"
    name = "operator-webhook"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "operator_webhook" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "operator-webhook"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "knative-operator-webhook"
  }
  subject {
    kind = "ServiceAccount"
    name = "operator-webhook"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "knative_serving_operator_aggregated" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "knative-serving-operator-aggregated"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "knative-serving-operator-aggregated"
  }
  subject {
    kind = "ServiceAccount"
    name = "knative-operator"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "knative_serving_operator_aggregated_stable" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "knative-serving-operator-aggregated-stable"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "knative-serving-operator-aggregated-stable"
  }
  subject {
    kind = "ServiceAccount"
    name = "knative-operator"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "knative_eventing_operator_aggregated" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "knative-eventing-operator-aggregated"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "knative-eventing-operator-aggregated"
  }
  subject {
    kind = "ServiceAccount"
    name = "knative-operator"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "knative_eventing_operator_aggregated_stable" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "knative-eventing-operator-aggregated-stable"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "knative-eventing-operator-aggregated-stable"
  }
  subject {
    kind = "ServiceAccount"
    name = "knative-operator"
    namespace = "default"
  }
}

resource "kubernetes_config_map" "config_logging" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "config-logging"
    namespace = "default"
  }
  data = {
    "_example" = <<-EOT
      ################################
      #                              #
      #    EXAMPLE CONFIGURATION     #
      #                              #
      ################################
      
      # This block is not actually functional configuration,
      # but serves to illustrate the available configuration
      # options and document them in a way that is accessible
      # to users that `kubectl edit` this config map.
      #
      # These sample configuration options may be copied out of
      # this example block and unindented to be in the data block
      # to actually change the configuration.
      
      # Common configuration for all Knative codebase
      zap-logger-config: |
        {
          "level": "info",
          "development": false,
          "outputPaths": ["stdout"],
          "errorOutputPaths": ["stderr"],
          "encoding": "json",
          "encoderConfig": {
            "timeKey": "ts",
            "levelKey": "level",
            "nameKey": "logger",
            "callerKey": "caller",
            "messageKey": "msg",
            "stacktraceKey": "stacktrace",
            "lineEnding": "",
            "levelEncoder": "",
            "timeEncoder": "iso8601",
            "durationEncoder": "",
            "callerEncoder": ""
          }
        }
      
      EOT
  }
}

resource "kubernetes_config_map" "config_observability" {
  metadata {
    labels = {
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "config-observability"
    namespace = "default"
  }
  data = {
    "_example" = <<-EOT
    ################################
    #                              #
    #    EXAMPLE CONFIGURATION     #
    #                              #
    ################################
    
    # This block is not actually functional configuration,
    # but serves to illustrate the available configuration
    # options and document them in a way that is accessible
    # to users that `kubectl edit` this config map.
    #
    # These sample configuration options may be copied out of
    # this example block and unindented to be in the data block
    # to actually change the configuration.
    
    # logging.enable-var-log-collection defaults to false.
    # The fluentd daemon set will be set up to collect /var/log if
    # this flag is true.
    logging.enable-var-log-collection: false
    
    # logging.revision-url-template provides a template to use for producing the
    # logging URL that is injected into the status of each Revision.
    # This value is what you might use the the Knative monitoring bundle, and provides
    # access to Kibana after setting up kubectl proxy.
    logging.revision-url-template: |
      http://localhost:8001/api/v1/namespaces/knative-monitoring/services/kibana-logging/proxy/app/kibana#/discover?_a=(query:(match:(kubernetes.labels.serving-knative-dev%2FrevisionUID:(query:'$${REVISION_UID}',type:phrase))))
    
    # If non-empty, this enables queue proxy writing request logs to stdout.
    # The value determines the shape of the request logs and it must be a valid go text/template.
    # It is important to keep this as a single line. Multiple lines are parsed as separate entities
    # by most collection agents and will split the request logs into multiple records.
    #
    # The following fields and functions are available to the template:
    #
    # Request: An http.Request (see https://golang.org/pkg/net/http/#Request)
    # representing an HTTP request received by the server.
    #
    # Response:
    # struct {
    #   Code    int       // HTTP status code (see https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml)
    #   Size    int       // An int representing the size of the response.
    #   Latency float64   // A float64 representing the latency of the response in seconds.
    # }
    #
    # Revision:
    # struct {
    #   Name          string  // Knative revision name
    #   Namespace     string  // Knative revision namespace
    #   Service       string  // Knative service name
    #   Configuration string  // Knative configuration name
    #   PodName       string  // Name of the pod hosting the revision
    #   PodIP         string  // IP of the pod hosting the revision
    # }
    #
    logging.request-log-template: '{"httpRequest": {"requestMethod": "{{.Request.Method}}", "requestUrl": "{{js .Request.RequestURI}}", "requestSize": "{{.Request.ContentLength}}", "status": {{.Response.Code}}, "responseSize": "{{.Response.Size}}", "userAgent": "{{js .Request.UserAgent}}", "remoteIp": "{{js .Request.RemoteAddr}}", "serverIp": "{{.Revision.PodIP}}", "referer": "{{js .Request.Referer}}", "latency": "{{.Response.Latency}}s", "protocol": "{{.Request.Proto}}"}, "traceId": "{{index .Request.Header "X-B3-Traceid"}}"}'
    
    # metrics.backend-destination field specifies the system metrics destination.
    # It supports either prometheus (the default) or stackdriver.
    # Note: Using stackdriver will incur additional charges
    metrics.backend-destination: prometheus
    
    # metrics.request-metrics-backend-destination specifies the request metrics
    # destination. If non-empty, it enables queue proxy to send request metrics.
    # Currently supported values: prometheus, stackdriver.
    metrics.request-metrics-backend-destination: prometheus
    
    # metrics.stackdriver-project-id field specifies the stackdriver project ID. This
    # field is optional. When running on GCE, application default credentials will be
    # used if this field is not provided.
    metrics.stackdriver-project-id: "<your stackdriver project id>"
    
    # metrics.allow-stackdriver-custom-metrics indicates whether it is allowed to send metrics to
    # Stackdriver using "global" resource type and custom metric type if the
    # metrics are not supported by "knative_revision" resource type. Setting this
    # flag to "true" could cause extra Stackdriver charge.
    # If metrics.backend-destination is not Stackdriver, this is ignored.
    metrics.allow-stackdriver-custom-metrics: "false"
    
    EOT
  }
}

resource "kubernetes_deployment" "knative_operator" {
  metadata {
    labels = {
      "app.kubernetes.io/name" = "knative-operator"
      "app.kubernetes.io/part-of" = "knative-operator"
      "app.kubernetes.io/version" = "1.7.0"
      "operator.knative.dev/release" = "v1.7.0"
    }
    name = "knative-operator"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "name" = "knative-operator"
      }
    }
    template {
      metadata {
        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
        labels = {
          "app.kubernetes.io/name" = "knative-operator"
          "app.kubernetes.io/part-of" = "knative-operator"
          "app.kubernetes.io/version" = "1.7.0"
          "name" = "knative-operator"
        }
      }
      spec {
        service_account_name = "knative-operator"
        container {
          name = "knative-operator"
          image = "gcr.io/knative-releases/knative.dev/operator/cmd/operator@sha256:f350ea6fc45495670bf1ce0b57218cc599d8c68214cbc2a8094cfda0dcaa0b3b"
          image_pull_policy = "IfNotPresent"
          
          port {
            container_port = 9090
            name = "metrics"
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name = "SYSTEM_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name = "METRICS_DOMAIN"
            value = "knative.dev/operator"
          }
          env {
            name = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }
          env {
            name = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }
        }
      }
    }
  }
}
