#!/bin/bash

SCRIPT_DIR=$(dirname $0)
neo4j=$(dirname $SCRIPT_DIR)

if [ -n "$1" ] ; then
  neo4j=$1
fi

if [ -z "$neo4j" ] ; then
  echo "usage: ./rsync_auth.sh path-to-neo4j-installation"
  exit -1
fi

CLUSTER_CONFIG="$neo4j/conf/cluster.config"

if [ ! -f "$CLUSTER_CONFIG" ] ; then
  echo "No such file: $CLUSTER_CONFIG"
  exit -1
fi

if [ ! -d "$neo4j" ] ; then
  echo "No such directory: $neo4j"
  exit -1
fi

dbms="$neo4j/data/dbms"

if [ ! -d "$dbms" ] ; then
  echo "No such directory: $dbms"
  exit -1
fi

function rsync_auth
{
  server=$1
  address=$2
  path=$3

  echo "RSyncing to cluster member $server"
  echo "    Address:   $address"
  echo "    Path:      $path"
  echo -e "\n"

  rsync -auv $dbms/ $address:$path/data/dbms

  echo -e "\n"
}

for line in `cat $CLUSTER_CONFIG | sed -e $'s/ /SEPARATOR/g' | grep -v '^#'`
do
  args="${line//SEPARATOR/ }"
  rsync_auth $args
done
