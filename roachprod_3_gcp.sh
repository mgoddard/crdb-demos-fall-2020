#!/bin/bash

# n2-highcpu-16 requires 2 local SSD
vm_type="n2-highcpu-16"

export CLUSTER1="${USER}-va"
roachprod create ${CLUSTER1} --clouds gce --gce-zones us-east4-a -n 3 --local-ssd --gce-machine-type $vm_type --gce-local-ssd-count 2

export CLUSTER2="${USER}-sc"
roachprod create ${CLUSTER2} --clouds gce --gce-zones us-east1-b -n 3 --local-ssd --gce-machine-type $vm_type --gce-local-ssd-count 2

# Below is an example of output from both of the "create" operations:
: <<'_COMMENT'

Refreshing DNS entries...
mgoddard-va: [gce] 12h14m12s remaining
  mgoddard-va-0001	mgoddard-va-0001.us-east4-a.cockroach-ephemeral	10.150.0.86	34.86.101.152
  mgoddard-va-0002	mgoddard-va-0002.us-east4-a.cockroach-ephemeral	10.150.0.89	35.236.194.166
  mgoddard-va-0003	mgoddard-va-0003.us-east4-a.cockroach-ephemeral	10.150.0.90	34.86.90.211
mgoddard-va: waiting for nodes to start 3/3
generating ssh key 1/1

_COMMENT

# Add gcloud SSH key. Optional for most commands, but some require it.
ssh-add ~/.ssh/google_compute_engine

# FOR PROD VERSION
version="v20.1.5"
roachprod stage $CLUSTER1 release $version
roachprod stage $CLUSTER2 release $version

# FOR THE ALPHA: After doing this put, the file will be in ~ubuntu/ on each node
roachprod put ${CLUSTER1} cockroach-v20.2.0-alpha.3.linux-amd64/cockroach cockroach
roachprod put ${CLUSTER2} cockroach-v20.2.0-alpha.3.linux-amd64/cockroach cockroach

# SSH into the 0001 nodea
m1=34.86.101.152
m2=34.74.151.75

ssh $m1 # Repeat for $m2

# Using each of the IPs in the second to last column, create file "hosts.all" with these IPs.
# Run this: cat | perl -ne 'print "$1\n" if /ephemeral\s+((?:\d+\.){3}\d+)\s+((?:\d+\.){3}\d+)+$/'
# and then past that blob of output from above into the terminal.

# Download orgalorg for || SSH/SCP
file="https://github.com/reconquest/orgalorg/releases/download/1.0/orgalorg_1.0_linux_amd64.tar.gz"
curl -L $file | tar xzvf -
sudo mv orgalorg /usr/local/bin/

# Copy the two required GIS libs.
for file in libgeos.so libgeos_c.so ; do curl -OL https://storage.googleapis.com/crl-goddard-util/$file ; done

# Copy those into /usr/local/lib/ on all hosts (the sudo is implied the the "-x" flag):
orgalorg -o ./hosts.all -x -er /usr/local/lib -U libgeos*

# Start a cluster.
# ./cockroach start --insecure --store=path=/mnt/data1/cockroach --log-dir=/home/ubuntu/logs --cache=25% --max-sql-memory=25% \
#   --port=26257 --http-port=26258 --locality=cloud=gce,region=us-east4,zone=us-east4-a --join=34.86.101.152:26257 --advertise-host=10.150.0.86
roachprod start $CLUSTER1
roachprod start $CLUSTER2

# See the locality info
select crdb_internal.locality_value('region'), crdb_internal.locality_value('zone');

# On the first node in $CLUSTER2, install the cdc-sink binary
ssh $m2
curl -OL https://storage.googleapis.com/crl-goddard-util/cdc-sink
chmod +x cdc-sink

# Configure everything per https://github.com/cockroachdb/cdc-sink

# On receiving end ($m2):
./cdc-sink --port 30004 --conn postgresql://root@localhost:26257/defaultdb?sslmode=disable --config='[{"endpoint": "osm.sql", "source_table": "osm", "destination_database": "defaultdb", "destination_table": "osm"}]'

# Ref. https://github.com/cockroachdb/cockroach/pull/45552
SET CLUSTER SETTING rocksdb.min_wal_sync_interval = '250us';

# On source end (replace the IP number with setting for $m2):
SET CLUSTER SETTING kv.rangefeed.enabled = true;
CREATE CHANGEFEED FOR TABLE osm INTO 'experimental-http://10.142.0.101:30004/osm.sql' WITH updated,resolved;

# Check the status of the changefeed
select * from [show jobs]
where job_type = 'CHANGEFEED';

# Cancel the job associated with a changefeed.
CANCEL JOB 588264558508670977;

# Check the admin UI.
roachprod admin --open ${CLUSTER1}:2

# ... Finally:
roachprod destroy $CLUSTER1
roachprod destroy $CLUSTER2

