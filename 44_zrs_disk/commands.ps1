# Using Azure Disk in AKS

## Introduction

## 0. Setup demo environment

# Variables
$AKS_RG="rg-aks-zrs"
$AKS_NAME="aks-cluster"

# Create and connect to AKS cluster
az group create --name $AKS_RG --location westeurope

az aks create --name $AKS_NAME --resource-group $AKS_RG --node-count 3 --zones 1 2 3 

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes

## 1. Deploy a sample deployment with PVC (Azure Disk with zrs)

kubectl apply -f zrs-disk-deploy.yaml

# Verify resources deployed successfully

kubectl get pods,pv,pvc

# Check the worker node for the pod

kubectl get pods -o wide

kubectl get nodes

# Worker Nodes are deployed into the 3 Azure Availability Zones

Set-Alias -Name grep -Value select-string # if using powershell

kubectl describe nodes | grep topology.kubernetes.io/zone

# Check the Availability Zone for our pod

# Get Pod's node name
$NODE_NAME=$(kubectl get pods -l app=nginx-zrs -o jsonpath='{.items[0].spec.nodeName}')
echo $NODE_NAME

kubectl get nodes $NODE_NAME -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'

kubectl describe nodes $NODE_NAME | grep topology.kubernetes.io/zone

## 2. Simulate node failure (delete node)

kubectl delete node $NODE_NAME

# Check the pod will be rescheduled in another node

kubectl get pods -o wide

# Thanks to using ZRS Disk, our pod could be resheduled to another availability zone.

# Check the availability zone for that node

# Get Pod's new node name
$NODE_NAME=$(kubectl get pods -l app=nginx-zrs -o jsonpath='{.items[0].spec.nodeName}')
echo $NODE_NAME

kubectl describe nodes $NODE_NAME | grep topology.kubernetes.io/zone

# Let's check the data inside the Disk

kubectl exec 