# Ansible Playbook Explanation

This document provides a comprehensive explanation of how the Kubernetes Ansible playbook (`k8-final2.yml`) works, breaking down each section, task, and explaining the overall flow of the installation process.

## Table of Contents

1. [Overview](#overview)
2. [Playbook Structure](#playbook-structure)
3. [Pre-Installation Setup](#pre-installation-setup)
4. [Kubernetes Installation](#kubernetes-installation)
5. [Container Runtime Configuration](#container-runtime-configuration)
6. [Kubeadm Initialization](#kubeadm-initialization)
7. [Network Plugin Deployment](#network-plugin-deployment)
8. [Dashboard Installation](#dashboard-installation)
9. [MetalLB Deployment](#metallb-deployment)
10. [Monitoring Setup](#monitoring-setup)
11. [GPU Support](#gpu-support)
12. [AI/ML Infrastructure](#aiml-infrastructure)
13. [Post-Installation Tasks](#post-installation-tasks)
14. [Customization Points](#customization-points)

## Overview

The main playbook (`k8-final2.yml`) automates the entire process of setting up a Kubernetes cluster, from installing necessary packages to deploying advanced components like MetalLB, monitoring tools, and AI/ML infrastructure. It is designed to work on Ubuntu hosts and provides a complete, production-ready Kubernetes environment.

## Playbook Structure

The playbook is organized into logical sections:

```yaml
- hosts: all
  become: yes
  vars_files:
    - common_vars.yml
  vars:
    kube_version: "1.32.3-1.1"
    cni_plugin: "calico"
    cni_version: "v3.26.1"
    # ... other variables ...
  tasks:
    # System preparation tasks
    # ...
    
    # Kubernetes installation tasks
    # ...
    
    # Container runtime configuration
    # ...
    
    # Cluster initialization tasks for master node
    # ...
    
    # Worker node join tasks
    # ...
    
    # Additional components installation
    # ...
  
  handlers:
    # Handlers for service restarts
    # ...
```

### Variables

The playbook uses a combination of inline variables and external variable files (`common_vars.yml`). Key variables include:

- `kube_version`: Kubernetes version to install
- `cni_plugin`: Container Network Interface to use (Calico)
- `metallb_version`: MetalLB load balancer version
- `metallb_ip_range`: IP range for MetalLB to allocate
- `dashboard_version`: Kubernetes Dashboard version
- Various namespace definitions for components

## Pre-Installation Setup

### System Packages

The playbook starts by updating the system and installing essential packages:

```yaml
- name: Update and upgrade apt packages
  apt:
    update_cache: yes
    upgrade: yes
    cache_valid_time: 3600

- name: Install essential system packages
  apt:
    name:
      - curl
      - git
      - build-essential
      - nfs-common
      # ... other packages ...
    state: present
```

### Kernel Modules and System Settings

The playbook loads necessary kernel modules and configures system settings required for Kubernetes:

```yaml
- name: Load required kernel modules
  shell: "modprobe {{ item }}"
  with_items:
    - br_netfilter
    - overlay
    - bridge

- name: Configure kernel parameters for Kubernetes
  sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
    sysfs: yes
  with_items:
    - { key: "net.bridge.bridge-nf-call-iptables", value: "1" }
    - { key: "net.bridge.bridge-nf-call-ip6tables", value: "1" }
    - { key: "net.ipv4.ip_forward", value: "1" }
```

### Swap Disabling

Kubernetes requires swap to be disabled:

```yaml
- name: Disable swap
  shell: swapoff -a
  changed_when: false

- name: Remove swap from fstab
  lineinfile:
    path: /etc/fstab
    regexp: '^([^#].*?\sswap\s+sw\s+.*)$'
    line: '# \1'
    backrefs: yes
  register: swap_disabled
```

## Kubernetes Installation

### APT Repository Setup

The playbook sets up the Kubernetes APT repository:

```yaml
- name: Add Kubernetes apt key
  apt_key:
    url: https://packages.cloud.google.com/apt/doc/apt-key.gpg
    state: present

- name: Add Kubernetes apt repository
  apt_repository:
    repo: deb https://apt.kubernetes.io/ kubernetes-xenial main
    state: present
    filename: kubernetes
```

### Package Installation

Kubernetes components are installed with specific versions:

```yaml
- name: Install Kubernetes components
  apt:
    name:
      - kubelet={{ kube_version }}
      - kubeadm={{ kube_version }}
      - kubectl={{ kube_version }}
    state: present
  environment:
    DEBIAN_FRONTEND: noninteractive
```

## Container Runtime Configuration

### Containerd Setup

The playbook configures containerd, the container runtime:

```yaml
- name: Create containerd configuration directory
  file:
    path: "{{ containerd_config_dir }}"
    state: directory
    mode: '0755'

- name: Generate containerd configuration
  shell: |
    containerd config default > {{ containerd_config_dir }}/config.toml
  args:
    creates: "{{ containerd_config_dir }}/config.toml"

- name: Configure containerd to use systemd cgroup driver
  replace:
    path: "{{ containerd_config_dir }}/config.toml"
    regexp: 'SystemdCgroup = false'
    replace: 'SystemdCgroup = true'
  notify: Restart containerd
```

## Kubeadm Initialization

### Master Node Setup

On the designated master node, the playbook initializes the Kubernetes control plane:

```yaml
- name: Initialize Kubernetes control plane with kubeadm
  shell: |
    kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version={{ kube_version | regex_replace('-.*$', '') }}
  args:
    creates: /etc/kubernetes/admin.conf
  register: kubeadm_init
  when: inventory_hostname in groups['k8s_master'] | default([])
```

### Kubeconfig Setup

The playbook sets up the kubeconfig file for cluster access:

```yaml
- name: Create .kube directory for root user
  file:
    path: /root/.kube
    state: directory
    mode: '0755'
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Copy admin kubeconfig for root user
  copy:
    src: /etc/kubernetes/admin.conf
    dest: /root/.kube/config
    remote_src: yes
    owner: root
    mode: '0644'
  when: inventory_hostname in groups['k8s_master'] | default([])
```

### Worker Node Join

Worker nodes are joined to the cluster using the token generated during initialization:

```yaml
- name: Get join command from master
  shell: kubeadm token create --print-join-command
  register: join_command
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Join worker nodes to the cluster
  shell: "{{ hostvars[groups['k8s_master'][0]]['join_command']['stdout'] }}"
  args:
    creates: /etc/kubernetes/kubelet.conf
  when: inventory_hostname in groups['k8s_workers'] | default([])
```

## Network Plugin Deployment

### Calico CNI

The playbook deploys Calico as the CNI solution:

```yaml
- name: Apply Calico CNI
  shell: |
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/{{ cni_version }}/manifests/calico.yaml
  when: inventory_hostname in groups['k8s_master'] | default([]) and cni_plugin == 'calico'
```

## Dashboard Installation

The playbook deploys the Kubernetes Dashboard:

```yaml
- name: Deploy Kubernetes Dashboard
  shell: |
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/{{ dashboard_version }}/aio/deploy/recommended.yaml
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Apply dashboard tolerations
  shell: |
    kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard --patch '{
      "spec": {
        "template": {
          "spec": {
            "tolerations": [
              {
                "key": "node-role.kubernetes.io/control-plane",
                "operator": "Exists",
                "effect": "NoSchedule"
              },
              {
                "key": "node-role.kubernetes.io/master",
                "operator": "Exists",
                "effect": "NoSchedule"
              }
            ]
          }
        }
      }
    }'
  when: inventory_hostname in groups['k8s_master'] | default([])
```

## MetalLB Deployment

The playbook installs and configures MetalLB for load balancing:

```yaml
- name: Direct installation of kubectl and MetalLB
  shell: |
    # Direct kubectl installation
    echo "Downloading and installing kubectl..."
    cd /tmp
    curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
    chmod +x kubectl
    cp kubectl /usr/local/bin/kubectl
    
    # Install MetalLB
    echo "Installing MetalLB..."
    export KUBECONFIG=/etc/kubernetes/admin.conf
    /usr/local/bin/kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/{{ metallb_version }}/config/manifests/metallb-native.yaml
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Configure MetalLB
  shell: |
    cat <<EOF | kubectl apply -f -
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: default-pool
      namespace: metallb-system
    spec:
      addresses:
      - {{ metallb_ip_range }}
    ---
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: l2-advert
      namespace: metallb-system
    spec:
      ipAddressPools:
      - default-pool
    EOF
  when: inventory_hostname in groups['k8s_master'] | default([])
```

## Monitoring Setup

### Prometheus and Grafana

The playbook sets up a monitoring stack with Prometheus and Grafana:

```yaml
- name: Create monitoring namespace
  shell: |
    kubectl create namespace {{ monitoring_namespace }} --dry-run=client -o yaml | kubectl apply -f -
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Deploy Prometheus and Grafana stack
  shell: |
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/0namespace.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/0crds.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/
  when: inventory_hostname in groups['k8s_master'] | default([])
```

## GPU Support

For systems with NVIDIA GPUs, the playbook deploys the NVIDIA GPU Operator:

```yaml
- name: Create GPU operator namespace
  shell: |
    kubectl create namespace {{ gpu_operator_namespace }} --dry-run=client -o yaml | kubectl apply -f -
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Add NVIDIA Helm repository
  shell: |
    helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
    helm repo update
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Install NVIDIA GPU Operator
  shell: |
    helm install --wait --generate-name -n {{ gpu_operator_namespace }} nvidia/gpu-operator
  when: inventory_hostname in groups['k8s_master'] | default([])
```

## AI/ML Infrastructure

### Triton Inference Server and Ollama

The playbook deploys AI/ML infrastructure components like NVIDIA Triton Inference Server and Ollama:

```yaml
- name: Create Triton Inference Server namespace
  shell: |
    kubectl create namespace {{ triton_namespace }} --dry-run=client -o yaml | kubectl apply -f -
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Deploy Triton Inference Server
  shell: |
    cat <<EOF | kubectl apply -f -
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: triton-inference-server
      namespace: {{ triton_namespace }}
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: triton-inference-server
      template:
        metadata:
          labels:
            app: triton-inference-server
        spec:
          containers:
          - name: triton-inference-server
            image: nvcr.io/nvidia/tritonserver:23.04-py3
            ports:
            - containerPort: 8000
              name: http
            - containerPort: 8001
              name: grpc
            - containerPort: 8002
              name: metrics
            resources:
              limits:
                nvidia.com/gpu: 1
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: triton-inference-server
      namespace: {{ triton_namespace }}
    spec:
      type: LoadBalancer
      ports:
      - port: 8000
        targetPort: 8000
        name: http-inference
      - port: 8001
        targetPort: 8001
        name: grpc-inference
      - port: 8002
        targetPort: 8002
        name: http-metrics
      selector:
        app: triton-inference-server
    EOF
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Create Ollama namespace
  shell: |
    kubectl create namespace {{ ollama_namespace }} --dry-run=client -o yaml | kubectl apply -f -
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Deploy Ollama
  shell: |
    cat <<EOF | kubectl apply -f -
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ollama
      namespace: {{ ollama_namespace }}
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: ollama
      template:
        metadata:
          labels:
            app: ollama
        spec:
          containers:
          - name: ollama
            image: ollama/ollama:latest
            ports:
            - containerPort: 11434
            env:
            - name: OLLAMA_HOST
              value: "0.0.0.0"
            resources:
              requests:
                memory: "4Gi"
                cpu: "2"
              limits:
                memory: "8Gi"
                cpu: "4"
                nvidia.com/gpu: 1
            volumeMounts:
            - name: ollama-data
              mountPath: /root/.ollama
          volumes:
          - name: ollama-data
            emptyDir: {}
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: ollama
      namespace: {{ ollama_namespace }}
    spec:
      type: LoadBalancer
      ports:
      - port: 11434
        targetPort: 11434
      selector:
        app: ollama
    EOF
  when: inventory_hostname in groups['k8s_master'] | default([])
```

## Post-Installation Tasks

The playbook performs several post-installation tasks, including:

```yaml
- name: Wait for node to be ready
  shell: |
    kubectl wait --for=condition=Ready node --all --timeout=300s
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Display cluster information
  shell: |
    echo "===== Kubernetes Cluster Information ====="
    echo "Kubernetes version:"
    kubectl version --short
    echo ""
    echo "Node status:"
    kubectl get nodes -o wide
    echo ""
    echo "Pod status:"
    kubectl get pods --all-namespaces -o wide
    echo ""
    echo "Service status:"
    kubectl get services --all-namespaces
    echo ""
    echo "Access the Kubernetes Dashboard at:"
    echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    echo "Use 'kubectl proxy' to enable access"
    echo "=========================================="
  register: cluster_info
  when: inventory_hostname in groups['k8s_master'] | default([])

- name: Show cluster information
  debug:
    var: cluster_info.stdout_lines
  when: inventory_hostname in groups['k8s_master'] | default([]) and cluster_info is defined
```

## Customization Points

The playbook offers several points for customization:

1. **Variable Definitions**: Edit `common_vars.yml` to change versions, IP ranges, and other parameters
2. **Component Selection**: Comment out or modify sections for specific components (e.g., GPU Operator, Ollama)
3. **Runtime Configuration**: Containerd configuration can be customized
4. **Additional Components**: Add more components by creating new tasks

To customize the playbook:

1. Identify the variables that control the behavior you want to modify
2. Edit `common_vars.yml` or the inline variables in the playbook
3. Add or modify tasks to deploy additional components
4. Test your changes in a development environment before applying to production

## Conclusion

This Ansible playbook provides a comprehensive solution for deploying a Kubernetes cluster with all necessary components for modern cloud-native applications, including specialized infrastructure for AI/ML workloads. By understanding how each section works, you can customize the deployment to fit your specific requirements.

For more information on specific components:
- Kubernetes Dashboard: [docs/component-guides/kubernetes-dashboard.md](component-guides/kubernetes-dashboard.md)
- MetalLB: [docs/component-guides/metallb.md](component-guides/metallb.md)
- Troubleshooting: [docs/troubleshooting/README.md](troubleshooting/README.md)
- Configuration Examples: [docs/examples/README.md](examples/README.md)
