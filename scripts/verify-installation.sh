#!/bin/bash
# Kubernetes Cluster Verification Script
# This script performs various checks to verify the health of your Kubernetes cluster

set -e

# Text formatting
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display header
function print_header() {
    echo -e "\n${BOLD}${BLUE}$1${NC}\n"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}\n"
}

# Display success message
function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Display warning message
function print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Display error message
function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if a command exists
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main header
print_header "Kubernetes Cluster Verification"
echo "This script will verify the installation and health of your Kubernetes cluster."
echo "If any issues are found, recommendations will be provided."
echo ""

# Check kubectl availability
echo "Checking kubectl availability..."
if command_exists kubectl; then
    print_success "kubectl is installed"
    kubectl_version=$(kubectl version --client -o json 2>/dev/null | grep gitVersion | head -1 | cut -d'"' -f4)
    echo "  kubectl version: $kubectl_version"
else
    print_error "kubectl is not installed or not in PATH"
    echo "  Please install kubectl or check your PATH settings"
    exit 1
fi

# Check if we can connect to the cluster
echo -e "\nChecking Kubernetes API connectivity..."
if kubectl cluster-info > /dev/null 2>&1; then
    print_success "Connected to Kubernetes API"
    cluster_info=$(kubectl cluster-info | head -1)
    echo "  $cluster_info"
else
    print_error "Cannot connect to Kubernetes API"
    echo "  Please check if the cluster is running and kubeconfig is properly set up"
    echo "  Try: export KUBECONFIG=/etc/kubernetes/admin.conf (for root user on master node)"
    exit 1
fi

# Check nodes
print_header "Node Status"
nodes=$(kubectl get nodes -o wide)
echo "$nodes"
node_count=$(echo "$nodes" | tail -n +2 | wc -l)
not_ready_count=$(echo "$nodes" | grep -v "Ready" | tail -n +2 | wc -l)

if [ $not_ready_count -eq 0 ]; then
    print_success "All $node_count nodes are in Ready state"
else
    print_error "$not_ready_count of $node_count nodes are not in Ready state"
    echo "  Please check node events and kubelet status on problem nodes:"
    echo "  1. kubectl describe node <node-name>"
    echo "  2. ssh to the node and check: systemctl status kubelet"
    echo "  3. Check kubelet logs: journalctl -xeu kubelet"
fi

# Check pods
print_header "Pod Status"
echo "Checking system pods across all namespaces..."
system_pods=$(kubectl get pods --all-namespaces -o wide)
echo "$system_pods"

# Count pods that are not Running or Completed
problem_pods_count=$(echo "$system_pods" | grep -v "Running\|Completed" | tail -n +2 | wc -l)
if [ $problem_pods_count -eq 0 ]; then
    print_success "All system pods are running correctly"
else
    print_warning "$problem_pods_count pods are not in Running or Completed state"
    echo "  Please check the problematic pods with:"
    echo "  kubectl describe pod <pod-name> -n <namespace>"
    echo "  kubectl logs <pod-name> -n <namespace>"
fi

# Check core components
print_header "Core Components Check"

# Check CNI (Calico)
echo "Checking CNI (Calico)..."
calico_pods=$(kubectl get pods -n kube-system -l k8s-app=calico-node -o wide 2>/dev/null || echo "Not found")
if echo "$calico_pods" | grep -q "Running"; then
    print_success "Calico pods are running"
else
    print_error "Calico pods are not running correctly"
    echo "  Please check Calico deployment with:"
    echo "  kubectl describe pods -n kube-system -l k8s-app=calico-node"
fi

# Check CoreDNS
echo -e "\nChecking CoreDNS..."
coredns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide 2>/dev/null || echo "Not found")
if echo "$coredns_pods" | grep -q "Running"; then
    print_success "CoreDNS pods are running"
else
    print_error "CoreDNS pods are not running correctly"
    echo "  Please check CoreDNS deployment with:"
    echo "  kubectl describe pods -n kube-system -l k8s-app=kube-dns"
fi

