#!/bin/bash

source common.sh
source remove.sh

function installAndConfigure() {
  prefix=$1
  num=$2
  echo -e "\n#\n# Installing cluster of $num $prefix servers\n#\n"
  installCluster "$prefix" $num
  configureCluster "$prefix" $num
  clearCluster "$prefix" $num
  startCluster "$prefix" $num
}

function waitFor() {
  prefix=$1
  num=$2
  echo -e "\n#\n# Waiting for cluster of $num $prefix servers to come online\n#\n"
  waitForCluster "$prefix" $num
}

installAndConfigure "core" $NUMBER_CORES
installAndConfigure "edge" $NUMBER_EDGES
waitFor "core" $NUMBER_CORES
waitFor "edge" $NUMBER_EDGES
