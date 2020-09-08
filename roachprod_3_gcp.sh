#!/bin/bash

export CLUSTER1="${USER}-va"
roachprod create ${CLUSTER1} --clouds gce --gce-zones us-east4-a -n 3 --local-ssd

export CLUSTER2="${USER}-sc"
roachprod create ${CLUSTER2} --clouds gce --gce-zones us-east1-b -n 3 --local-ssd

# Below is an example of output from both of the "create" operations:
: <<'_COMMENT'

mgoddard-va: [gce] 12h16m45s remaining
  mgoddard-va-0001	mgoddard-va-0001.us-east4-a.cockroach-ephemeral	10.150.0.63	35.236.194.166
  mgoddard-va-0002	mgoddard-va-0002.us-east4-a.cockroach-ephemeral	10.150.0.43	34.86.254.129
  mgoddard-va-0003	mgoddard-va-0003.us-east4-a.cockroach-ephemeral	10.150.0.98	34.86.251.244
mgoddard-va: waiting for nodes to start 3/3

mgoddard-sc: [gce] 12h15m18s remaining
  mgoddard-sc-0001	mgoddard-sc-0001.us-east1-b.cockroach-ephemeral	10.142.0.23	104.196.167.117
  mgoddard-sc-0002	mgoddard-sc-0002.us-east1-b.cockroach-ephemeral	10.142.0.26	34.75.173.251
  mgoddard-sc-0003	mgoddard-sc-0003.us-east1-b.cockroach-ephemeral	10.142.0.22	35.231.56.245
mgoddard-sc: waiting for nodes to start 3/3

_COMMENT

# Add gcloud SSH key. Optional for most commands, but some require it.
ssh-add ~/.ssh/google_compute_engine

# After doing this put, the file will be in ~ubuntu/ on each node
roachprod put ${CLUSTER1} cockroach-v20.2.0-alpha.3.linux-amd64/cockroach cockroach
roachprod put ${CLUSTER2} cockroach-v20.2.0-alpha.3.linux-amd64/cockroach cockroach

# SSH into the 0001 nodea
m1=35.236.194.166
m2=104.196.167.117

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
roachprod start ${CLUSTER1}
roachprod start ${CLUSTER2}

# On the first node in $CLUSTER2, install the cdc-sink binary
ssh $m2
curl -OL https://storage.googleapis.com/crl-goddard-util/cdc-sink
chmod +x cdc-sink

# Configure everything per https://github.com/cockroachdb/cdc-sink

# On receiving end ($m2):
cdc-sink --port 30004 --conn postgresql://root@localhost:26257/defaultdb?sslmode=disable --config='[{"endpoint": "osm.sql", "source_table": "osm", "destination_database": "defaultdb", "destination_table": "osm"}]'

# On source end (replace the IP number with setting for $m2):
SET CLUSTER SETTING kv.rangefeed.enabled = true
CREATE CHANGEFEED FOR TABLE osm INTO 'experimental-http://10.142.0.23:30004/osm.sql' WITH updated,resolved;

# Check the admin UI.
roachprod admin --open ${CLUSTER1}:1

# Later ...
roachprod destroy $CLUSTER1
roachprod destroy $CLUSTER2

