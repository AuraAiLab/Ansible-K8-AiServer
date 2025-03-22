# Configuration Examples

This directory contains example configurations for various components of the Kubernetes cluster deployed with our Ansible playbooks.

## Table of Contents

1. [MetalLB Configuration](#metallb-configuration)
2. [Kubernetes Dashboard](#kubernetes-dashboard)
3. [Monitoring Stack Configuration](#monitoring-stack-configuration)
4. [AI/ML Configurations](#aiml-configurations)
5. [Custom Deployments](#custom-deployments)

## MetalLB Configuration

### Basic Configuration

Here's an example of a basic MetalLB configuration:

```yaml
# metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.20.20-192.168.20.24
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
```

To apply this configuration:

```bash
kubectl apply -f metallb-config.yaml
```

### Advanced Configuration with Address Sharing

If you need to share IP addresses between services:

```yaml
# metallb-shared-ip.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: shared-ip-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.20.30-192.168.20.35
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - shared-ip-pool
```

Services can share an IP by setting the following annotation:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: service1
  annotations:
    metallb.universe.tf/allow-shared-ip: shared-key-name
spec:
  loadBalancerIP: 192.168.20.30
  type: LoadBalancer
  ports:
  - port: 80
```

## Kubernetes Dashboard

### Secure Access Configuration

This example shows how to secure the Kubernetes Dashboard with a ServiceAccount and RBAC:

```yaml
# dashboard-admin-user.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

To apply and get an access token:

```bash
kubectl apply -f dashboard-admin-user.yaml
kubectl -n kubernetes-dashboard create token admin-user --duration=24h
```

### Dashboard with Node Tolerations

If your cluster only has control-plane nodes with taints, use this configuration:

```yaml
# dashboard-with-tolerations.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  template:
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
```

Apply the changes with:

```bash
kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard --patch "$(cat dashboard-with-tolerations.yaml)"
```

## Monitoring Stack Configuration

### Prometheus Configuration

Example Prometheus configuration with retention settings and storage:

```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  namespace: monitoring
  labels:
    name: prometheus-server-conf
data:
  prometheus.yml: |-
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https

      - job_name: 'kubernetes-nodes'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics

      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
```

### Grafana Default Dashboards

Example configuring Grafana with default dashboards:

```yaml
# grafana-dashboards-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: monitoring
data:
  dashboards.yaml: |-
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-dashboard
  namespace: monitoring
data:
  kubernetes-cluster.json: |
    {
      "annotations": {...},
      "editable": true,
      "gnetId": 7249,
      "graphTooltip": 0,
      "id": 1,
      "iteration": 1581342838067,
      ...
    }
```

## AI/ML Configurations

### NVIDIA GPU Operator

Configuration for NVIDIA GPU Operator:

```yaml
# gpu-operator-values.yaml
operator:
  defaultRuntime: containerd
  validator:
    env:
    - name: NVIDIA_VISIBLE_DEVICES
      value: all
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

Installing with Helm:

```bash
helm upgrade --install gpu-operator nvidia/gpu-operator \
  --create-namespace \
  --namespace gpu-operator \
  -f gpu-operator-values.yaml
```

### Triton Inference Server

Example Triton Inference Server deployment:

```yaml
# triton-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: triton-inference-server
  namespace: triton-inference
spec:
  replicas: 1
  selector:
    matchLabels:
      app: triton-inference-server
  template:
    metadata:
      labels:
        app: triton-inference-server
    spec:
      containers:
      - name: triton-inference-server
        image: nvcr.io/nvidia/tritonserver:23.04-py3
        imagePullPolicy: IfNotPresent
        command: ["tritonserver"]
        args: ["--model-repository=/models"]
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 8001
          name: grpc
        - containerPort: 8002
          name: metrics
        resources:
          limits:
            nvidia.com/gpu: 1
        volumeMounts:
        - mountPath: /models
          name: model-repository
      volumes:
      - name: model-repository
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: triton-inference-server
  namespace: triton-inference
spec:
  type: LoadBalancer
  ports:
  - port: 8000
    targetPort: 8000
    name: http-inference
  - port: 8001
    targetPort: 8001
    name: grpc-inference
  - port: 8002
    targetPort: 8002
    name: http-metrics
  selector:
    app: triton-inference-server
```

### Ollama Deployment

Example Ollama configuration:

```yaml
# ollama-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
          name: api
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: 1
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-data
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: ollama
spec:
  type: LoadBalancer
  ports:
  - port: 11434
    targetPort: 11434
    name: api
  selector:
    app: ollama
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-data
  namespace: ollama
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

## Custom Deployments

### Using Nginx Ingress Controller

Example deployment of NGINX ingress controller:

```yaml
# nginx-ingress.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
---
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer
```

### Example Ingress Resource

```yaml
# example-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

Each example configuration above is designed to work with the Kubernetes cluster deployed by our Ansible playbooks. You can modify these examples to fit your specific requirements.
