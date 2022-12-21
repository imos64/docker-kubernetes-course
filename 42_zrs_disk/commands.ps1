# resources: https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/

# 0. Setup demo environment

# Variables
$AKS_RG="rg-aks-az"
$AKS_NAME="aks-cluster"

# Create and connect to AKS cluster
az group create --name $AKS_RG --location westeurope

az aks create --name $AKS_NAME `
              --resource-group $AKS_RG `
              --node-count 3 `
              --zones 1 2 3 

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes

# 1. Deploy statefulset, service and configmap

kubectl apply -f .
# configmap/mysql created
# service/mysql created
# service/mysql-read created
# statefulset.apps/mysql created
# storageclass.storage.k8s.io/managed-csi-zrs created

kubectl get sts,pod,svc,pv,pvc
# NAME                     READY   AGE
# statefulset.apps/mysql   3/3     4m7s

# NAME          READY   STATUS    RESTARTS   AGE
# pod/mysql-0   2/2     Running   0          4m7s
# pod/mysql-1   2/2     Running   0          3m14s
# pod/mysql-2   2/2     Running   0          2m19s

# NAME                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
# service/kubernetes   ClusterIP   10.0.0.1      <none>        443/TCP    88m
# service/mysql        ClusterIP   None          <none>        3306/TCP   4m7s
# service/mysql-read   ClusterIP   10.0.99.145   <none>        3306/TCP   4m7s

# NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
# persistentvolume/pvc-276393bc-81a5-42e6-ab8e-3e29a3385f7c   10Gi       RWO            Delete           Bound    default/data-mysql-0   managed-csi             4m4s
# persistentvolume/pvc-e55cdf98-a35e-4067-8d9f-b630c10bbfbd   10Gi       RWO            Delete           Bound    default/data-mysql-1   managed-csi             3m12s
# persistentvolume/pvc-ea2055ff-5b7b-4d8d-9eae-e61450c9b5ce   10Gi       RWO            Delete           Bound    default/data-mysql-2   managed-csi             2m17s

# NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# persistentvolumeclaim/data-mysql-0   Bound    pvc-276393bc-81a5-42e6-ab8e-3e29a3385f7c   10Gi       RWO            managed-csi    4m7s
# persistentvolumeclaim/data-mysql-1   Bound    pvc-e55cdf98-a35e-4067-8d9f-b630c10bbfbd   10Gi       RWO            managed-csi    3m14s
# persistentvolumeclaim/data-mysql-2   Bound    pvc-ea2055ff-5b7b-4d8d-9eae-e61450c9b5ce   10Gi       RWO            managed-csi    2m19s

# 2. Insert data into th main database

# You can send test queries to the primary MySQL server (hostname mysql-0.mysql) 
# by running a temporary container with the mysql:5.7 image and running the mysql client binary.
kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- `
  mysql -h mysql-0.mysql -e "
    CREATE DATABASE test; 
    CREATE TABLE test.messages (message VARCHAR(250)); 
    INSERT INTO test.messages VALUES ('hello');
"
# pod "mysql-client" deleted

# Cloning existing data

# when a new Pod joins the set as a replica, it must assume the primary MySQL server might already have data on it.
# The second init container, named clone-mysql, performs a clone operation on a replica Pod the first time 
# it starts up on an empty PersistentVolume. That means it copies all existing data from another running Pod, 
# so its local state is consistent enough to begin replicating from the primary server.
# MySQL itself does not provide a mechanism to do this, 
# so the example uses a popular open-source tool called Percona XtraBackup. 
# During the clone, the source MySQL server might suffer reduced performance. 
# To minimize impact on the primary MySQL server, the script instructs each Pod to clone from the Pod whose ordinal index is one lower.
# This works because the StatefulSet controller always ensures Pod N is Ready before starting Pod N+1.

# Starting replication

# After the init containers complete successfully, the regular containers run. 
# The MySQL Pods consist of a mysql container that runs the actual mysqld server, 
# and an xtrabackup container that acts as a sidecar.
# The xtrabackup sidecar looks at the cloned data files and determines if it's necessary to initialize MySQL replication on the replica. 
# If so, it waits for mysqld to be ready and then executes commands with replication parameters extracted from the XtraBackup clone files.
# Replicas look for the primary server at its stable DNS name (mysql-0.mysql), 
# they automatically find the primary server even if it gets a new Pod IP due to being rescheduled.

# 3. Test hostname mysql-read to send test queries to any server that reports being Ready:

kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- `
  mysql -h mysql-read -e "
    SELECT * FROM test.messages
"
# +---------+
# | message |
# +---------+
# | hello   |
# +---------+
# pod "mysql-client" deleted

# 4. Read data from a specific replica

kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- `
  mysql -h mysql-2.mysql -e "SELECT * FROM test.messages"
#   +---------+
#   | message |
#   +---------+
#   | hello   |
#   +---------+
#   pod "mysql-client" deleted

# To demonstrate that the mysql-read Service distributes connections across servers, you can run SELECT @@server_id in a loop:

kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- `
  bash -ic "while sleep 1; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
#   If you don't see a command prompt, try pressing enter.
# #   +-------------+---------------------+
# #   | @@server_id | NOW()               |
# #   +-------------+---------------------+
# #   |         102 | 2022-12-21 14:34:09 |
# #   +-------------+---------------------+
# #   +-------------+---------------------+
# #   | @@server_id | NOW()               |
# #   +-------------+---------------------+
# #   |         100 | 2022-12-21 14:34:10 |
# #   +-------------+---------------------+
# #   +-------------+---------------------+
# #   | @@server_id | NOW()               |
# #   +-------------+---------------------+
# #   |         101 | 2022-12-21 14:34:11 |
# #   +-------------+---------------------+

# let us have some fun! Let us break things and see what kubernetes will do!

# Break the Readiness probe

The readiness probe for the mysql container runs the command mysql -h 127.0.0.1 -e 'SELECT 1' to make sure the server is up and able to execute queries.

One way to force this readiness probe to fail is to break that command:

# let us see what will happen to the storage (PV) and StatefulSet instance when 