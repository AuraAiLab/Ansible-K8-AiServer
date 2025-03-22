#!/bin/bash
# Kubernetes Cluster Reset Helper Script
# This script helps reset a Kubernetes cluster deployed with our Ansible playbooks

set -e

# Default values
INVENTORY_FILE="../playbooks/inventory"
VERBOSE=""
LIMIT=""
FORCE=""

# Display help message
function show_help {
    echo "Kubernetes Cluster Reset Helper"
    echo "------------------------------"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -i, --inventory FILE     Specify inventory file (default: ../playbooks/inventory)"
    echo "  -v, --verbose            Enable verbose output"
    echo "  -l, --limit HOSTS        Limit execution to specified hosts"
    echo "  -f, --force              Skip confirmation prompt"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --verbose           # Run with verbose output"
    echo "  $0 --limit worker      # Reset only worker nodes"
    echo "  $0 --force             # Reset without confirmation"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -l|--limit)
            LIMIT="--limit $2"
            shift
            shift
            ;;
        -f|--force)
            FORCE="yes"
            shift
            ;;
        -h|--help)
            show_help
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Verify that inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file '$INVENTORY_FILE' not found."
    exit 1
fi

# Show warning message
echo "========================================"
echo "WARNING: KUBERNETES CLUSTER RESET"
echo "========================================"
echo "This script will completely reset your Kubernetes cluster."
echo "This action will:"
echo "  1. Reset all kubeadm installations"
echo "  2. Remove all Kubernetes packages"
echo "  3. Reset container runtime (containerd)"
echo "  4. Remove all pod configurations and data"
echo "  5. Reset network configurations"
echo "========================================"
echo "THIS ACTION IS IRREVERSIBLE. ALL DATA WILL BE LOST."
echo "========================================"
echo ""

# Ask for confirmation unless --force is specified
if [ "$FORCE" != "yes" ]; then
    read -p "Are you ABSOLUTELY SURE you want to reset the cluster? Type 'YES' to confirm: " -r
    if [ "$REPLY" != "YES" ]; then
        echo "Cluster reset aborted."
        exit 1
    fi
    
    echo ""
    read -p "Last chance! This will DESTROY YOUR CLUSTER. Continue? (yes/no): " -n 3 -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cluster reset aborted."
        exit 1
    fi
fi

echo "Starting Kubernetes cluster reset..."

# Create temporary playbook for resetting the cluster
TMP_PLAYBOOK="/tmp/k8s-reset-playbook-$$.yml"
cat > $TMP_PLAYBOOK << 'EOF'
---
- hosts: all
  become: yes
  tasks:
    - name: Get list of running pods
      shell: "kubectl get pods --all-namespaces || echo 'Unable to get pods'"
      register: running_pods
      ignore_errors: yes
      when: inventory_hostname in groups['k8s_master'] | default([])
      
    - name: Display running pods before reset (if any)
      debug:
        var: running_pods.stdout_lines
      when: inventory_hostname in groups['k8s_master'] | default([]) and running_pods.rc == 0

    - name: Reset kubeadm
      shell: "kubeadm reset -f"
      ignore_errors: yes

    - name: Remove all containers
      shell: "crictl rm $(crictl ps -a -q) || true"
      ignore_errors: yes

    - name: Stop services
      systemd:
        name: "{{ item }}"
        state: stopped
        enabled: no
      with_items:
        - kubelet
        - containerd
      ignore_errors: yes

    - name: Remove Kubernetes packages
      apt:
        name:
          - kubeadm
          - kubelet
          - kubectl
          - kubernetes-cni
        state: absent
        purge: yes
      ignore_errors: yes

    - name: Remove CNI configurations
      file:
        path: /etc/cni/net.d
        state: absent
      ignore_errors: yes

    - name: Remove Kubernetes directories
      file:
        path: "{{ item }}"
        state: absent
      with_items:
        - /etc/kubernetes/
        - /var/lib/kubelet/
        - /var/lib/etcd/
        - /var/lib/cni/
        - /var/run/kubernetes/
        - $HOME/.kube/config
      ignore_errors: yes

    - name: Flush iptables rules
      shell: |
        iptables -F
        iptables -t nat -F
        iptables -t mangle -F
        iptables -X
      ignore_errors: yes

    - name: Restart containerd
      systemd:
        name: containerd
        state: restarted
      ignore_errors: yes

    - name: Clean up system status
      shell: |
        systemctl daemon-reload
        systemctl reset-failed
      ignore_errors: yes
EOF

# Run the reset playbook with specified parameters
ansible-playbook -i "$INVENTORY_FILE" $TMP_PLAYBOOK $VERBOSE $LIMIT

# Clean up temporary playbook
rm -f $TMP_PLAYBOOK

# Check if ansible-playbook command was successful
if [ $? -eq 0 ]; then
    echo "========================================"
    echo "Kubernetes cluster reset completed successfully."
    echo "All Kubernetes components have been removed from the system."
    echo "To reinstall the cluster, run the cluster-setup.sh script."
    echo "========================================"
else
    echo "========================================"
    echo "Kubernetes cluster reset encountered some issues."
    echo "Some components might not have been fully removed."
    echo "Please check the logs above for more information."
    echo "========================================"
    exit 1
fi
