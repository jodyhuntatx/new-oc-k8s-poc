# OpenShift Workshop Labs

# User lab setup:

1) Install the oc CLI executable on your local machine. Instructions are at:

   https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html

2) Download/unzip or clone this repository to your local machine:

   https://github.com/jodyhuntatx/ocp4-workshop-labs

3) Edit dap-app.config to set paths to your oc CLI binary and KUBECONFIG

4) Source dap-app.config to set all env vars:

   Run: ```source dap-app.config```

5) Set env vars for your DAP admin creds:

   Run: ```export AUTH_USERNAME=<value-to-be-provided>```

   Run: ```export AUTH_PASSWORD=<value-to-be-provided>```

5) Login with your lab user id:

   Run: ```oc login -u <username> --server=$LAB_CLUSTER```

6) Wait for further instructions.

Some handy oc commands:

- Get recent events:

  ```oc get event | awk '$1 ~ /^*s/'```
