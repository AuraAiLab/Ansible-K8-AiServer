#!/bin/bash
# Setup script for Kubernetes monitoring with Prometheus and Grafana
# This version uses persistent storage with manually created PVs and PVCs

set -e

NAMESPACE="monitoring"
PERSISTENCE_FILE="/root/CascadeProjects/ansible-k8-aiserver/playbooks/monitoring-persistence.yaml"
VALUES_FILE="/root/CascadeProjects/ansible-k8-aiserver/playbooks/monitoring-values-persistent.yaml"
DCGM_FILE="/root/CascadeProjects/ansible-k8-aiserver/playbooks/dcgm-exporter-setup.yaml"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed or not in PATH"
    exit 1
fi

echo "Setting up Kubernetes monitoring stack with persistent storage..."

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace if it doesn't exist
echo "Creating monitoring namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Clean up any existing installation
if helm list -n "$NAMESPACE" | grep -q prometheus; then
    echo "Found existing prometheus installation. Uninstalling..."
    helm uninstall prometheus -n "$NAMESPACE"
    
    # Wait for resources to be removed
    echo "Waiting for resources to be cleaned up..."
    sleep 15
    
    # Check if PVCs exist and remove them
    if kubectl get pvc -n "$NAMESPACE" | grep -q "prometheus-data\|grafana-data"; then
        echo "Removing existing PVCs..."
        kubectl delete pvc --all -n "$NAMESPACE"
    fi
fi

# Apply persistent volume configurations
echo "Creating persistent volumes and claims..."
kubectl apply -f "$PERSISTENCE_FILE"

# Ensure PVs and PVCs are created before proceeding
echo "Waiting for PVCs to be bound..."
sleep 5

# Verify PVC status
kubectl get pvc -n "$NAMESPACE"

# Install Prometheus stack with persistent storage
echo "Installing Prometheus and Grafana with persistent storage..."
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --values "$VALUES_FILE" \
  --timeout 5m

# Check if NVIDIA is available and install DCGM exporter
if ssh -o StrictHostKeyChecking=no ee@192.168.20.10 "nvidia-smi" &>/dev/null; then
    echo "NVIDIA GPUs detected, installing DCGM exporter..."
    kubectl apply -f "$DCGM_FILE"
else
    echo "No NVIDIA GPUs detected, skipping DCGM exporter installation"
fi

# Wait for pods to be ready
echo "Waiting for monitoring pods to be ready..."
for i in {1..12}; do
    if kubectl get pods -n "$NAMESPACE" | grep -v "Running\|Completed"; then
        echo "Waiting for all pods to be running (attempt $i/12)..."
        sleep 10
    else
        break
    fi
done

# Get access information
GRAFANA_IP=$(kubectl get svc -n "$NAMESPACE" prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "======================= MONITORING SETUP COMPLETE ======================="
echo "Grafana dashboard URL: http://$GRAFANA_IP:80"
echo "Default credentials: admin / AiLabMonitoring123"
echo "Check the documentation at /root/CascadeProjects/ansible-k8-aiserver/docs/monitoring-guide.md"
echo "for more information on available dashboards and monitoring features."
echo "======================================================================"
