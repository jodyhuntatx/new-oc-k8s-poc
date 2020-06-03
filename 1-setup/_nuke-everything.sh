#!/bin/bash
pushd 3-user-ns-setup
./0-user-ns-setup.sh clean
popd
pushd 2-cluster-setup
./2-mysqldb-deploy.sh clean
./1-follower-deploy.sh clean
./0-namespace-init.sh clean
popd
pushd 1-dap-master-setup
./stop
popd
