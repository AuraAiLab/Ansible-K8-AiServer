#!/bin/bash
# Kubernetes Cluster Setup Helper Script
# This script helps run the Ansible playbook with proper parameters

set -e

# Default values
INVENTORY_FILE="../playbooks/inventory"
PLAYBOOK_FILE="../playbooks/k8-final2.yml"
VERBOSE=""
TAGS=""
SKIP_TAGS=""
LIMIT=""

# Display help message
function show_help {
    echo "Kubernetes Cluster Setup Helper"
    echo "-------------------------------"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -i, --inventory FILE     Specify inventory file (default: ../playbooks/inventory)"
    echo "  -p, --playbook FILE      Specify playbook file (default: ../playbooks/k8-final2.yml)"
    echo "  -v, --verbose            Enable verbose output"
    echo "  -t, --tags TAGS          Only run plays and tasks tagged with these values"
    echo "  -s, --skip-tags TAGS     Skip plays and tasks tagged with these values"
    echo "  -l, --limit HOSTS        Limit execution to specified hosts"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --verbose                                # Run with verbose output"
    echo "  $0 --tags setup,dashboard --skip-tags gpu   # Run only setup and dashboard tasks, skip GPU tasks"
    echo "  $0 --limit master                           # Run only on master node"
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
        -p|--playbook)
            PLAYBOOK_FILE="$2"
            shift
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -t|--tags)
            TAGS="--tags $2"
            shift
            shift
            ;;
        -s|--skip-tags)
            SKIP_TAGS="--skip-tags $2"
            shift
            shift
            ;;
        -l|--limit)
            LIMIT="--limit $2"
            shift
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

# Verify that playbook file exists
if [ ! -f "$PLAYBOOK_FILE" ]; then
    echo "Error: Playbook file '$PLAYBOOK_FILE' not found."
    exit 1
fi

# Show configuration before running
echo "========================================"
echo "Kubernetes Cluster Setup Configuration:"
echo "========================================"
echo "Inventory File: $INVENTORY_FILE"
echo "Playbook File:  $PLAYBOOK_FILE"
if [ ! -z "$TAGS" ]; then
    echo "Tags:          ${TAGS#--tags }"
fi
if [ ! -z "$SKIP_TAGS" ]; then
    echo "Skip Tags:     ${SKIP_TAGS#--skip-tags }"
fi
if [ ! -z "$LIMIT" ]; then
    echo "Limit:         ${LIMIT#--limit }"
fi
echo "Verbose:       ${VERBOSE:+yes}"
echo "========================================"
echo ""

# Ask for confirmation
read -p "Do you want to continue with this configuration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting installation."
    exit 1
fi

# Run ansible playbook with specified parameters
echo "Starting Kubernetes cluster installation..."
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" $VERBOSE $TAGS $SKIP_TAGS $LIMIT

# Check if ansible-playbook command was successful
if [ $? -eq 0 ]; then
    echo "========================================"
    echo "Kubernetes cluster installation completed successfully."
    echo "To verify the installation, run: kubectl get nodes"
    echo "To access the Kubernetes Dashboard, run: kubectl proxy"
    echo "Then open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    echo "========================================"
else
    echo "========================================"
    echo "Kubernetes cluster installation failed."
    echo "Please check the logs above for more information."
    echo "========================================"
    exit 1
fi
