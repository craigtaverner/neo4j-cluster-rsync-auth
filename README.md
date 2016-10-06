# Cluster synchronisation of neo4j native security

Since Neo4j 2.2 there has been support for native users in the auth file at data/dbms/auth. When working with a cluster, it is necessary to copy this file to all cluster instances to have the same username/password data on all instances. Edits to the auth file also required restarting all instances to realize the changes in the servers.

In Neo4j 3.1 many new features have been added. The community version now has procedures for editing the native users file (creating and deleting users and setting passwords). Getting these changes across a cluster still requires manual copying, and restarting servers. However, in the enterprise version there are many more security features that improve both the security capability and the cluster support. In enterprise you can also assign users to roles and control their access rights more carefully. These new capabilities are described in detail on the Neo4j 3.1 operation manual. The one feature we will discuss here is the ability for the server to reload from disk any changed auth or roles file every five seconds. By itself, this does not sound like much. It implies the ability to edit the files from outside the server and have those edits reflected in the security behavior in the server, which might be of interest to some IT management processes.

But for clusters it does allow for a very basic form of automated synchronisation of security information across the cluster. External scripts can copy the auth and roles files around the cluster whenever they are changed, and the server will reload the changes. Note that the concurrency checks done here are based on a last edit wins approach, so you will still need to be careful about allowing administrators on multiple instances to edit at the same time, if you want to be sure about which edit actually wins.

This also means that you could solve cluster security synchronization in two ways, one client connecting to all servers and updating their security data, or server-side synchronization by copying the security files.

This project contains scripts to demonstrate one way of doing the server-side synchronization.

_Note: This is not production code, and is made available for example use or demonstration use only

## Download Neo4j 3.1

The scripts were tested on neo4j-enterprise-3.1.0-BETA1, and so you should download neo4j-enterprise-3.1.0-BETA1-unix.tar.gz

## Installing a local Neo4j cluster

First get the scripts and make a template installation of neo4j in the scripts directory:

```
git clone git@github.com:craigtaverner/neo4j-cluster-rsync-auth.git
cd neo4j-cluster-rsync-auth
cp ~/Downloads/neo4j-enterprise-3.1.0-BETA1-unix.tar.gz .
tar xzf neo4j-enterprise-3.1.0-BETA1-unix.tar.gz
```

Then set some environment variables the scripts can use to manage the cluster:

```
export NEO4J_VERSION="3.1.0-BETA1"
export NEO4J_PASSWORD="abc"
export NUMBER_CORES=3
export NUMBER_EDGES=0
```

Now setup the cluster:

```
install.sh
```

This will copy from the template previously extracted to the number of core servers defined. The administrator password will be set, the cluster instances configured with different port numbers for all instances, and then the script will wait for all servers to come up before exiting.

Some of the individual parts of this process can be run separately using commands like: `stop.sh`, `start.sh`, `wait.sh`, `clear.sh` and `configure.sh`. All these commands will run on all instances in the cluster.

## Setting up rsync and crontab

The previous section outlines how to get a running cluster. However, if you add users to one instance, they will not be available on the others. You could also add different users to different instances, and perhaps there are clusters for which that is desirable. However, should you wish to have all security files synchronized across the cluster, you need to setup scripts for cluster rsync.
