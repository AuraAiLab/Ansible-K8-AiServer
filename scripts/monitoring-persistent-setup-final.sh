#!/bin/bash
# Setup script for Kubernetes monitoring with Prometheus and Grafana
# This version uses persistent storage with manually created PVs and PVCs

set -e

NAMESPACE="monitoring"

echo "Setting up Kubernetes monitoring stack with persistent storage..."

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
    if kubectl get pvc -n "$NAMESPACE" | grep -q "grafana-data\|prometheus"; then
        echo "Removing existing PVCs..."
        kubectl delete pvc --all -n "$NAMESPACE"
    fi
fi

# Create host directories with proper permissions
echo "Preparing host directories for persistent storage..."
sudo mkdir -p /models/prometheus /models/grafana
sudo chmod -R 777 /models/prometheus /models/grafana

# Create Prometheus PV
echo "Creating persistent volume for Prometheus..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-prometheus-kube-prometheus-prometheus-0
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /models/prometheus
    type: DirectoryOrCreate
EOF

# Create Grafana PV and PVC
echo "Creating persistent volume and claim for Grafana..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: grafana-data-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /models/grafana
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  volumeName: grafana-data-pv
EOF

# Wait for PVs to be created
echo "Waiting for persistent volumes to be ready..."
sleep 5

# Create values file for Helm
echo "Creating Helm values file..."
cat <<EOF > /tmp/monitoring-values-persistent.yaml
# Values for kube-prometheus-stack with persistent storage using manually created PVs
prometheus:
  prometheusSpec:
    retention: 15d
    resources:
      requests:
        memory: 512Mi
        cpu: 500m
      limits:
        memory: 2Gi
        cpu: 1000m
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 200m

grafana:
  adminPassword: "AiLabMonitoring123"
  persistence:
    enabled: true
    existingClaim: grafana-data-pvc
  service:
    type: LoadBalancer
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 200m
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'kubernetes'
          orgId: 1
          folder: 'Kubernetes'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/kubernetes
        - name: 'nvidia'
          orgId: 1
          folder: 'NVIDIA'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/nvidia
  dashboards:
    kubernetes:
      k8s-system-resources:
        gnetId: 10856
        revision: 1
        datasource: Prometheus
      k8s-deployment-statefulset:
        gnetId: 8588
        revision: 1
        datasource: Prometheus
    nvidia:
      nvidia-dcgm:
        gnetId: 12239
        revision: 1
        datasource: Prometheus

nodeExporter:
  resources:
    requests:
      memory: 64Mi
      cpu: 100m
    limits:
      memory: 128Mi
      cpu: 200m

kubeStateMetrics:
  resources:
    requests:
      memory: 64Mi
      cpu: 100m
    limits:
      memory: 128Mi
      cpu: 200m

# Enable ServiceMonitor for NVIDIA DCGM Exporter
additionalServiceMonitors:
  - name: dcgm-exporter
    selector:
      matchLabels:
        app: dcgm-exporter
    namespaceSelector:
      matchNames:
        - gpu-operator
    endpoints:
      - port: metrics
        interval: 15s
EOF

# Install Prometheus stack with persistent storage
echo "Installing Prometheus and Grafana with persistent storage..."
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --values /tmp/monitoring-values-persistent.yaml \
  --timeout 5m

# Check if NVIDIA is available and install DCGM exporter
if lspci | grep -i nvidia > /dev/null 2>&1 || command -v nvidia-smi > /dev/null 2>&1; then
    echo "NVIDIA GPUs detected, installing DCGM exporter..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dcgm-exporter
  namespace: $NAMESPACE
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app: dcgm-exporter
  template:
    metadata:
      labels:
        app: dcgm-exporter
    spec:
      serviceAccount: dcgm-exporter
      containers:
      - name: dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.1.7-3.1.5-ubuntu20.04
        securityContext:
          runAsNonRoot: false
          runAsUser: 0
        volumeMounts:
        - name: driver-socket
          mountPath: /var/run/nvidia-mps
        - name: driver
          mountPath: /usr/local/nvidia
        - name: dcgm-socket
          mountPath: /var/run/dcgm
      volumes:
      - name: driver-socket
        hostPath:
          path: /var/run/nvidia-mps
      - name: driver
        hostPath:
          path: /usr/local/nvidia
      - name: dcgm-socket
        hostPath:
          path: /var/run/dcgm
---
apiVersion: v1
kind: Service
metadata:
  name: dcgm-exporter
  namespace: $NAMESPACE
spec:
  selector:
    app: dcgm-exporter
  ports:
  - name: metrics
    port: 9400
    targetPort: 9400
EOF
else
    echo "No NVIDIA GPUs detected, skipping DCGM exporter installation"
fi

# Wait for pods to be ready
echo "Waiting for monitoring pods to be ready..."
for i in {1..15}; do
    if kubectl get pods -n "$NAMESPACE" | grep -v "Running\|Completed"; then
        echo "Waiting for all pods to be running (attempt $i/15)..."
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
echo "======================================================================"
