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
- Persistent storage ensures metrics retention across restarts
- Grafana provides dashboards for visualizing metrics
- AlertManager handles notifications for alert conditions

## Accessing the Dashboards

### Grafana

- URL: http://[LOAD_BALANCER_IP]:80
- Default credentials: 
  - Username: `admin`
  - Password: `AiLabMonitoring123` (should be changed in production)
  
### Prometheus

- URL: http://[LOAD_BALANCER_IP]:9090

## Available Dashboards

Pre-configured dashboards include:

1. **Kubernetes System Resources** - Node-level metrics (CPU, memory, etc.)
2. **Kubernetes Deployments & StatefulSets** - Workload-specific metrics
3. **NVIDIA GPU Metrics** - GPU utilization, memory, temperature, etc.

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

## Security Considerations

- The Grafana admin password should be changed for production deployments
- Consider implementing TLS for all monitoring endpoints
- Restrict access to the monitoring namespace through RBAC
