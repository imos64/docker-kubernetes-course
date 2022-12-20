# 1. setup demo environment

# variables
$AKS_RG="rg-aks-upgrade"
$AKS_NAME="aks-cluster"

# create and connect to cluster
az group create --name $AKS_RG --location westeurope

az aks create --name $AKS_NAME `
              --resource-group $AKS_RG `
              --node-count 3

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes

kubectl apply -f .

kubectl get pod,svc,pv,pvc
# NAME                                     READY   STATUS    RESTARTS   AGE
# pod/db-statefulset-0                     1/1     Running   0          14m
# pod/db-statefulset-1                     1/1     Running   0          8m25s
# pod/db-statefulset-2                     1/1     Running   0          8m7s
# pod/webapp-deployment-7d7cd859c7-j9d6c   1/1     Running   0          6m20s

# NAME                           TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)          AGE
# service/kubernetes             ClusterIP      10.0.0.1     <none>         443/TCP          4h8m
# service/mssql-service          ClusterIP      None         <none>         1433/TCP         14m
# service/mssql-service-public   LoadBalancer   10.0.28.41   20.93.170.43   1433:30110/TCP   11m
# service/webapp-service         LoadBalancer   10.0.1.241   20.76.26.128   80:31812/TCP     59m

# NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                           STORAGECLASS   REASON   AGE
# persistentvolume/pvc-1fbfe744-ecaa-4c77-a693-4a7b919d79d9   1Gi        RWO            Delete           Bound    default/data-db-statefulset-1   managed-csi             8m23s
# persistentvolume/pvc-bc4e0268-ada2-490b-8b88-9009120a07db   1Gi        RWO            Delete           Bound    default/data-db-statefulset-0   managed-csi             26m
# persistentvolume/pvc-c6fb483c-7b56-4094-bfd2-3e29cbf79a9c   1Gi        RWO            Delete           Bound    default/data-db-statefulset-2   managed-csi             8m5s

# NAME                                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# persistentvolumeclaim/data-db-statefulset-0   Bound    pvc-bc4e0268-ada2-490b-8b88-9009120a07db   1Gi        RWO            managed-csi    26m
# persistentvolumeclaim/data-db-statefulset-1   Bound    pvc-1fbfe744-ecaa-4c77-a693-4a7b919d79d9   1Gi        RWO            managed-csi    8m26s
# persistentvolumeclaim/data-db-statefulset-2   Bound    pvc-c6fb483c-7b56-4094-bfd2-3e29cbf79a9c   1Gi        RWO            managed-csi    8m8s

kubectl run nginx --image=nginx
kubectl exec nginx -it -- apt-get update
kubectl exec nginx -it -- apt-get install dnsutils

kubectl exec nginx -it -- nslookup mssql-service
# Server:         10.0.0.10
# Address:        10.0.0.10#53

# Name:   mssql-service.default.svc.cluster.local
# Address: 10.244.1.22
# Name:   mssql-service.default.svc.cluster.local
# Address: 10.244.2.17
# Name:   mssql-service.default.svc.cluster.local
# Address: 10.244.1.23

kubectl exec nginx -it -- nslookup db-statefulset-0.mssql-service
# Server:         10.0.0.10
# Address:        10.0.0.10#53

# Name:   db-statefulset-0.mssql-service.default.svc.cluster.local
# Address: 10.244.1.22