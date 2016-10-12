#!/bin/bash

if [ -z "$NEO4J_VERSION" ] ; then
  echo "No NEO4J_VERSION set"
  exit -1
fi

if [ -z "$NEO4J_PASSWORD" ] ; then
  echo "No NEO4J_PASSWORD set"
  exit -1
fi

export NEO4J_TEMPLATE="neo4j-enterprise-$NEO4J_VERSION"

if [ ! -d "$NEO4J_TEMPLATE" ] ; then
  echo "No Neo4j template directory found: $NEO4J_TEMPLATE"
  exit -1
fi

if [ -z "$NUMBER_CORES" ] ; then
  export NUMBER_CORES=3
  echo "Setting NUMBER_CORES to default: $NUMBER_CORES"
fi

if [ -z "$NUMBER_EDGES" ] ; then
  export NUMBER_EDGES=0
  echo "Setting NUMBER_EDGES to default: $NUMBER_EDGES"
fi

max_cores=9
max_edges=9
min_cores=1
min_edges=0

if [ $NUMBER_CORES -gt $max_cores ] ; then
  echo "Number of cores set too high: $NUMBER_CORES"
  export NUMBER_CORES=$max_cores
  echo "Setting NUMBER_CORES to max: $NUMBER_CORES"
fi

if [ $NUMBER_CORES -lt $min_cores ] ; then
  echo "Number of cores set too low: $NUMBER_CORES"
  export NUMBER_CORES=$min_cores
  echo "Setting NUMBER_CORES to min: $NUMBER_CORES"
fi

if [ $NUMBER_EDGES -gt $max_edges ] ; then
  echo "Number of edges set too high: $NUMBER_EDGES"
  export NUMBER_EDGES=$max_edges
  echo "Setting NUMBER_EDGES to max: $NUMBER_EDGES"
fi

if [ $NUMBER_EDGES -lt $min_edges ] ; then
  echo "Number of edges set too low: $NUMBER_EDGES"
  export NUMBER_EDGES=$min_edges
  echo "Setting NUMBER_EDGES to min: $NUMBER_EDGES"
fi

function deleteKnownHosts() {
  if [ -f "$HOME/.neo4j/known_hosts" ] ; then
    rm -f $HOME/.neo4j/known_hosts
  fi
}

