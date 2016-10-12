#!/bin/bash

source common.sh

USER_NAME=$1
USER_PW=$2
LONG_INDEX=$3

if [ -z "$USER_NAME" ] ; then
  USER_NAME="morpheus"
  echo "No username provided for clearing auth cache: defaulting to $USER_NAME"
fi

if [ -z "$USER_PW" ] ; then
  USER_PW="ProudListingsMedia1"
  echo "No user password provided for clearing auth cache: defaulting to $USER_PW"
fi

function clearAuthCache() {
  prefix=$1
  index=$2
  username=$3
  password=$4
  cypher="CALL dbms.security.clearAuthCache();"
  if [ "$prefix" = "core" ] ; then
    address="bolt://localhost:769$index"
  else
    address="bolt://localhost:760$index"
  fi
  dir="${prefix}_${index}"
  if [ -d "$dir" ] ; then
    echo "Running query on $dir at $address as '$username': \"$cypher\""
    echo "$cypher" | $dir/bin/cypher-shell -u "$username" -p "$password" -a "$address" > /dev/null &
  else
    echo "No such directory: $dir"
  fi
}

function clearAuthCacheOnCluster() {
  prefix=$1
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    clearAuthCache $prefix $i $3 $4
  done
}

clearAuthCacheOnCluster "core" $NUMBER_CORES "$USER_NAME" "$USER_PW"
clearAuthCacheOnCluster "edge" $NUMBER_EDGES "$USER_NAME" "$USER_PW"
