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
```

Now setup the cluster:

```
install.sh
```

This will copy from the template previously extracted to the number of core servers defined. The administrator password will be set, the cluster instances configured with different port numbers for all instances, and then the script will wait for all servers to come up before exiting.

Some of the individual parts of this process can be run separately using commands like: `stop.sh`, `start.sh`, `wait.sh`, `clear.sh` and `configure.sh`. All these commands will run on all instances in the cluster.

## Setting up rsync and crontab

The previous section outlines how to get a running cluster. However, if you add users to one instance, they will not be available on the others. You could also add different users to different instances, and perhaps there are clusters for which that is desirable. However, should you wish to have all security files synchronized across the cluster, you need to setup scripts for cluster rsync.

Two files need to be added to the installations of each of the instances:

* conf/cluster.config
* bin/rsync_auth.sh

The easiest way to add these for the cluster configured above is to run the command:

```
configure_rsync.sh
```

However, it is useful to know what these files contain and what they do, so the following manual instructions can be used to set this up for any cluster. Also, the process of setting up the pre-shared public keys is not automated by this command, so make sure you complete that step manually.

### Create cluster.config

This config file contains the settings for all members of the cluster. It will be read by the rsync_auth.sh script to copy files around the cluster. It can be setup on one instance and then copied to all others. The local instance should also be listed for symmetry.

The format is a space separated, three column format, where the columns are:

* unique name for the instance
* ssh-user@host format for ssh access to console of instance
* path on the host to the installation of the instance

For example, here is a config setting that is a 6 core config with 3 cores on each of two hosts:

```
craig_1    craig@172.16.13.129               /Users/craig/Downloads/3.1-cluster/core_1
craig_2    craig@172.16.13.129               /Users/craig/Downloads/3.1-cluster/core_2
craig_3    craig@172.16.13.129               /Users/craig/Downloads/3.1-cluster/core_3
olivia_1   oliviaytterbrink@172.16.13.22     /Users/oliviaytterbrink/dev/hackathon/core_1
olivia_2   oliviaytterbrink@172.16.13.22     /Users/oliviaytterbrink/dev/hackathon/core_2
olivia_3   oliviaytterbrink@172.16.13.22     /Users/oliviaytterbrink/dev/hackathon/core_3
```

Create this file in one instance conf directory and then copy to all instances. This can be done even after the instances are started, because the rsync script does not interact directly with the cluster.

### Install rsync_auth.sh script

Copy the supplied rsync_auth.sh script into the bin directory of each cluster installation. If you ran the `configure_rsync.sh` script above, this has been done for you on the local cluster.

### Setup ssh with public keys

On all hosts, make sure the user that is running the server has generated an ssh keypair. This can be done with the command:

```
ssh-keygen -t dsa
```

The copy the public key to all hosts, including the local host, installing the public key in the .ssh/authorized_keys file of a user with write access to the remote neo4j installation. For the local cluster installation performed above, it is sufficient to run the following command:

```
cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

If you are running a neo4j cluster across multiple hosts, take that into account when copying keys. Also, remember to never copy private keys around, only public keys. If in doubt, refer to documentation on ssh, or on public-private key cryptography.

### Setup crontab

On each host running an instance, you need to setup crontab with lines for each instance to synchronise. For example, the crontab on the local host setup with a cluster using the scripts above will have entries like this:

```
* * * * *    /Users/craig/Downloads/3.1-cluster/core_1/bin/rsync_auth.sh
* * * * *    /Users/craig/Downloads/3.1-cluster/core_2/bin/rsync_auth.sh
* * * * *    /Users/craig/Downloads/3.1-cluster/core_3/bin/rsync_auth.sh
```

These entries indicate that once every minute, the script in each installation will be run. It will copy the local installations version of the auth and roles files to all other servers using the settings in the cluster.config file. The actual rsync command run requires that you have setup pre-shared public keys for ssh to work. It also uses the `-u` option to ensure the file is only copied if there are local changes more recent than the remote file. For reference, here is the line in the script that does the real work:

```
rsync -auv $dbms/ $address:$path/data/dbms
```