function installCluster() {
  prefix=$1
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    if [ -d "$dir" ] ; then
      echo "Directory already exists: $dir"
      echo "Stopping previous installation"
      $dir/bin/neo4j stop
      echo "Deleting previous installation"
      rm -Rf $dir
    fi
    echo "Installing $dir"
    mkdir -p $dir
    cp -a $NEO4J_TEMPLATE/* $dir/
    $dir/bin/neo4j-admin set-initial-password $NEO4J_PASSWORD
  done
}

function deleteCluster() {
  prefix=$1
  if [ -d "${prefix}_1" ] ; then
    for dir in ${prefix}_? ; do
      if [ -d "$dir" ] ; then
        echo "Found installation at $dir - stopping and deleting it"
        if [ -x "$dir/bin/neo4j" ] ; then
          $dir/bin/neo4j stop
        fi
        rm -Rf $dir
      else
        echo "Not a directory: $dir"
      fi
    done
  else
    echo "No ${prefix} installations found"
  fi
}

function printConfigFromPatch() {
  conf_patch=$1
  echo -e "\tConfig settings changed:"
  for line in `grep -v 'neo4j.conf' $conf_patch | grep -e '^\+'`
  do
    echo -e "\t\t${line:1}"
  done
}

function makeDiscoveryMembersConfig() {
  prefix="core"
  members=""
  typeset -i i END # Let's be explicit
  let END=$NUMBER_CORES
  for ((i=1;i<=END;++i)); do
    port="500$i"
    if [ -n "$members" ] ; then
      members="${members},"
    fi
    members="${members}localhost:$port"
  done
  echo $members
}

function makeAdvertisedAddress() {
  prefix=$1
  index=$2
  if [ -n "$ADVERTISED_HOSTNAME" ] ; then
    echo "$ADVERTISED_HOSTNAME" \
      | sed -e "s/PREFIX/$prefix/" \
      | sed -e "s/INDEX/$index/"
  else
    echo "localhost"
  fi
}

function configureCluster() {
  members=$(makeDiscoveryMembersConfig)
  prefix=$1
  ce_mode=$(echo "$prefix" | tr '[:lower:]' '[:upper:]')
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    if [ -d "$dir" ] ; then
      echo "Configuring $dir"
      mkdir -p $dir/conf
      cp -a $NEO4J_TEMPLATE/conf/neo4j.conf $dir/conf/
      advertised_address=$(makeAdvertisedAddress $prefix $i)
      conf_patch="neo4j.conf.${prefix}_${i}.patch"
      echo -e "\tMaking patch for ${prefix}_${i} in $conf_patch"
      cat neo4j.conf.${prefix}.patch \
        | sed -e "s/^\+\(.*\)1$/\+\1$i/" \
        | sed -e "s/^\+dbms.connectors.default_advertised_address=localhost$/\+dbms.connectors.default_advertised_address=$advertised_address/" \
        | sed -e "s/^\+core_edge.expected_core_cluster_size=3$/\+core_edge.expected_core_cluster_size=$NUMBER_CORES/" \
        | sed -e "s/^\+core_edge.initial_discovery_members=.*$/\+core_edge.initial_discovery_members=$members/" \
        > $conf_patch
      if [ -f "$conf_patch" ] ; then
        rm -f "$dir/conf/neo4j.conf.back"
        echo -e "\tPatching $dir/conf/neo4j.conf"
        patch -s -i $conf_patch $dir/conf/neo4j.conf
        printConfigFromPatch $conf_patch
      else
        echo "No such file: $conf_patch"
      fi
    else
      echo "Directory does not exist: $dir"
    fi
  done
}

function initClusterConfigLocal() {
  cp -a cluster.config cluster.config.local
  rm -f crontab.local
  touch crontab.local
}

function addToClusterConfigLocal() {
  logfile="$(pwd)/cluster_rsync.log"
  prefix=$1
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    path="$(pwd)/${dir}"
    address="${USER}@localhost"
    if [ -d "$dir" ] ; then
      echo "Making cluster config for $dir using address $address and path $path"
      echo "$dir    $address    $path" >> cluster.config.local
      echo "* * * * *    $path/bin/rsync_auth.sh >> $logfile" >> crontab.local
    else
      echo "Directory does not exist: $dir"
    fi
  done
}

function configureClusterRSync() {
  prefix=$1
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    path="$(pwd)/${dir}"
    if [ -d "$dir" ] ; then
      echo "Configuring cluster rsync for installation at $dir"
      mkdir -p $dir/conf
      cp -a cluster.config.local $dir/conf/cluster.config
      cp -a rsync_auth.sh $dir/bin/
    else
      echo "Directory does not exist: $dir"
    fi
  done
}

function installClusterRSyncCrontab() {
  logfile="$(pwd)/cluster_rsync.log"
  if [ -f "$logfile.backup" ] ; then
    tar czf "$logfile.backup.tgz" "$logfile.backup"
  fi
  if [ -f "$logfile" ] ; then
    mv "$logfile" "$logfile.backup"
  fi
  if [ -f "crontab.local" ] ; then
    echo "Installing crontab"
    crontab crontab.local
  else
    echo "No crontab.local found"
  fi
  crontab -l
}

function clearCluster() {
  prefix=$1
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    if [ -d "$dir" ] ; then
      echo "Clearing logs and graph.db for $dir"
      rm -Rf $dir/logs/* $dir/data/databases/graph.db
    else
      echo "Directory does not exist: $dir"
    fi
  done
}

function waitForCluster() {
  prefix=$1
  typeset -i i END # Let's be explicit
  let END=$2
  for ((i=1;i<=END;++i)); do
    if [ "$prefix" = "core" ] ; then
      http_port="748${i}"
    else
      http_port="749${i}"
    fi
    end="$((SECONDS+20))"
    echo -en "\tWaiting for response at port $http_port "
    rc=0
    while true; do
        [[ "200" = "$(curl --silent --write-out %{http_code} --output /dev/null http://localhost:$http_port)" ]] && break
        [[ "${SECONDS}" -ge "${end}" ]] && rc=1 && break
        echo -n "."
        sleep 1
    done
    echo
    if [ $rc ] ; then
      echo -e "\tInstance ${prefix}_${i} is up"
    else
      echo -e "\tTimed out waiting for ${prefix}_${i} to respond"
    fi
  done
}

function clusterCommand() {
  command=$1
  prefix=$2
  typeset -i i END # Let's be explicit
  let END=$3
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    if [ -x "$dir/bin/neo4j" ] ; then
      echo "S${command:1}ing Neo4j $NEO4J_VERSION in $dir"
      $dir/bin/neo4j $command
    else
      echo "Command is not executable: $dir/bin/neo4j"
    fi
  done
}

function startCluster() {
  clusterCommand "start" $@
}

function stopCluster() {
  clusterCommand "stop" $@
}

function restartCluster() {
  clusterCommand "restart" $@
}
