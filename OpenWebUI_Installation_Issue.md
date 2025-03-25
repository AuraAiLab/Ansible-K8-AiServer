## OpenWebUI Not Installing Correctly

### Description
The Ansible playbook k8-final2.yml attempts to install OpenWebUI using Helm, but the installation is not successful. The task has a conditional check for the existence of the openwebui-chart directory, but this directory appears to be missing on the target system.

### Expected Behavior
OpenWebUI should be installed properly as a Kubernetes pod in the openwebui namespace.

### Current Behavior
The OpenWebUI namespace doesn't exist, and no pods are running. The installation is either skipped because the chart directory doesn't exist or fails silently due to the 'ignore_errors: yes' setting.

### Proposed Solution
1. Add a task to create or download the OpenWebUI chart
2. Remove ignore_errors option
3. Implement better error handling
4. Add proper validation steps
