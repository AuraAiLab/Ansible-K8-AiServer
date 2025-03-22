# Kubernetes Dashboard Guide

This guide provides detailed information about the Kubernetes Dashboard deployment included in this project.

## Overview

The Kubernetes Dashboard is a web-based UI for Kubernetes clusters. It allows users to manage applications running in the cluster and troubleshoot them, as well as manage the cluster itself.

## Version Information

- Dashboard Version: v2.7.0 (configurable in `common_vars.yml`)

## Architecture

The Dashboard is deployed in the `kubernetes-dashboard` namespace and consists of the following components:

- Dashboard Deployment: The main dashboard UI
- Dashboard Service: Exposes the dashboard UI
- Dashboard ServiceAccount: Provides authentication for the dashboard
- Dashboard Metrics-Scraper: Collects metrics from the cluster for display in the dashboard

## Deployment Details

Our Ansible playbook deploys the Kubernetes Dashboard with the following customizations:

1. **Node Tolerations**: Custom tolerations are added to ensure the dashboard can run on control-plane nodes
2. **RBAC Configuration**: Proper RBAC rules are set up for secure access
3. **Metrics Integration**: Dashboard is configured to display real-time metrics

## Accessing the Dashboard

To access the dashboard securely:

1. Start a kubectl proxy:
   ```bash
   kubectl proxy
   ```

2. Access the dashboard at:
   [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)

3. Authentication is required. Use one of these methods:

   **Option 1**: Generate a token (recommended):
   ```bash
   kubectl create token admin-user -n kubernetes-dashboard
   ```

   **Option 2**: Create a kubeconfig file for dashboard access:
   ```bash
   # See the example in the scripts directory
   ./scripts/create-dashboard-kubeconfig.sh
   ```

## Security Considerations

The dashboard deployment follows these security best practices:

1. Access is secured using authentication tokens or kubeconfig files
2. HTTPS is enabled by default with self-signed certificates
3. Service account permissions are restricted to only what's necessary
4. The dashboard is not exposed outside the cluster by default

## Customization

To customize the dashboard deployment, you can modify the following files:

1. Change the dashboard version in `common_vars.yml`:
   ```yaml
   dashboard_version: "v2.7.0"  # Change to desired version
   ```

2. Customize the dashboard YAML manifest in the playbook if needed:
   ```yaml
   # Example customizing dashboard resources
   resources:
     limits:
       cpu: 500m
       memory: 1Gi
     requests:
       cpu: 100m
       memory: 512Mi
   ```

## Troubleshooting

### Dashboard Pods in Pending State

If dashboard pods remain in a pending state, check for node taints:

```bash
kubectl describe nodes | grep Taint
```

Apply the necessary tolerations as described in [ISSUES.md](../../ISSUES.md).

### Authentication Issues

If you encounter "authentication required" or token errors:

1. Check that you're using a valid token:
   ```bash
   kubectl create token admin-user -n kubernetes-dashboard
   ```

2. Verify the service account exists:
   ```bash
   kubectl get serviceaccount admin-user -n kubernetes-dashboard
   ```

3. Check RBAC permissions:
   ```bash
   kubectl get clusterrolebinding dashboard-admin
   ```

## Additional Resources

- [Kubernetes Dashboard GitHub Repository](https://github.com/kubernetes/dashboard)
- [Official Kubernetes Dashboard Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
