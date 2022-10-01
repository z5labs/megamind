# Megamind Roadmap

## v2

*Implement a full Graph Management System*

## v1.x

### Services
*TBD*

### Infrastructure
*TBD*

### Database Support
- [ ] TypeDB?

## v1

### Services
*All services should be done*

### Infrastructure
- [ ] Publish Helm charts to registry
- [ ] Publish Terraform module to registry

### Database Support
- [ ] Dgraph

## v0 (a.k.a. MVP)

### Services
- [ ] Entity Registry
  - now with caching
- [ ] Graph Mutator
  - now with caching
- [ ] Cacher
- [ ] Disjoint Watcher
- [ ] Disjoint Resolver

### Infrastructure
- [ ] Knative Eventing
  - [ ] Kafka Channel
- [ ] Megamind
  - [ ] Cacher - Knative Service
    - [ ] Terraform
    - [ ] K8s yaml
  - [ ] etcd - K8s Service
    - [ ] Terraform
    - [ ] K8s yaml
  - [ ] Disjoint Watcher - Knative Service
    - [ ] Terraform
    - [ ] K8s yaml
  - [ ] Disjoint Resolver - Knative Service
    - [ ] Terraform
    - [ ] K8s yaml

## Prototype

### Services
- [ ] Subgraph Ingester
  - [x] REST
  - [x] gRPC
- [ ] Entity Registry
  - without caching
- [ ] Graph Mutator
  - without caching

### Infrastructure
- [ ] Knative Serving
  - [x] Terraform
  - [x] K8s
  - [ ] sslip.io dns
- [ ] Knative Eventing
  - [x] Terraform
  - [x] K8s
  - [ ] Kafka Broker
- [ ] Megamind
  - [ ] Subgraph Ingester - Knative Service
    - [ ] Terraform
    - [ ] K8s yaml
  - [ ] Entity Registry - Knative Service
    - [ ] Terraform
    - [ ] K8s yaml
  - [ ] Graph Mutator - Knative Service
    - [ ] Terraform
    - [ ] K8s yaml

### Database Support
- [ ] Neo4j