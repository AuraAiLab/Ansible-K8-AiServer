# Known Issues and Fixes

This document tracks issues encountered during Kubernetes deployment with the Ansible playbooks and their corresponding fixes.

## Issue 1: Kubernetes Dashboard Stuck in Pending Status

**Problem**: The Kubernetes Dashboard pod was stuck in a "Pending" state after installation.

**Cause**: The control-plane/master node has taints that prevent pods from being scheduled unless they have matching tolerations.

**Fix**: Added tolerations to the Dashboard deployment with:

```yaml
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
```

## Issue 2: MetalLB Installation Failing Due to kubectl Issues

**Problem**: The MetalLB installation task was failing because kubectl was not found or accessible.

**Cause**: The kubectl binary was either not installed or not in the expected path.

**Fix**: Added explicit installation of kubectl from the official Kubernetes repository and used the full path to kubectl in all commands:

```yaml
- name: Direct installation of kubectl and MetalLB
  shell: |
    # Direct kubectl installation
    echo "Downloading and installing kubectl..."
    cd /tmp
    curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
    chmod +x kubectl
    cp kubectl /usr/local/bin/kubectl
    
    # Verify kubectl
    echo "Verifying kubectl installation..."
    /usr/local/bin/kubectl version --client || exit 1
    
    # Install MetalLB
    echo "Installing MetalLB..."
    export KUBECONFIG=/etc/kubernetes/admin.conf
    /usr/local/bin/kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/{{ metallb_version }}/config/manifests/metallb-native.yaml
```

## Issue 3: Bridge Module Not Loaded

**Problem**: The Ansible playbook was failing when attempting to set sysctl parameters for bridge networking.

**Cause**: The bridge module was not loaded in the kernel.

**Fix**: Added tasks to load the bridge module and ensure it loads at boot:

```yaml
- name: Load bridge module
  shell: "modprobe bridge"
  changed_when: false

- name: Add bridge module to /etc/modules to load at boot
  lineinfile:
    path: /etc/modules
    line: bridge
    state: present
```
