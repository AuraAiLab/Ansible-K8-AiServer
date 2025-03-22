# Directory Structure and Deployment Components

## System Directories
- `/etc/containerd/` - Contains containerd configuration files including `config.toml`
- `/etc/kubernetes/` - Kubernetes configuration directory
- `/etc/apt/keyrings/` - Contains repository signing keys
- `/etc/cni/net.d/` - CNI plugin configuration directory

## User Directories
- `/root/.kube/` - Kubernetes configuration for root user (contains `config` file)
- `$HOME/.kube/` - Kubernetes configuration for regular users

## Data and Application Directories
- `/models/` - Parent directory for model storage
  - `/models/triton/model_repo/` - Storage location for Triton Inference Server models
  - `/models/ollama/` - Storage location for Ollama LLM models

## Kubernetes Components
The deployment sets up these logical components (not necessarily directories):
- Kubernetes control plane (running in containers/pods)
- MetalLB load balancer
- Calico CNI network plugin
- Kubernetes Dashboard
- Prometheus & Grafana monitoring stack
- NVIDIA GPU Operator
- Triton Inference Server
- Ollama LLM platform

## Namespaces in Kubernetes
The deployment creates several Kubernetes namespaces:
- `monitoring` - For Prometheus and Grafana
- `gpu-operator` - For NVIDIA GPU Operator
- `ollama` - For Ollama LLM platform
- `triton-inference` - For Triton Inference Server
- `openwebui` - For OpenWebUI
