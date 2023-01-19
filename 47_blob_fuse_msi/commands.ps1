# Using Azure Blob Fuse with Managed Identity in AKS

## Introduction

## 0. Setup demo environment

# Variables
$AKS_RG="rg-aks-cluster"
$AKS_NAME="aks-cluster"
$STORAGE_ACCOUNT_NAME="storage4aks013"
$CONTAINER_NAME="container01"
$IDENTITY_NAME="identity-storage-account"

# Create and connect to AKS cluster
az group create --name $AKS_RG --location westeurope

az aks create --name $AKS_NAME --resource-group $AKS_RG --node-count 3 --zones 1 2 3 --kubernetes-version "1.25.4" --network-plugin azure  --enable-blob-driver

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes
# NAME                                STATUS   ROLES   AGE   VERSION
# aks-nodepool1-35380384-vmss000000   Ready    agent   66s   v1.25.4
# aks-nodepool1-35380384-vmss000001   Ready    agent   62s   v1.25.4
# aks-nodepool1-35380384-vmss000002   Ready    agent   64s   v1.25.4

# Verify the blob driver (DaemonSet) was installed

Set-Alias -Name grep -Value select-string # if using powershell
kubectl get pods -n kube-system | grep csi
# csi-azuredisk-node-jl665              3/3     Running   0          6m36s
# csi-azuredisk-node-wwxsx              3/3     Running   0          6m34s
# csi-azuredisk-node-z2zmt              3/3     Running   0          6m32s
# csi-azurefile-node-dcgbb              3/3     Running   0          6m34s
# csi-azurefile-node-trgpv              3/3     Running   0          6m32s
# csi-azurefile-node-xrz9r              3/3     Running   0          6m36s
# csi-blob-node-c6v6n                   3/3     Running   0          6m34s
# csi-blob-node-hmssr                   3/3     Running   0          6m32s
# csi-blob-node-wvqcp                   3/3     Running   0          6m36s
# Create Storage Account

az storage account create -n $STORAGE_ACCOUNT_NAME -g $AKS_RG -l westeurope --sku Premium_ZRS --kind BlockBlobStorage

# Create a SA container

az storage container create --account-name $STORAGE_ACCOUNT_NAME -n $CONTAINER_NAME

# upload a file into the SA container

$STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

az storage blob upload `
           --account-name $STORAGE_ACCOUNT_NAME `
           -c $CONTAINER_NAME `
           --name blobfile.html `
           --file blobfile.html `
           --auth-mode key `
           --account-key $STORAGE_ACCOUNT_KEY

# Verify the resources are created on the Azure portal

# Create Managed Identity

az identity create -g $AKS_RG -n $IDENTITY_NAME

# Assign RBAC role

$IDENTITY_CLIENT_ID=$(az identity show -g $AKS_RG -n $IDENTITY_NAME --query "clientId" -o tsv)
$STORAGE_ACCOUNT_ID=$(az storage account show -n $STORAGE_ACCOUNT_NAME --query id)

# az role assignment create --assignee $IDENTITY_CLIENT_ID `
#         --role "Contributor" `
#         --scope $STORAGE_ACCOUNT_ID

az role assignment create --assignee $IDENTITY_CLIENT_ID `
        --role "Storage Blob Data Owner" `
        --scope $STORAGE_ACCOUNT_ID

# Attach Managed Identity to AKS VMSS

$IDENTITY_ID=$(az identity show -g $AKS_RG -n $IDENTITY_NAME --query "id" -o tsv)

$NODE_RG=$(az aks show -g $AKS_RG -n $AKS_NAME --query nodeResourceGroup -o tsv)

$VMSS_NAME=$(az vmss list -g $NODE_RG --query [0].name -o tsv)

az vmss identity assign -g $NODE_RG -n $VMSS_NAME --identities $IDENTITY_ID

# Configure Persistent Volume (PV) with managed identity

@"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-blob
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: azureblob-fuse-premium
  mountOptions:
    - -o allow_other
    - --file-cache-timeout-in-seconds=120
  csi:
    driver: blob.csi.azure.com
    readOnly: false
    volumeHandle: $STORAGE_ACCOUNT_NAME-$CONTAINER_NAME
    volumeAttributes:
      resourceGroup: $AKS_RG
      storageAccount: $STORAGE_ACCOUNT_NAME
      containerName: $CONTAINER_NAME
      # refer to https://github.com/Azure/azure-storage-fuse#environment-variables
      AzureStorageAuthType: msi  # key, sas, msi, spn
      AzureStorageIdentityResourceID: $IDENTITY_ID
"@ > pv-blobfuse.yaml

# Deploy the app

kubectl apply -f pv-blobfuse.yaml -f pvc-blobfuse.yaml -f nginx-pod-blob.yaml
# deployment.apps/nginx-app created
# service/nginx-app created
# persistentvolume/pv-blob created
# persistentvolumeclaim/pvc-blob created

kubectl get pods,svc,pvc,pv
# NAME                             READY   STATUS    RESTARTS   AGE
# pod/nginx-app-55d47d67fd-ppstp   1/1     Running   0          85m

# NAME                 TYPE           CLUSTER-IP   EXTERNAL-IP      PORT(S)        AGE
# service/kubernetes   ClusterIP      10.0.0.1     <none>           443/TCP        102m
# service/nginx-app    LoadBalancer   10.0.17.50   20.234.250.254   80:31990/TCP   85m

# NAME                             STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS             AGE
# persistentvolumeclaim/pvc-blob   Bound    pv-blob   100Gi      RWX            azureblob-fuse-premium   85m

# NAME                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM              STORAGECLASS             REASON   AGE
# persistentvolume/pv-blob   100Gi      RWX            Retain           Bound    default/pvc-blob   azureblob-fuse-premium            85m

# verify the Blob storage mounted

$POD_NAME=$(kubectl get pods -l app=nginx-app -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $POD_NAME -- df -h
# Filesystem      Size  Used Avail Use% Mounted on
# overlay         124G   23G  102G  19% /
# tmpfs            64M     0   64M   0% /dev
# shm              64M     0   64M   0% /dev/shm
# /dev/root       124G   23G  102G  19% /etc/hosts
# blobfuse2       124G   23G  102G  19% /usr/share/nginx/html
# tmpfs           4.5G   12K  4.5G   1% /run/secrets/kubernetes.io/serviceaccount
# tmpfs           3.4G     0  3.4G   0% /proc/acpi
# tmpfs           3.4G     0  3.4G   0% /proc/scsi
# tmpfs           3.4G     0  3.4G   0% /sys/firmware

kubectl exec -it $POD_NAME -- ls /usr/share/nginx/html
# blobfile.html

# Navigate to http://<PUBLIC_SERVICE_IP>/blobfile.html to view web app running the uploaded blobfile.html file.

# Additional resources
# src: https://github.com/qxsch/Azure-Aks/tree/master/aks-blobfuse-mi
# src: https://github.com/kubernetes-sigs/blob-csi-driver/blob/master/docs/driver-parameters.md