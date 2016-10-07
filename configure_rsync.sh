#!/bin/bash

source common.sh

if [ -z "$USER" ] ; then
  echo "No USER set - cannot configure local rsync"
  exit -1
fi

initClusterConfigLocal

addToClusterConfigLocal "core" $NUMBER_CORES
addToClusterConfigLocal "edge" $NUMBER_EDGES

configureClusterRSync "core" $NUMBER_CORES
configureClusterRSync "edge" $NUMBER_EDGES

installClusterRSyncCrontab