# Check MetalLB
echo -e "\nChecking MetalLB..."
metallb_pods=$(kubectl get pods -n metallb-system -o wide 2>/dev/null || echo "Not found")
if echo "$metallb_pods" | grep -q "Running"; then
    print_success "MetalLB pods are running"
    
    # Check MetalLB configuration
    metallb_config=$(kubectl get ipaddresspools -n metallb-system -o name 2>/dev/null || echo "Not found")
    if echo "$metallb_config" | grep -q "ipaddresspool"; then
        print_success "MetalLB IP address pool is configured"
        ip_range=$(kubectl get ipaddresspools -n metallb-system -o jsonpath='{.items[0].spec.addresses}' 2>/dev/null)
        echo "  IP range: $ip_range"
    else
        print_warning "MetalLB IP address pool is not configured"
        echo "  Please configure the IP address pool with the example in docs/examples/README.md"
    fi
else
    print_error "MetalLB pods are not running correctly or not deployed"
    echo "  Please check MetalLB deployment with:"
    echo "  kubectl get pods -n metallb-system"
    echo "  kubectl describe pods -n metallb-system"
fi

# Check Kubernetes Dashboard
echo -e "\nChecking Kubernetes Dashboard..."
dashboard_pods=$(kubectl get pods -n kubernetes-dashboard -o wide 2>/dev/null || echo "Not found")
if echo "$dashboard_pods" | grep -q "Running"; then
    print_success "Kubernetes Dashboard pods are running"
    
    # Check Dashboard accessibility
    dashboard_service=$(kubectl get svc -n kubernetes-dashboard kubernetes-dashboard -o jsonpath='{.spec.type}' 2>/dev/null || echo "Not found")
    echo "  Dashboard service type: $dashboard_service"
    echo "  Access URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
else
    print_error "Kubernetes Dashboard pods are not running correctly or not deployed"
    echo "  Please check Dashboard deployment with:"
    echo "  kubectl get pods -n kubernetes-dashboard"
    echo "  kubectl describe pods -n kubernetes-dashboard"
fi

# Check Services
print_header "Services Check"
echo "Checking for LoadBalancer services..."
lb_services=$(kubectl get svc --all-namespaces | grep LoadBalancer)
if [ -z "$lb_services" ]; then
    print_warning "No LoadBalancer services found"
    echo "  To create a test service, run:"
    echo "  kubectl create deployment nginx --image=nginx"
    echo "  kubectl expose deployment nginx --port=80 --type=LoadBalancer"
else
    echo "$lb_services"
    pending_lb=$(echo "$lb_services" | grep "<pending>" | wc -l)
    
    if [ $pending_lb -eq 0 ]; then
        print_success "All LoadBalancer services have external IPs assigned"
    else
        print_error "$pending_lb LoadBalancer services have pending external IPs"
        echo "  Please check MetalLB configuration with:"
        echo "  kubectl get ipaddresspools -n metallb-system"
        echo "  kubectl get l2advertisements -n metallb-system"
    fi
fi

# Check Storage
print_header "Storage Check"
echo "Checking storage classes..."
storage_classes=$(kubectl get storageclasses)
echo "$storage_classes"

