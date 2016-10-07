#!/bin/bash

source common.sh

configureCluster "core" $NUMBER_CORES
configureCluster "edge" $NUMBER_EDGES
