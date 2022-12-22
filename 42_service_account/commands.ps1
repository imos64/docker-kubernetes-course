# 0. setup demo environment

# variables
$AKS_RG="rg-aks-az"
$AKS_NAME="aks-cluster"

# create and connect to AKS cluster
az group create --name $AKS_RG --location westeurope

az aks create --name $AKS_NAME `
              --resource-group $AKS_RG `
              --node-count 3 `
              --zones 1 2 3 

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes

# 1. deploy statefulset, service and webapp
