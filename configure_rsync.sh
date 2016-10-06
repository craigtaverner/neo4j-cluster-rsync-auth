#!/bin/bash

source common.sh

if [ -z "$USER" ] ; then
  echo "No USER set - cannot configure local rsync"
  exit -1
fi

makeClusterConfigLocal "core" $NUMBER_CORES
configureClusterRSync "core" $NUMBER_CORES
