#!/bin/bash

# Delete network if exists
echo "Delete network if exists"
docker network rm redisnet1 
docker network rm redisnet2 
docker network rm redisnet3 


# Create new bridge networks
echo "Create new bridge networks"
docker network create redisnet1 --subnet=172.18.0.0/16 --gateway=172.18.0.1
docker network create redisnet2 --subnet=172.19.0.0/16 --gateway=172.19.0.1
docker network create redisnet3 --subnet=172.20.0.0/16 --gateway=172.20.0.1

# Run Redis Enterprise
docker run -d --cap-add sys_resource --name redis01 -h redis01 -p 8443:8443 -p 9443:9443 -p 12000:12000 --network=redisnet1 --ip=172.18.0.2 redislabs/redis
docker run -d --cap-add sys_resource --name redis02 -h redis03 -p 8444:8443 -p 9444:9443 -p 12001:12000 --network=redisnet2 --ip=172.19.0.2 redislabs/redis
docker run -d --cap-add sys_resource --name redis03 -h redis03 -p 8445:8443 -p 9445:9443 -p 12002:12000 --network=redisnet3 --ip=172.20.0.2 redislabs/redis

# Wait until the containers are created
echo "Wait until the containers are created.."
sleep 10

# Create clusters
echo "Create clusters"
docker exec -it redis01 /opt/redislabs/bin/rladmin cluster create name cluster1.local username user@test.com password test
docker exec -it redis02 /opt/redislabs/bin/rladmin cluster create name cluster2.local username user@test.com password test
docker exec -it redis03 /opt/redislabs/bin/rladmin cluster create name cluster3.local username user@test.com password test

# Connect 3 nodes with networks
echo "Connect 3 nodes with networks"
docker network connect redisnet1 redis02
docker network connect redisnet1 redis03
docker network connect redisnet2 redis01
docker network connect redisnet2 redis03
docker network connect redisnet3 redis01
docker network connect redisnet3 redis02


# Create CRDB using 3 clusters
echo "Create CRDB using 3 clusters"
docker exec -it redis01 /opt/redislabs/bin/crdb-cli crdb create --name mycrdb --memory-size 512mb --port 12000 --replication false --shards-count 1 --instance fqdn=cluster1.local,username=user@test.com,password=test --instance fqdn=cluster2.local,username=user@test.com,password=test --instance fqdn=cluster3.local,username=user@test.com,password=test
