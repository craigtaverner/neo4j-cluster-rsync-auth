#!/bin/bash

source common.sh

installCluster "core" $NUMBER_CORES
configureCluster "core" $NUMBER_CORES
clearCluster "core" $NUMBER_CORES
startCluster "core" $NUMBER_CORES
waitForCluster "core" $NUMBER_CORES
