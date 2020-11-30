#!/bin/bash
pushd 3-deployment
./2-mysqldb-deploy.sh clean
./1-follower-deploy.sh clean
popd
pushd 2-namespace-setup
./start clean
popd
pushd 1-dap-master-setup
./stop
popd
