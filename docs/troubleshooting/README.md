# Kubernetes Ansible Troubleshooting Guide

This comprehensive guide covers common issues you might encounter when deploying and running your Kubernetes cluster with our Ansible playbooks.

## Table of Contents

1. [Deployment Issues](#deployment-issues)
   - [Playbook Execution Failures](#playbook-execution-failures)
   - [Kubernetes Initialization Problems](#kubernetes-initialization-problems)
   - [Network Plugin Issues](#network-plugin-issues)
   
2. [Pod Scheduling Issues](#pod-scheduling-issues)
   - [Pods Stuck in Pending State](#pods-stuck-in-pending-state)
   - [Node Taints and Tolerations](#node-taints-and-tolerations)
   
3. [Networking Problems](#networking-problems)
   - [Pod-to-Pod Communication](#pod-to-pod-communication)
   - [Service Discovery Issues](#service-discovery-issues)
   - [Load Balancer Configuration](#load-balancer-configuration)
   
4. [Resource Issues](#resource-issues)
   - [CPU and Memory Constraints](#cpu-and-memory-constraints)
   - [Storage Problems](#storage-problems)
   
5. [Component-Specific Troubleshooting](#component-specific-troubleshooting)
   - [Dashboard Access Issues](#dashboard-access-issues)
   - [MetalLB Configuration](#metallb-configuration)
   - [Monitoring Stack Issues](#monitoring-stack-issues)
   - [GPU Operator Problems](#gpu-operator-problems)

## Deployment Issues

### Playbook Execution Failures

**Symptom**: Ansible playbook fails during execution with various errors.

**Common Causes and Solutions**:

1. **SSH Connectivity Issues**
   - **Symptoms**: `Unreachable` errors in Ansible output
   - **Fix**: 
     ```bash
     # Test SSH connectivity
     ssh -i /path/to/private_key user@target_host
     
     # Ensure hosts are correctly defined in inventory
     cat playbooks/inventory
     ```

2. **Insufficient Permissions**
   - **Symptoms**: Permission denied errors
   - **Fix**: Ensure the user specified in the inventory has sudo privileges
     ```yaml
     # Example inventory with sudo privileges
     [k8s_master]
     master ansible_host=192.168.1.10 ansible_user=ubuntu ansible_ssh_private_key_file=/path/to/key.pem
     ```

3. **Syntax Errors in Playbooks**
   - **Symptoms**: `yaml.parser.ParserError` or similar
   - **Fix**: Validate YAML syntax
     ```bash
     ansible-playbook --syntax-check playbooks/k8-final2.yml
     ```

### Kubernetes Initialization Problems

**Symptom**: `kubeadm init` fails during the playbook execution.

**Common Causes and Solutions**:

1. **Container Runtime Issues**
   - **Symptoms**: Errors about containerd or Docker not running
   - **Fix**: 
     ```bash
     # Check container runtime status
     systemctl status containerd
     
     # Restart if needed
     systemctl restart containerd
     ```

2. **Incorrect Kubernetes Version**
   - **Symptoms**: Package conflicts or "unable to find package" errors
   - **Fix**: Ensure specified Kubernetes version exists in repositories
     ```bash
     # Check available versions
     apt-cache policy kubelet
     
     # Update common_vars.yml with correct version
     vim playbooks/common_vars.yml
     ```

3. **Swap Enabled**
   - **Symptoms**: Error about swap being enabled
   - **Fix**: Ensure swap is disabled
     ```bash
     # Check swap status
     swapon --show
     
     # Disable swap
     swapoff -a
     
     # Prevent swap at boot in /etc/fstab
     ```

### Network Plugin Issues

**Symptom**: Calico or other network plugins not initializing properly.

**Common Causes and Solutions**:

1. **Missing Network Requirements**
   - **Symptoms**: Pods can't communicate, network plugin fails to start
   - **Fix**: Ensure bridge networking is enabled:
     ```bash
     # Load bridge module
     modprobe bridge
     
     # Verify bridge settings
     sysctl net.bridge.bridge-nf-call-iptables
     sysctl net.bridge.bridge-nf-call-ip6tables
     ```

2. **Incorrect CIDR Configuration**
   - **Symptoms**: Calico pods fail to initialize
   - **Fix**: Ensure the pod CIDR range is correctly configured:
     ```bash
     # Check current configuration
     kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
     
     # Ensure your Calico configuration matches this range
     ```

## Pod Scheduling Issues

### Pods Stuck in Pending State

**Symptom**: Pods remain in `Pending` state after deployment.

**Causes and Solutions**:

1. **Insufficient Resources**
   - **Symptoms**: Events show insufficient CPU, memory, or other resources
   - **Fix**: Check node resources and pod requests
     ```bash
     # Check node capacity
     kubectl describe nodes
     
     # Check pod requests
     kubectl describe pod <pod-name>
     ```

2. **Missing Persistent Volumes**
   - **Symptoms**: Events show waiting for a PersistentVolume
   - **Fix**: Provision the required storage resources
     ```bash
     # Check PVC status
     kubectl get pvc
     
     # Create the required PV if needed
     ```

### Node Taints and Tolerations

**Symptom**: Pods don't get scheduled on certain nodes.

**Causes and Solutions**:

1. **Node Taints Blocking Scheduling**
   - **Symptoms**: Events show "no nodes available to schedule pods"
   - **Fix**: Check for taints and add required tolerations
     ```bash
     # Check node taints
     kubectl describe nodes | grep Taint
     
     # Example of adding tolerations to a deployment
     kubectl patch deployment <deployment-name> --patch '{
       "spec": {
         "template": {
           "spec": {
             "tolerations": [
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

## Networking Problems

### Pod-to-Pod Communication

**Symptom**: Pods cannot communicate with each other.

**Causes and Solutions**:

1. **CNI Plugin Issues**
   - **Symptoms**: Network plugin pods not running or failing
   - **Fix**: Check the status of Calico (or other CNI) pods
     ```bash
     # Check Calico pods
     kubectl get pods -n kube-system -l k8s-app=calico-node
     
     # Look at Calico logs
     kubectl logs -n kube-system <calico-pod-name>
     ```

2. **Network Policy Restrictions**
   - **Symptoms**: Communication blocked even with healthy CNI
   - **Fix**: Check for restrictive NetworkPolicies
     ```bash
     # List network policies
     kubectl get networkpolicies --all-namespaces
     
     # Create an allowing policy if needed
     ```

### Service Discovery Issues

**Symptom**: Services cannot be discovered by DNS name.

**Causes and Solutions**:

1. **CoreDNS Issues**
   - **Symptoms**: DNS queries failing
   - **Fix**: Check CoreDNS deployment
     ```bash
     # Check CoreDNS pods
     kubectl get pods -n kube-system -l k8s-app=kube-dns
     
     # Check CoreDNS logs
     kubectl logs -n kube-system -l k8s-app=kube-dns
     
     # Verify CoreDNS configuration
     kubectl get configmap -n kube-system coredns -o yaml
     ```

### Load Balancer Configuration

**Symptom**: MetalLB does not assign external IPs to LoadBalancer services.

**Causes and Solutions**:

1. **MetalLB Not Running**
   - **Symptoms**: LoadBalancer services stuck in "pending" external IP
   - **Fix**: Check MetalLB deployment
     ```bash
     # Check MetalLB pods
     kubectl get pods -n metallb-system
     
     # Check logs for controller
     kubectl logs -n metallb-system -l app=metallb,component=controller
     ```

2. **Incorrect IP Pool Configuration**
   - **Symptoms**: No IPs assigned even with healthy pods
   - **Fix**: Verify the IP address pool configuration
     ```bash
     # Check IP address pools
     kubectl get ipaddresspools -n metallb-system
     
     # Check L2Advertisement
     kubectl get l2advertisements -n metallb-system
     
     # Example of correctly configured IP pool:
     cat <<EOF | kubectl apply -f -
     apiVersion: metallb.io/v1beta1
     kind: IPAddressPool
     metadata:
       name: default-pool
       namespace: metallb-system
     spec:
       addresses:
       - 192.168.20.20-192.168.20.24
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
     ```

## Resource Issues

### CPU and Memory Constraints

**Symptom**: Pods fail to start or get evicted due to resource constraints.

**Causes and Solutions**:

1. **Resource Limits Too Low or Too High**
   - **Symptoms**: Out of memory errors or CPU throttling
   - **Fix**: Adjust resource requests and limits
     ```bash
     # Check current pod resource settings
     kubectl describe pod <pod-name> | grep -A 3 "Limits:" -A 6 "Requests:"
     
     # Edit deployment resources
     kubectl edit deployment <deployment-name>
     ```

### Storage Problems

**Symptom**: Pods with PersistentVolumeClaims can't start.

**Causes and Solutions**:

1. **Missing Storage Class or Provisioner**
   - **Symptoms**: PVCs stuck in Pending state
   - **Fix**: Check storage classes and create them if missing
     ```bash
     # Check storage classes
     kubectl get storageclasses
     
     # Create a default storage class if needed
     ```

## Component-Specific Troubleshooting

### Dashboard Access Issues

**Symptom**: Cannot access the Kubernetes Dashboard.

**Causes and Solutions**:

1. **Dashboard Pod Not Running**
   - **Symptoms**: Dashboard pod not in Running state
   - **Fix**: Check pod status and add tolerations if needed
     ```bash
     # Check dashboard pod
     kubectl get pods -n kubernetes-dashboard
     
     # Apply tolerations patch (for master nodes)
     kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard --patch '{
       "spec": {
         "template": {
           "spec": {
             "tolerations": [
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

2. **Authentication Issues**
   - **Symptoms**: Access denied when trying to view dashboard
   - **Fix**: Create a service account with appropriate permissions
     ```bash
     # Create admin service account
     kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
     
     # Create cluster role binding
     kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin
     
     # Get token for login
     kubectl -n kubernetes-dashboard create token dashboard-admin
     ```

### MetalLB Configuration

**Symptom**: MetalLB not assigning IPs to LoadBalancer services.

**Causes and Solutions**:

1. **IP Range Conflicts**
   - **Symptoms**: IPs not assigned or conflicts with other network devices
   - **Fix**: Ensure IP range is available on your network
     ```bash
     # Check current IP range
     kubectl get ipaddresspools -n metallb-system -o jsonpath='{.items[0].spec.addresses}'
     
     # Update if needed with a new range
     kubectl edit ipaddresspool -n metallb-system default-pool
     ```

### Monitoring Stack Issues

**Symptom**: Prometheus or Grafana not working correctly.

**Causes and Solutions**:

1. **Pod Resource Constraints**
   - **Symptoms**: Monitoring pods crashing or restarting
   - **Fix**: Increase resource limits
     ```bash
     # Check monitoring pods
     kubectl get pods -n monitoring
     
     # Edit resource allocation
     kubectl -n monitoring edit deployment prometheus-server
     ```

2. **Storage Issues**
   - **Symptoms**: Prometheus complaining about storage
   - **Fix**: Ensure PVCs are correctly provisioned
     ```bash
     # Check PVCs in monitoring namespace
     kubectl get pvc -n monitoring
     ```

### GPU Operator Problems

**Symptom**: GPU operator not deploying correctly or GPUs not available to pods.

**Causes and Solutions**:

1. **Driver Compatibility Issues**
   - **Symptoms**: GPU operator pods failing
   - **Fix**: Ensure compatible driver version
     ```bash
     # Check GPU operator pods
     kubectl get pods -n gpu-operator-resources
     
     # Check driver logs
     kubectl logs -n gpu-operator-resources <driver-pod>
     ```

2. **Driver Installation Failures**
   - **Symptoms**: Driver pods failing to install
   - **Fix**: Verify kernel headers are available
     ```bash
     # Install kernel headers on the host
     apt-get install linux-headers-$(uname -r)
     
     # Restart operator pods
     kubectl delete pod -n gpu-operator <operator-pod>
     ```

For any issues not covered in this guide, please check the [official Kubernetes troubleshooting documentation](https://kubernetes.io/docs/tasks/debug/) or open an issue in the GitHub repository.
