#!/bin/bash

source common.sh

startCluster "core" $NUMBER_CORES
waitForCluster "core" $NUMBER_CORES

startCluster "edge" $NUMBER_EDGES
waitForCluster "edge" $NUMBER_EDGES
