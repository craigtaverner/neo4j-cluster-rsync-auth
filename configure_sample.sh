#!/bin/bash

source common.sh

function addFilesToClusterDBMS() {
  prefix=$1 ; shift
  typeset -i i END # Let's be explicit
  let END=$1 ; shift
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    path="$(pwd)/${dir}/data/dbms"
    if [ -d "$dir" ] ; then
      mkdir -p "$path"
      echo "Installing sample files in $dir: $@"
      for sample in $@
      do
        dest="${path}/${sample/\.sample/}"
        cp "$sample" "$dest"
      done
    else
      echo "Directory does not exist: $dir"
    fi
  done
}

addFilesToClusterDBMS "core" $NUMBER_CORES "auth.sample" "roles.sample"
addFilesToClusterDBMS "edge" $NUMBER_EDGES "auth.sample" "roles.sample"
