#!/bin/bash

source common.sh

function configureLDAPProvider() {
  prefix=$1 ; shift
  typeset -i i END # Let's be explicit
  let END=$1 ; shift
  provider=$1
  ldap_config="neo4j-$provider.conf"
  if [ -f "$ldap_config" ] ; then
    for ((i=1;i<=END;++i)); do
      dir="${prefix}_${i}"
      if [ -d "$dir" ] ; then
        conf="$dir/conf/neo4j.conf"
        back="$conf.back"
        if [ ! -f "$back" ] ; then
          cp $conf $back
        fi
        cat $back $ldap_config > temp.conf
        diff temp.conf $conf > /dev/null
        if [ ! "$?" = "0" ] ; then
          cp temp.conf $conf
          echo "Config changed at $conf - restarting $dir"
          $dir/bin/neo4j restart
        else
          echo "$dir already configured for provider=$provider"
        fi
      else
        echo "Directory does not exist: $dir"
      fi
    done
  else
    echo "No such config: $ldap_config"
  fi
}

function configureNativeProvider() {
  prefix=$1 ; shift
  typeset -i i END # Let's be explicit
  let END=$1 ; shift
  for ((i=1;i<=END;++i)); do
    dir="${prefix}_${i}"
    path="$(pwd)/${dir}/data/dbms"
    if [ -d "$dir" ] ; then
      conf="$dir/conf/neo4j.conf"
      back="$conf.back"
      if [ -f "$back" ] ; then
        diff $back $conf > /dev/null
        if [ ! "$?" = "0" ] ; then
          cp $back $conf
          echo "Config changed at $conf - restarting $dir"
          $dir/bin/neo4j restart
        else
          echo "$dir already configured for provider=native"
        fi
        cp $back $conf
      fi
    else
      echo "Directory does not exist: $dir"
    fi
  done
}

case "$1" in
AD)
  configureLDAPProvider "core" $NUMBER_CORES "AD"
  configureLDAPProvider "edge" $NUMBER_EDGES "AD"
  ;;
OpenLDAP)
  configureLDAPProvider "core" $NUMBER_CORES "OpenLDAP"
  configureLDAPProvider "edge" $NUMBER_EDGES "OpenLDAP"
  ;;
*)
  configureNativeProvider "core" $NUMBER_CORES
  configureNativeProvider "edge" $NUMBER_EDGES
  ;;
esac
