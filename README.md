# 🚀 SynergyChat — Kubernetes Deployment

Welcome to the Kubernetes deployment of **SynergyChat**, a multi-service application composed of a web frontend, API backend, and distributed crawler — fully containerized and orchestrated with Kubernetes.

This project demonstrates real-world Kubernetes architecture using Deployments, Services, ConfigMaps, Persistent Volumes, and the Gateway API.

---

# 💬 What is SynergyChat?

SynergyChat is a real-time chat app with a built-in book data crawler. Users pick a username and send messages in a shared chat. The interesting part is the `/stats` command — it lets you query emotion keyword frequency across a library of crawled books in real time.

The crawler runs in the background continuously scraping book data and indexing occurrences of emotion keywords like `love`, `hate`, `joy`, `sadness`, `anger`, `disgust`, `fear`, and `surprise`.

---

# 🖥️ Using the App

Once deployed, open your browser and navigate to:

```
http://synchat.internal
```

### 1. Set a username

Type a username in the top input field and start chatting.

### 2. Send messages

Type anything in the message box and hit **Send** to chat.

### 3. Query book stats with `/stats`

Use the `/stats` command to query keyword data from crawled books. The `crawler-bot` will respond with results.

| Command | Description |
|---|---|
| `/stats` | Summary of all keywords across all books |
| `/stats keywords=love` | Occurrences of "love" across all books |
| `/stats keywords=love,hate` | Occurrences of both "love" and "hate" |
| `/stats title=Frankenstein` | All keywords in the book "Frankenstein" |
| `/stats keywords=love,hate title=Frankenstein` | "love" and "hate" in "Frankenstein" only |

> **Note:** The crawler needs time to index books after first deployment. If `/stats` returns 0 matches, wait a few minutes and try again.

---

# ⚙️ Prerequisites

Before running this project you need the following installed:

| Tool | Install Guide |
|---|---|
| Docker | https://docs.docker.com/engine/install/ |
| Minikube | https://minikube.sigs.k8s.io/docs/start/ |
| kubectl | https://kubernetes.io/docs/tasks/tools/ |

---

# 🛠️ Deployment Steps

## 1️⃣ Quick Start (Recommended)

Clone the repo and run following cmds:

```bash
cd kubectl
make run
```

When the script pauses and prompts you, open a **new terminal** and run:

```bash
minikube tunnel
```

The script will detect the tunnel and continue automatically.

If you would like to remove everything:

```bash
make clean
```

---

## 2️⃣ Manual Setup

### Start Kubernetes

```bash
minikube start --driver=docker
```

### Start the tunnel

In a separate terminal:

```bash
minikube tunnel
```

### Apply Manifests

Manifests are organised into subdirectories and should be applied in dependency order:

```bash
# 1. Gateway infrastructure first
kubectl apply -f manifests/gateway/

# 2. Backend services
kubectl apply -f manifests/api/
kubectl apply -f manifests/crawler/

# 3. Frontend
kubectl apply -f manifests/web/
```

Or apply everything at once (order not guaranteed):

```bash
kubectl apply -f manifests/
```

---

# 📁 Project Structure

```
.
├── manifests/
│   ├── gateway/
│   │   ├── app-gatewayclass.yaml
│   │   ├── app-gateway.yaml
│   │   ├── api-httproute.yaml
│   │   └── web-httproute.yaml
│   ├── api/
│   │   ├── api-configmap.yaml
│   │   ├── api-deployment.yaml
│   │   ├── api-service.yaml
│   │   └── api-pvc.yaml
│   ├── crawler/
│   │   ├── crawler-configmap.yaml
│   │   ├── crawler-deployment.yaml
│   │   └── crawler-service.yaml
│   └── web/
│       ├── synchat-web-config.yaml
│       ├── web-deployment.yaml
│       └── web-service.yaml
├── scripts/
│   └── bootstrap.sh
├── Makefile
└── README.md
```

Manifests are grouped by service and applied in dependency order (gateway → api → crawler → web) to ensure Gateway resources exist before the HTTPRoutes that reference them.

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

```
Client → Gateway → HTTPRoute → Service → Pod
```

This approach provides:

* Clear separation of concerns
* Explicit routing rules
* Production-style network design

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

## Why Organise Manifests into Subdirectories?

Grouping manifests by service makes the project easier to navigate and enables targeted `kubectl apply` calls per service. It also maps cleanly onto a Kustomize structure if the project grows to need it.

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
- [x] Idempotent bootstrap scripting

---

# 🚀 Production Considerations

If this were deployed in a production environment:

* Crawler workers would likely be separate Pods
* Work distribution might use a message queue
* Horizontal Pod Autoscaling would be implemented
* Liveness and readiness probes would be added
* Resource requests and limits would be enforced
* Observability (metrics + logging) would be configured
* Manifests would be managed with Helm or Kustomize

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