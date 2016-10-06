#!/bin/bash

source common.sh

stopCluster "core" $NUMBER_CORES
deleteCluster "core" $NUMBER_CORES
