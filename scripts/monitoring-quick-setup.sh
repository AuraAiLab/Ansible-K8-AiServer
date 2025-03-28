#!/bin/bash
# Quick setup script for Kubernetes monitoring with Prometheus and Grafana
# This script installs only the monitoring components without touching the rest of the cluster

set -e

NAMESPACE="monitoring"
VALUES_FILE="/root/CascadeProjects/ansible-k8-aiserver/playbooks/monitoring-values-simple.yaml"
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

echo "Setting up Kubernetes monitoring stack..."

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace if it doesn't exist
echo "Creating monitoring namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Check for existing installation
if helm list -n "$NAMESPACE" | grep -q prometheus; then
    echo "Found existing prometheus installation. Uninstalling..."
    helm uninstall prometheus -n "$NAMESPACE"
    # Wait a bit for resources to clean up
    sleep 10
fi

# Install Prometheus stack
echo "Installing Prometheus and Grafana with custom values..."
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --values "$VALUES_FILE" \
  --timeout 5m

# Check if NVIDIA is available
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPUs detected, installing DCGM exporter..."
    kubectl apply -f "$DCGM_FILE"
else
    echo "No NVIDIA GPUs detected, skipping DCGM exporter installation"
fi

# Wait for pods to be ready
echo "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=300s

# Get access information
GRAFANA_IP=$(kubectl get svc -n "$NAMESPACE" prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "======================= MONITORING SETUP COMPLETE ======================="
echo "Grafana dashboard URL: http://$GRAFANA_IP:80"
echo "Default credentials: admin / AiLabMonitoring123"
echo "Check the documentation at /root/CascadeProjects/ansible-k8-aiserver/docs/monitoring-guide.md"
echo "for more information on available dashboards and monitoring features."
echo "======================================================================"
