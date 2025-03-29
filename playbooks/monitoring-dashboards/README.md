# NVIDIA GPU Monitoring Dashboards for Grafana

This directory contains Grafana dashboard definitions for monitoring NVIDIA GPUs in Kubernetes environments. The dashboards use Prometheus as the data source and leverage the DCGM Exporter metrics.

## Dashboards Overview

### 1. NVIDIA GPU Per-Device Monitoring
- **File:** `Nvidia_GPU_Per_Device_Dashboard.json`
- **Purpose:** Detailed monitoring of individual GPU metrics
- **Key Metrics:** GPU utilization
- **Target Users:** Data scientists, ML engineers, and administrators who need to monitor specific GPUs

### 2. System and GPU Dashboard
- **File:** `System_and_GPU_Dashboard.json`
- **Purpose:** Combined view of system resources (CPU, memory) alongside GPU metrics
- **Key Metrics:** CPU utilization, memory usage, GPU utilization, GPU memory usage
- **Target Users:** System administrators and DevOps engineers who need a comprehensive view of both system and GPU resources

### 3. NVIDIA GPU Advanced Metrics
- **File:** `Nvidia_GPU_Advanced_Metrics_Dashboard.json`
- **Purpose:** Detailed technical metrics about GPU performance and health
- **Key Metrics:** GPU temperature, power usage, memory clock, SM clock
- **Target Users:** System administrators and performance engineers who need to monitor GPU health and performance characteristics

## Prerequisites

- Kubernetes cluster with GPUs
- Prometheus installed and configured
- DCGM Exporter deployed to expose NVIDIA GPU metrics
- Grafana deployed and connected to Prometheus

## Installation

1. Import these dashboard JSON files into your Grafana instance:
   - Navigate to Dashboards > Import in the Grafana UI
   - Upload the JSON file or paste its contents
   - Select your Prometheus data source
   - Click Import

## Dashboard Variables

All dashboards use the following variables:
- `$gpu`: Allows filtering by specific GPU devices

## Troubleshooting

If metrics are not displaying correctly:
1. Verify that DCGM Exporter is running and exposing metrics
2. Check that Prometheus is scraping the DCGM Exporter endpoint
3. Confirm that the metric names match those in the dashboard queries (metric names can vary slightly between DCGM Exporter versions)

## Customization

Feel free to customize these dashboards to fit your specific monitoring needs. Some suggestions:
- Add alerts for critical thresholds
- Adjust time ranges for historical analysis
- Add additional metrics specific to your workloads
- Customize visualization styles and thresholds

## Metrics Reference

Common DCGM metrics used in these dashboards:
- `DCGM_FI_DEV_GPU_UTIL`: GPU utilization (%)
- `DCGM_FI_DEV_GPU_TEMP`: GPU temperature (°C)
- `DCGM_FI_DEV_POWER_USAGE`: Power usage (W)
- `DCGM_FI_DEV_FB_USED`: Framebuffer memory used (MiB)
- `DCGM_FI_DEV_FB_FREE`: Framebuffer memory free (MiB)
- `DCGM_FI_DEV_MEM_CLOCK`: Memory clock frequency (MHz)
- `DCGM_FI_DEV_SM_CLOCK`: SM clock frequency (MHz)
