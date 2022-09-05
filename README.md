# megamind

megamind is a system for constructing Knowledge Graphs through subgraphs.
The main objective of megamind is to provide a modern, resilient, cloud
agnostic service for ingesting data into your Knowledge Graph.

# Goals

## Modern

megamind implements multiple different API endpoints allowing you to quickly
and easily integrate into your current stack. See the following list for
current API endpoint support:

- [ ] RESTful endpint
- [x] gRPC endpoint

## Cloud Agnostic

megamind is built solely on [Kubernetes](https://kubernetes.io/) and [Knative](https://knative.dev).
Meaning you can deploy megamind anywhere [Kubernetes](https://kubernetes.io/) is supported, such as:

- [AWS EKS](https://aws.amazon.com/pm/eks/)
- [Google Cloud GKE](https://cloud.google.com/kubernetes-engine)
- [Azure AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/)
- and, of course, your own private infrastructure

## Resilient

megamind leverages [Kubernetes](https://kubernetes.io/) and [Knative](https://knative.dev)
to implement an event-driven architecture with great resiliency.
