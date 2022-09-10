**An eventually consistent Knowledge Graph construction service.**

[![Go Report Card](https://goreportcard.com/badge/github.com/z5labs/megamind)](https://goreportcard.com/report/github.com/z5labs/megamind)
[![build](https://github.com/z5labs/megamind/actions/workflows/main.yml/badge.svg)](https://github.com/z5labs/megamind/actions/workflows/main.yml/badge.svg)

Megamind is a system for constructing Knowledge Graphs through subgraphs.
The main objective of Megamind is to provide a modern, resilient, cloud
agnostic service for ingesting data into your Knowledge Graph.

## Features

### Modern

Megamind implements multiple different API endpoints allowing you to quickly
and easily integrate into your current stack. See the following list for
current API endpoint support:

- [ ] RESTful endpint
- [x] gRPC endpoint

### Cloud Agnostic

Megamind is built solely on [Kubernetes](https://kubernetes.io/) and [Knative](https://knative.dev).
Meaning you can deploy Megamind anywhere [Kubernetes](https://kubernetes.io/) is supported, such as:

- [AWS EKS](https://aws.amazon.com/pm/eks/)
- [Google Cloud GKE](https://cloud.google.com/kubernetes-engine)
- [Azure AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/)
- and, of course, your own private infrastructure

### Resilient

Megamind leverages [Kubernetes](https://kubernetes.io/) and [Knative](https://knative.dev)
to implement an event-driven architecture with great resiliency.

## Install with Terraform

*TBD*

## Install with Helm

*TBD*

## Developers

Please see [Contributing to Megamind](CONTRIBUTING.md) for guidelines on contributions.