# Detailed Installation Guide

This guide provides step-by-step instructions for installing a complete Kubernetes cluster using the Ansible playbooks in this repository.

## Prerequisites

1. Ensure all target machines are running Ubuntu 20.04 or newer.
2. Configure SSH access with key-based authentication.
3. Ensure the Ansible control node has network access to all target machines.

## Pre-Installation Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/k8-ansible.git
   cd k8-ansible
   ```

2. Update the inventory file:
   ```bash
   vi playbooks/inventory
   ```
   Add your servers in the appropriate groups.

3. Update common variables if needed:
   ```bash
   vi playbooks/common_vars.yml
   ```

## Running the Installation

Execute the main playbook:

```bash
cd playbooks
ansible-playbook -i inventory k8-final2.yml
```

The playbook will:
1. Install system packages and dependencies.
2. Configure containerd with the systemd cgroup driver.
3. Initialize Kubernetes with kubeadm.
4. Deploy Calico networking.
5. Install the Kubernetes Dashboard.
6. Deploy MetalLB load balancer.
7. Set up monitoring with Prometheus and Grafana.
8. Configure NVIDIA GPU support (if available).
9. Deploy Triton Inference Server and Ollama (if enabled).

## Post-Installation

After successful installation:

1. **Access the Kubernetes Dashboard**:
   ```bash
   kubectl proxy
   ```
   Then navigate to: [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)

2. **Get the MetalLB IP range**:
   ```bash
   kubectl get ipaddresspools -n metallb-system
   ```

3. **Check system pods**:
   ```bash
   kubectl get pods --all-namespaces
   ```
