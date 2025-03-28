# Kubernetes Ansible Deployment Project

## Overview

This project provides a comprehensive suite of Ansible playbooks for deploying and managing a production-ready Kubernetes cluster with a focus on AI/ML workloads. The automation handles everything from initial system preparation to the deployment of advanced components like MetalLB, monitoring tools, and AI infrastructure.

## Architecture

The deployment creates a fully-functional Kubernetes cluster with the following architecture:

```
┌──────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                      │
│                                                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐ │
│  │ Control     │     │ MetalLB     │     │ Monitoring  │ │
│  │ Plane       │     │ Load        │     │ Stack       │ │
│  │ Components  │     │ Balancer    │     │             │ │
│  └─────────────┘     └─────────────┘     └─────────────┘ │
│                                                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐ │
│  │ Calico      │     │ Kubernetes  │     │ NVIDIA      │ │
│  │ Network     │     │ Dashboard   │     │ GPU         │ │
│  │ Plugin      │     │             │     │ Operator    │ │
│  └─────────────┘     └─────────────┘     └─────────────┘ │
│                                                          │
│  ┌─────────────┐     ┌─────────────┐                     │
│  │ Triton      │     │ Ollama      │                     │
│  │ Inference   │     │ LLM         │                     │
│  │ Server      │     │ Platform    │                     │
│  └─────────────┘     └─────────────┘                     │
└──────────────────────────────────────────────────────────┘
```

## Components Installed

| Component | Version | Description |
|-----------|---------|-------------|
| Kubernetes | v1.32.3 | Container orchestration platform |
| containerd | Latest | Container runtime |
| Calico CNI | v3.26.1 | Network plugin for pod networking |
| MetalLB | v0.13.12 | Load balancer for bare-metal clusters |
| Kubernetes Dashboard | v2.7.0 | Web UI for cluster management |
| Prometheus & Grafana | Latest | Monitoring and visualization |
| NVIDIA GPU Operator | Latest | GPU support for AI/ML workloads |
| Triton Inference Server | Latest | Model serving platform |
| Ollama | Latest | LLM serving platform |

## Prerequisites

- One or more machines running Ubuntu 20.04 or newer
- SSH access to all target servers with sudo privileges
- Minimum hardware requirements:
  - 2 CPUs
  - 4GB RAM
  - 40GB disk space
  - (Optional) NVIDIA GPU for AI/ML workloads

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/k8-ansible.git
   cd k8-ansible
   ```

2. Update the inventory file with your server details:
   ```bash
   vi playbooks/inventory
   ```

3. Run the deployment:
   ```bash
   ansible-playbook -i playbooks/inventory playbooks/k8-final2.yml
   ```

## Detailed Documentation

- [Installation Guide](docs/installation-guide.md): Complete step-by-step installation instructions
- [Troubleshooting Guide](docs/troubleshooting/README.md): Solutions for common issues
- [Configuration Examples](docs/examples/README.md): Example configuration files for various scenarios
- [Issues and Fixes](ISSUES.md): Documented issues and their resolutions

## Project Structure

```
k8-ansible/
├── README.md                 # This file
├── ISSUES.md                 # Known issues and their fixes
├── ansible.cfg               # Ansible configuration
├── playbooks/                # Ansible playbooks
│   ├── k8-final2.yml         # Main Kubernetes installation playbook
│   ├── common_vars.yml       # Common variables
│   └── inventory             # Inventory file
├── docs/                     # Documentation
│   ├── installation-guide.md # Installation guide
│   ├── troubleshooting/      # Troubleshooting guides
│   ├── examples/             # Configuration examples
│   └── images/               # Documentation images
├── scripts/                  # Helper scripts
│   ├── cluster-setup.sh      # Cluster setup script
│   ├── reset-cluster.sh      # Cluster reset script
│   └── verify-installation.sh # Verification script
├── ansible-roles/            # Custom Ansible roles
└── config-examples/          # Example configuration files
    ├── metallb/              # MetalLB configuration
    └── monitoring/           # Monitoring configuration
```

## Monitoring

The main branch includes a basic Prometheus and Grafana installation for monitoring your Kubernetes cluster.

For advanced monitoring capabilities, including:
- Persistent storage for long-term metrics retention
- GPU monitoring via DCGM exporter
- Customized Grafana dashboards
- Detailed monitoring configuration options

Check out the `feature/enhanced-monitoring` branch:
```bash
git checkout feature/enhanced-monitoring
```

This branch includes additional playbooks and a comprehensive [monitoring guide](docs/monitoring-guide.md) for setting up a production-grade monitoring solution.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributors

- Your Name <your.email@example.com>

## Acknowledgments

- The Kubernetes community
- The Ansible community
