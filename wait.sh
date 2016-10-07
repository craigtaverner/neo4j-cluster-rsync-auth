#!/bin/bash

source common.sh

waitForCluster "core" $NUMBER_CORES
waitForCluster "edge" $NUMBER_CORES
