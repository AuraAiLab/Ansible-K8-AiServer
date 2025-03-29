# Ollama GPU Configuration

This document explains the GPU configuration options for the Ollama deployment in different branches.

## Main Branch (Single GPU)

The main branch is configured to use a single GPU, specifically targeting the first NVIDIA GPU on the host machine.

### Configuration Details:

- **Environment Variables**: Uses `CUDA_VISIBLE_DEVICES=0` to target only the first GPU
- **Resource Allocation**: Sets `nvidia.com/gpu: 1` to request one GPU
- **Purpose**: Optimized for single-GPU systems or to ensure predictable behavior by using the same GPU consistently

### Helm Chart Configuration

The Ollama chart in the main branch includes the following GPU-specific settings:

```yaml
spec:
  containers:
  - name: ollama
    # ...
    env:
    - name: CUDA_VISIBLE_DEVICES
      value: "0"
    resources:
      limits:
        nvidia.com/gpu: 1
```

## Feature Branch (Dual GPU)

The feature branch `feature/ollama-gpu-selection` supports dual GPU setups, allowing Ollama to utilize both available GPUs simultaneously.

### Configuration Details:

- **Environment Variables**: Removes `CUDA_VISIBLE_DEVICES` to let Ollama access all available GPUs
- **Resource Allocation**: Sets `nvidia.com/gpu: 2` to request two GPUs
- **Purpose**: Enables more efficient parallel processing for multiple Ollama workloads and model loading

### Helm Chart Configuration

The Ollama chart in the feature branch includes the following GPU-specific settings:

```yaml
spec:
  containers:
  - name: ollama
    # No CUDA_VISIBLE_DEVICES environment variable
    resources:
      limits:
        nvidia.com/gpu: 2
```

## Usage Considerations

### Main Branch (Single GPU)

- Best for scenarios where you want to ensure consistent performance
- Simpler setup and resource management
- Ideal when running on a machine with a single GPU

### Feature Branch (Dual GPU)

- Better for parallel workloads and serving multiple models
- Can improve throughput when multiple requests come in simultaneously
- Requires a machine with at least two NVIDIA GPUs

## Testing Configurations

To verify that Ollama is using the correct GPU(s), run the following command in the Ollama pod:

```bash
kubectl exec -it -n ollama <ollama-pod-name> -- nvidia-smi
```

For the single GPU configuration, this should show activity only on GPU 0.
For the dual GPU configuration, this should show activity distributed across both GPUs.

## Future Enhancements

Future plans include:
- Adding support for fine-grained GPU selection
- Implementing more sophisticated GPU assignment strategies
- Enhancing monitoring to track GPU utilization per model
