# Kubernetes Monitoring with Prometheus and Grafana

This guide documents the monitoring setup for the AI Server Kubernetes cluster.

## Components

The monitoring stack consists of:

1. **Prometheus** - For metrics collection and storage
2. **Grafana** - For visualization and dashboards
3. **AlertManager** - For alerting based on metrics
4. **Node Exporter** - For collecting host metrics
5. **Kube State Metrics** - For collecting Kubernetes state metrics
6. **NVIDIA DCGM Exporter** - For collecting GPU metrics

## Architecture

- Prometheus scrapes metrics from various sources at configurable intervals
- Persistent storage using HostPath volumes (same approach as AI models)
- Grafana provides dashboards for visualizing metrics
- AlertManager handles notifications for alert conditions

## Accessing the Dashboards

### Grafana

- URL: http://192.168.20.21:80
- Default credentials: 
  - Username: `admin`
  - Password: `AiLabMonitoring123` (should be changed in production)
  
### Prometheus

Prometheus UI is primarily accessible through Grafana. If direct access is needed:

```bash
# Port-forward the Prometheus service to your local machine
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Then access: http://localhost:9090

## Recommended Dashboards

The following pre-configured dashboards are available in Grafana:

### 1. Kubernetes Cluster Overview
- Dashboard ID: 10856
- Shows overall cluster resource usage, node status, and workload overview
- Perfect for a high-level status check of the entire cluster

### 2. Node Resources
- Navigate to: Dashboards → Kubernetes → Compute Resources → Node
- Provides detailed CPU, memory, and disk usage for each node
- Helps identify resource constraints or imbalances

### 3. Pod Resources
- Navigate to: Dashboards → Kubernetes → Compute Resources → Pod
- Displays resource usage by individual pods
- Useful for identifying high-resource consumers

### 4. GPU Metrics Dashboard
- Dashboard ID: 12239
- Shows NVIDIA GPU utilization, memory usage, temperature, and power consumption
- Critical for monitoring AI/ML workload performance

### 5. Persistent Volume Usage
- Navigate to: Dashboards → Kubernetes → Storage
- Tracks storage utilization across persistent volumes
- Important for capacity planning

## Creating Custom Dashboards

To create a simple custom dashboard for quick resource monitoring:

1. Click "+" icon in the left sidebar and select "Dashboard"
2. Add a new panel
3. For CPU usage, use the query:
   ```
   sum(rate(node_cpu_seconds_total{mode!="idle"}[5m])) by (instance) / 
   sum(rate(node_cpu_seconds_total[5m])) by (instance) * 100
   ```
4. For memory usage, use:
   ```
   (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 
   node_memory_MemTotal_bytes * 100
   ```
5. For GPU utilization, use:
   ```
   DCGM_FI_DEV_GPU_UTIL
   ```

## Custom Metrics

To add custom metrics:

1. Create a ServiceMonitor for your application
2. Ensure your application exposes Prometheus-compatible metrics
3. Configure alerts in Prometheus as needed

## Troubleshooting

Common issues:

1. **Missing metrics**: Check that ServiceMonitors are correctly configured
2. **Dashboard errors**: Ensure the correct data source is selected
3. **Alert issues**: Verify AlertManager configuration

## Persistent Storage

The monitoring stack now uses persistent storage with HostPath volumes to ensure that monitoring data is retained across pod restarts:

1. **Prometheus** data is stored at `/models/prometheus` on the host node
2. **Grafana** data is stored at `/models/grafana` on the host node

This implementation uses manually created Persistent Volumes and PersistentVolumeClaims since the Kubernetes cluster doesn't have a default StorageClass configured.

### Key Implementation Details

For Prometheus, we create a PersistentVolume with a very specific name that matches the StatefulSet naming pattern used by the Prometheus Operator:

```yaml
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
```

For Grafana, we create both a PersistentVolume and a PersistentVolumeClaim:

```yaml
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
```

The Helm values are configured to use these persistent volumes:

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

grafana:
  persistence:
    enabled: true
    existingClaim: grafana-data-pvc
```

> ⚠️ **Important**: The host directories must have appropriate permissions (777) to allow the containers to write to them: `sudo chmod -R 777 /models/prometheus /models/grafana`

### Deployment Script

A complete setup script is available at `/scripts/monitoring-persistent-setup-final.sh` that handles:
1. Creating the namespace
2. Removing any existing monitoring stack
3. Preparing host directories with proper permissions
4. Creating PVs and PVCs
5. Deploying the monitoring stack with persistent storage
6. Configuring NVIDIA DCGM Exporter (if GPUs are detected)

### Backup Considerations

To back up the monitoring data:
- For Prometheus: Backup the `/models/prometheus` directory on the host
- For Grafana: Backup the `/models/grafana` directory on the host

Regular backups are recommended, especially before upgrades or changes to the monitoring stack.

## Security Considerations

- The Grafana admin password should be changed for production deployments
- Consider implementing TLS for all monitoring endpoints
- Restrict access to the monitoring namespace through RBAC
