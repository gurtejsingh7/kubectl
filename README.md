# 🚀 SynergyChat — Kubernetes Deployment

Welcome to the Kubernetes deployment of **SynergyChat**, a multi-service application composed of a web frontend, API backend, and distributed crawler — fully containerized and orchestrated with Kubernetes.

This project demonstrates real-world Kubernetes architecture using Deployments, Services, ConfigMaps, Persistent Volumes, and the Gateway API.

---

# 🧠 High-Level Architecture

The system is composed of three core services:

## 🌐 Web Frontend

* Runs as a Kubernetes Deployment
* Exposed internally via a Service
* Routed externally through HTTPRoute + Gateway
* Communicates with the API service

## 🔌 API Backend

* Runs as its own Deployment
* Exposed internally via ClusterIP Service
* Uses ConfigMaps for configuration
* Shares persistent storage with the crawler

## 🤖 Crawler Service

* Runs as a Deployment
* Contains **3 containers inside a single Pod**
* Uses a PersistentVolumeClaim (PVC)
* Crawls book data and stores results in shared storage
* Demonstrates multi-container coordination and shared volumes

---

# 🏗️ Kubernetes Resources Used

## 📦 Deployments

Manage pod lifecycle, restarts, and scaling.

* `web-deployment.yaml`
* `api-deployment.yaml`
* `crawler-deployment.yaml`

---

## 🌉 Services

Provide stable internal networking endpoints.

* `web-service.yaml`
* `api-service.yaml`
* `crawler-service.yaml`

💡 General rule followed:

* All HTTP workloads have a **Service**
* Only workloads requiring external exposure have an **HTTPRoute**

---

## ⚙️ ConfigMaps

Externalize configuration from container images.

* `api-configmap.yaml`
* `crawler-configmap.yaml`
* `synchat-web-config.yaml`

Used for:

* Environment variables
* Internal service URLs
* Runtime configuration

---

## 💾 Persistent Storage

* `api-pvc.yaml`

The crawler and API share a PersistentVolumeClaim to:

* Store database files
* Persist crawled data
* Survive pod restarts
* Simulate stateful production workloads

This ensures durability inside a containerized environment.

---

## 🌍 Gateway API (Modern Routing)

Instead of traditional Ingress, this project uses the **Gateway API**.

Resources:

* `app-gatewayclass.yaml`
* `app-gateway.yaml`
* `api-httproute.yaml`
* `web-httproute.yaml`

### Traffic Flow

Client → Gateway → HTTPRoute → Service → Pod

This approach provides:

* Clear separation of concerns
* Explicit routing rules
* Production-style network design

---

# 🛠️ Deployment Steps

## 1️⃣ Start Kubernetes

Example with Minikube:

```bash
minikube start --driver=docker --network-plugin=cni --cpus=2 --memory=4096
```

---

## 2️⃣ Apply Manifests

Apply in logical order:

```bash
kubectl apply -f app-gatewayclass.yaml
kubectl apply -f app-gateway.yaml

kubectl apply -f api-configmap.yaml
kubectl apply -f crawler-configmap.yaml
kubectl apply -f synchat-web-config.yaml

kubectl apply -f api-pvc.yaml

kubectl apply -f api-deployment.yaml
kubectl apply -f crawler-deployment.yaml
kubectl apply -f web-deployment.yaml

kubectl apply -f api-service.yaml
kubectl apply -f crawler-service.yaml
kubectl apply -f web-service.yaml

kubectl apply -f api-httproute.yaml
kubectl apply -f web-httproute.yaml
```
or simply

```bash
kubectl apply -f .
```

---

# 🏛️ Design Decisions

## Why Give Every HTTP App a Service?

Because Pods are ephemeral.

Services provide:

* Stable DNS names
* Stable IPs
* Internal load balancing

Only services that need to be accessed externally are connected to the Gateway via HTTPRoute.

---

## Why Use a PersistentVolumeClaim?

The crawler writes data to disk.

Without a PVC:

* Data would be lost on restart
* Scaling would be inconsistent
* The system would not simulate real-world stateful behavior

The PVC ensures durability and shared access between containers.

---

## Why 3 Containers in One Pod?

The crawler runs three containers inside a single Pod to:

* Share the same network namespace
* Share mounted storage
* Operate as tightly coupled workers

In production, horizontal scaling using multiple Pods is more common.
However, this design keeps the architecture simple while demonstrating shared storage and concurrency concepts.

---

# 📁 Project Structure

```
.
├── api-configmap.yaml
├── api-deployment.yaml
├── api-pvc.yaml
├── api-service.yaml
├── api-httproute.yaml
├── crawler-configmap.yaml
├── crawler-deployment.yaml
├── crawler-service.yaml
├── web-deployment.yaml
├── web-service.yaml
├── web-httproute.yaml
├── app-gateway.yaml
├── app-gatewayclass.yaml
└── README.md
```

---

# 🔍 What This Project Demonstrates

- [x] Multi-container Pods
- [x] Persistent volumes in Kubernetes
- [x] Internal service networking
- [x] Gateway API routing
- [x] ConfigMap-based configuration
- [x] Stateful workloads
- [x] Debugging container orchestration issues
- [x] Declarative infrastructure management
---

# 🚀 Production Considerations

If this were deployed in a production environment:

* Crawler workers would likely be separate Pods
* Work distribution might use a message queue
* Horizontal Pod Autoscaling would be implemented
* Liveness and readiness probes would be added
* Resource requests and limits would be enforced
* Observability (metrics + logging) would be configured

This project focuses on mastering core Kubernetes primitives before introducing distributed system complexity.

---

# 🏁 Final Thoughts

This deployment showcases:

* Clean Kubernetes architecture
* Modern routing via Gateway API
* Stateful workload handling
* Real-world debugging experience
* Declarative infrastructure management

---

🔥 Built with Kubernetes.
💡 Designed with intent.
🚀 Deployed like production.
