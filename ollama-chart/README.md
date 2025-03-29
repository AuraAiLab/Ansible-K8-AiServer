# Ollama Helm Chart

## Overview
This Helm chart deploys Ollama on a Kubernetes cluster.

## Current Configuration (Main Branch)
The current version in the main branch supports a single GPU setup. The deployment is configured to use one NVIDIA GPU (specifically targets the first GPU with CUDA_VISIBLE_DEVICES=0) for all Ollama workloads.

## Future Enhancement (Feature Branch)
The feature branch `feature/ollama-gpu-selection` supports dual GPU setups, allowing Ollama to utilize both available GPUs simultaneously. This configuration:
- Removes the CUDA_VISIBLE_DEVICES environment variable to allow access to all GPUs
- Sets the nvidia.com/gpu resource limit to 2
- Enables more efficient parallel processing for multiple Ollama workloads

## Configuration Parameters
The following table lists the configurable parameters of the Ollama chart and their default values.

| Parameter | Description | Default (Main) | Default (Feature Branch) |
|-----------|-------------|---------------|-------------------------|
| `replicaCount` | Number of replicas | `1` | `1` |
| `image.repository` | Image repository | `ollama/ollama` | `ollama/ollama` |
| `image.tag` | Image tag | `latest` | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` | `IfNotPresent` |
| `service.type` | Kubernetes Service type | `ClusterIP` | `ClusterIP` |
| `service.port` | Service port | `11434` | `11434` |
| `resources.limits.cpu` | CPU limit | `4` | `4` |
| `resources.limits.memory` | Memory limit | `16Gi` | `16Gi` |
| `resources.limits.nvidia.com/gpu` | GPU limit | `1` | `2` |
| `resources.requests.cpu` | CPU request | `1` | `1` |
| `resources.requests.memory` | Memory request | `4Gi` | `4Gi` |
| `persistence.enabled` | Enable persistence | `true` | `true` |
| `persistence.size` | PVC size | `20Gi` | `20Gi` |
| `persistence.storageClass` | Storage class for PVC | `""` | `""` |
| `namespace` | Namespace to deploy in | `ollama` | `ollama` |

## Special Configurations

### Main Branch (Single GPU)
- Uses CUDA_VISIBLE_DEVICES=0 to target only the first GPU
- Allocates 1 GPU resource limit

### Feature Branch (Dual GPU)
- Removes CUDA_VISIBLE_DEVICES to access all available GPUs
- Allocates 2 GPU resource limit for the deployment

## Installation
To install the chart:

```bash
helm install ollama ./ollama-chart
```

## Upgrading
To upgrade the release:

```bash
helm upgrade ollama ./ollama-chart
```
