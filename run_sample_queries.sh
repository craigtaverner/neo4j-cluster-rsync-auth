#!/bin/bash

source common.sh

USER_NAME=$1
USER_PW=$2
LONG_INDEX=$3

if [ -z "$USER_NAME" ] ; then
  USER_NAME="neo"
  echo "No username provided for running long queries under: defaulting to $USER_NAME"
fi

if [ -z "$USER_PW" ] ; then
  USER_PW="abc"
  echo "No user password provided for running long queries under: defaulting to $USER_PW"
fi

if [ -z "$LONG_INDEX" ] ; then
  LONG_INDEX=1
  echo "No index provided for instance to run very long query on: defaulting to $LONG_INDEX"
fi

function runQueryOn() {
  prefix=$1
  index=$2
  username=$3
  password=$4
  cypher=$5
  if [ -z "$cypher" ] ; then
    duration=$((${index} * 10))
    cypher="CALL test.waitFor('${duration}s')"
  fi
  if [ "$prefix" = "core" ] ; then
    address="bolt://localhost:769$index"
  else
    address="bolt://localhost:760$index"
  fi
  dir="${prefix}_${index}"
  if [ -n "$duration" ] ; then
    meta="{$prefix:'$index',user:'$username',duration:'${duration}s'}"
  else
    meta="{$prefix:'$index',user:'$username'}"
  fi
  if [ -d "$dir" ] ; then
    echo "Running query on $dir at $address as '$username': \"$cypher\""
    rm -f temp.cypher
    echo ":param name '$username'" >> temp.cypher
    echo ":param index '$index'" >> temp.cypher
    echo ":param prefix '$prefix'" >> temp.cypher
    echo ":begin" >> temp.cypher
    echo "CALL dbms.setTXMetaData(${meta});" >> temp.cypher
    echo "${cypher};" >> temp.cypher
    echo ":commit" >> temp.cypher
    cat temp.cypher | $dir/bin/cypher-shell -u "$username" -p "$password" -a "$address" > /dev/null &
  else
    echo "No such directory: $dir"
  fi
}

function runQueriesOnCluster() {
  prefix=$1
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    runQueryOn $prefix $i $3 $4 "$(makeQuery $5 $3)"
  done
}

function makeQuery() {
  duration=$1
  username=$2
  echo "OPTIONAL MATCH (n) WITH '$username' as user, collect(n) as nodes CALL test.waitFor('${duration}s') RETURN 0"
}

runQueriesOnCluster "core" $NUMBER_CORES "$USER_NAME" "$USER_PW" 30
runQueriesOnCluster "edge" $NUMBER_EDGES "$USER_NAME" "$USER_PW" 20

runQueryOn "core" $LONG_INDEX "$USER_NAME" "$USER_PW" "$(makeQuery 120 slow_$USER_NAME)"
