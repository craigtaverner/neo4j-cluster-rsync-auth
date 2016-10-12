#!/bin/bash

source common.sh

restartCluster "core" $NUMBER_CORES
restartCluster "edge" $NUMBER_EDGES
waitForCluster "core" $NUMBER_CORES
waitForCluster "edge" $NUMBER_EDGES