# Check Monitoring
print_header "Monitoring Check"
echo "Checking Prometheus and Grafana..."
monitoring_ns=$(kubectl get ns monitoring 2>/dev/null || echo "not-found")
if echo "$monitoring_ns" | grep -q "monitoring"; then
    print_success "Monitoring namespace exists"
    
    # Check Prometheus
    prometheus_pods=$(kubectl get pods -n monitoring -l app=prometheus -o wide 2>/dev/null || echo "Not found")
    if echo "$prometheus_pods" | grep -q "Running"; then
        print_success "Prometheus pods are running"
    else
        print_warning "Prometheus pods are not running correctly or not deployed"
    fi
    
    # Check Grafana
    grafana_pods=$(kubectl get pods -n monitoring -l app=grafana -o wide 2>/dev/null || echo "Not found")
    if echo "$grafana_pods" | grep -q "Running"; then
        print_success "Grafana pods are running"
        grafana_svc=$(kubectl get svc -n monitoring grafana -o jsonpath='{.spec.type}' 2>/dev/null || echo "Not found")
        if [ "$grafana_svc" == "LoadBalancer" ]; then
            grafana_ip=$(kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
            echo "  Grafana is exposed via LoadBalancer at http://$grafana_ip:3000"
        else
            echo "  Grafana service type: $grafana_svc"
        fi
    else
        print_warning "Grafana pods are not running correctly or not deployed"
    fi
else
    print_warning "Monitoring namespace does not exist. Monitoring components not deployed."
    echo "  This is normal if you chose not to deploy monitoring components."
fi

# Check AI/ML components
print_header "AI/ML Components Check"

# Check NVIDIA GPU Operator
echo "Checking NVIDIA GPU Operator..."
gpu_ns=$(kubectl get ns gpu-operator 2>/dev/null || echo "not-found")
if echo "$gpu_ns" | grep -q "gpu-operator"; then
    print_success "GPU Operator namespace exists"
    
    gpu_operator_pods=$(kubectl get pods -n gpu-operator 2>/dev/null)
    if [ $? -eq 0 ]; then
        gpu_operator_status=$(kubectl get pods -n gpu-operator -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | sort | uniq -c)
        echo "  GPU Operator pod statuses: $gpu_operator_status"
        
        # Check if NVIDIA drivers are working
        nvidia_device_plugin=$(kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset 2>/dev/null || echo "Not found")
        if echo "$nvidia_device_plugin" | grep -q "Running"; then
            print_success "NVIDIA device plugin is running"
            
            # Check if GPUs are available to the cluster
            gpu_nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.nvidia\.com/gpu}' 2>/dev/null)
            if [ -n "$gpu_nodes" ] && [ "$gpu_nodes" != "0" ]; then
                print_success "GPUs are available in the cluster"
                echo "  GPU count: $gpu_nodes"
            else
                print_warning "No GPUs are detected in the cluster"
                echo "  Please check if the nodes have NVIDIA GPUs and drivers are correctly installed"
            fi
        else
            print_warning "NVIDIA device plugin is not running correctly"
        fi
    else
        print_warning "Unable to retrieve GPU Operator pods"
    fi
else
    print_warning "GPU Operator namespace does not exist. GPU components not deployed."
    echo "  This is normal if you have no GPUs or chose not to deploy GPU components."
fi

# Check Triton Inference Server and Ollama
echo -e "\nChecking AI Serving Platforms..."
triton_ns=$(kubectl get ns triton-inference 2>/dev/null || echo "not-found")
ollama_ns=$(kubectl get ns ollama 2>/dev/null || echo "not-found")

if echo "$triton_ns" | grep -q "triton-inference"; then
    print_success "Triton Inference Server namespace exists"
    
    triton_pods=$(kubectl get pods -n triton-inference 2>/dev/null || echo "Not found")
    if echo "$triton_pods" | grep -q "Running"; then
        print_success "Triton Inference Server pods are running"
    else
        print_warning "Triton Inference Server pods are not running correctly or not deployed"
    fi
else
    print_warning "Triton Inference Server namespace does not exist. Triton not deployed."
    echo "  This is normal if you chose not to deploy Triton Inference Server."
fi

if echo "$ollama_ns" | grep -q "ollama"; then
    print_success "Ollama namespace exists"
    
    ollama_pods=$(kubectl get pods -n ollama 2>/dev/null || echo "Not found")
    if echo "$ollama_pods" | grep -q "Running"; then
        print_success "Ollama pods are running"
    else
        print_warning "Ollama pods are not running correctly or not deployed"
    fi
else
    print_warning "Ollama namespace does not exist. Ollama not deployed."
    echo "  This is normal if you chose not to deploy Ollama."
fi

# Final summary
print_header "Verification Summary"

if [ $problem_pods_count -eq 0 ] && [ $not_ready_count -eq 0 ]; then
    print_success "Your Kubernetes cluster appears to be healthy!"
    echo "  All nodes are in Ready state"
    echo "  All system pods are running correctly"
    echo "  Core components are functioning properly"
    echo ""
    echo "You can now deploy your applications on the cluster."
    echo "For more information, check the documentation in the docs/ directory."
else
    print_warning "Your Kubernetes cluster has some issues that need attention."
    if [ $not_ready_count -ne 0 ]; then
        echo "  $not_ready_count nodes are not in Ready state"
    fi
    if [ $problem_pods_count -ne 0 ]; then
        echo "  $problem_pods_count pods are not in Running or Completed state"
    fi
    echo ""
    echo "Please check the issues mentioned above and refer to the troubleshooting guide:"
    echo "  docs/troubleshooting/README.md"
fi

echo -e "\nVerification completed at $(date)"
