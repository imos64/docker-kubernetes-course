# Using Azure Blob Fuse with Managed Identity in AKS

## Introduction

## 0. Setup demo environment

# Variables
$AKS_RG="rg-aks-cluster"
$AKS_NAME="aks-cluster"
$STORAGE_ACCOUNT_NAME="storage4aks013"
$IDENTITY_NAME="identity-storage-account"

# Create and connect to AKS cluster
az group create --name $AKS_RG --location westeurope

az aks create --name $AKS_NAME --resource-group $AKS_RG --node-count 3 --zones 1 2 3 --kubernetes-version "1.25.4" --network-plugin azure  --enable-blob-driver

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes

# Verify the blob driver (DaemonSet) was installed

Set-Alias -Name grep -Value select-string # if using powershell
kubectl get pods -n kube-system | grep csi

# Create Storage Account

az storage account create -n $STORAGE_ACCOUNT_NAME -g $AKS_RG -l westeurope --sku Standard_ZRS --kind BlockBlobStorage

# Create a container

az storage container create --account-name $STORAGE_ACCOUNT_NAME -n container01

# Create Identity

az identity create -g $AKS_RG -n $IDENTITY_NAME

# Assign RBAC role

$IDENTITY_CLIENT_ID=$(az identity show -g $AKS_RG -n $IDENTITY_NAME --query "clientId" -o tsv)
$STORAGE_ACCOUNT_ID=$(az storage account show -n $STORAGE_ACCOUNT_NAME --query id)
az role assignment create --assignee $IDENTITY_CLIENT_ID `
        --role "Contributor" `
        --scope $STORAGE_ACCOUNT_ID

az role assignment create --assignee $IDENTITY_CLIENT_ID `
        --role "Storage Blob Data Owner" `
        --scope $STORAGE_ACCOUNT_ID

# Attach Managed Identity to AKS VMSS

$IDENTITY_ID=$(az identity show -g $AKS_RG -n $IDENTITY_NAME --query "id" -o tsv)

$NODE_RG=$(az aks show -g $AKS_RG -n $AKS_NAME --query nodeResourceGroup -o tsv)

$VMSS_NAME=$(az vmss list -g $NODE_RG --query [0].name -o tsv)

az vmss identity assign -g $NODE_RG -n $VMSS_NAME --identities $IDENTITY_ID

# verify the Blob storage mounted

kubectl exec -it nginx-blob -- df -h

# src: https://github.com/qxsch/Azure-Aks/tree/master/aks-blobfuse-mi