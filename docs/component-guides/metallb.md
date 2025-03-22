# MetalLB Guide

This guide provides detailed information about the MetalLB load balancer deployment included in this project.

## Overview

MetalLB is a load-balancer implementation for bare metal Kubernetes clusters that gives your cluster an implementation of Kubernetes' `LoadBalancer` Service type. It allows you to create services of type LoadBalancer in Kubernetes environments that don't run on a cloud provider, such as on-premises, edge, and bare metal clusters.

## Version Information

- MetalLB Version: v0.13.12 (configurable in `common_vars.yml`)

## Architecture

MetalLB consists of two main components:

1. **Controller**: Handles IP address assignment
2. **Speaker**: Broadcasts the IP address through ARP/NDP or BGP

Both components are deployed in the `metallb-system` namespace.

## Deployment Details

Our Ansible playbook deploys MetalLB with the following configuration:

1. **Layer 2 Mode**: By default, we use the L2 (Layer 2) operation mode, where MetalLB uses ARP/NDP to advertise the service IPs.
2. **IP Address Pool**: A configurable IP address pool for service assignment (configured via `metallb_ip_range` in `common_vars.yml`).
3. **Namespace**: Deployed in the dedicated `metallb-system` namespace.

## Configuration

MetalLB is configured with the following IP address pool:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${metallb_ip_range}  # Configured in common_vars.yml
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
```

## Usage

After deployment, you can create Kubernetes services with type `LoadBalancer`, and MetalLB will automatically assign them external IP addresses from the configured pool:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

To verify that MetalLB is working:

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Verify the IPAddressPool configuration
kubectl get ipaddresspools -n metallb-system -o yaml

# Create a test service
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check if an external IP was assigned
kubectl get service nginx
```

## Troubleshooting

### Services Stuck with Pending External IP

If your LoadBalancer services are stuck with pending external IPs:

1. **Check MetalLB pod status**:
   ```bash
   kubectl get pods -n metallb-system
   ```

2. **Check controller logs**:
   ```bash
   kubectl logs -n metallb-system -l app=metallb,component=controller
   ```

3. **Verify IP address pool configuration**:
   ```bash
   kubectl get ipaddresspools -n metallb-system -o yaml
   ```

4. **Check L2 advertisement configuration**:
   ```bash
   kubectl get l2advertisements -n metallb-system -o yaml
   ```

5. **IP Range Issues**: Ensure the configured IP range doesn't conflict with other network devices and is in the same subnet as your nodes.

### Kubernetes API Errors

If you encounter errors like "unable to retrieve address pools" or other Kubernetes API-related errors:

1. **Check RBAC permissions**:
   ```bash
   kubectl get clusterrole metallb-system:controller -o yaml
   kubectl get clusterrolebinding metallb-system:controller -o yaml
   ```

2. **Check webhook configuration**:
   ```bash
   kubectl get validatingwebhookconfigurations -l app=metallb
   ```

## Custom Configuration

### Using BGP Mode

To switch from Layer 2 to BGP mode:

1. Create a BGP configuration:
   ```yaml
   apiVersion: metallb.io/v1beta2
   kind: BGPPeer
   metadata:
     name: bgp-router
     namespace: metallb-system
   spec:
     myASN: 64500
     peerASN: 64501
     peerAddress: 192.168.1.1
   ```

2. Create a BGP advertisement:
   ```yaml
   apiVersion: metallb.io/v1beta1
   kind: BGPAdvertisement
   metadata:
     name: bgp-advert
     namespace: metallb-system
   spec:
     ipAddressPools:
     - default-pool
   ```

### Shared IP Addresses

To share IP addresses between multiple services (useful for e.g. HTTP/HTTPS on the same IP):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: http-service
  annotations:
    metallb.universe.tf/allow-shared-ip: "shared-ip-key"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: https-service
  annotations:
    metallb.universe.tf/allow-shared-ip: "shared-ip-key"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 443
```

## Additional Resources

- [MetalLB Official Documentation](https://metallb.universe.tf/)
- [MetalLB GitHub Repository](https://github.com/metallb/metallb)
- [MetalLB Configuration Examples](../examples/README.md#metallb-configuration)
