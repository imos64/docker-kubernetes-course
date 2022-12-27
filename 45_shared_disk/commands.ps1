# https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/failover/README.md

# Using Azure Disk in AKS

## Introduction

## 0. Setup demo environment

# Variables
$AKS_RG="rg-aks-shared-disk"
$AKS_NAME="aks-cluster"

# Create and connect to AKS cluster
az group create --name $AKS_RG --location westeurope

az aks create --name $AKS_NAME --resource-group $AKS_RG --node-count 3 --zones 1 2 3 --kubernetes-version "1.25.2" --network-plugin azure

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes

## 1. Deploy a sample deployment with StorageClass and PVC (ZRS Shared Azure Disk)

kubectl apply -f zrs-shared-disk-pvc-sc.yaml,zrs-shared-disk-deploy.yaml
# storageclass.storage.k8s.io/zrs-shared-managed-csi created
# persistentvolumeclaim/zrs-shared-pvc-azuredisk created
# deployment.apps/deployment-azuredisk created

# Verify resources deployed successfully

kubectl get pods,pv,pvc

kubectl exec -it deployment-sharedisk-7454978bc6-xh7jp bash

dd if=/dev/zero of=/dev/sdx bs=1024k count=100
# 100+0 records in
# 100+0 records out
# 104857600 bytes (105 MB, 100 MiB) copied, 0.0502999 s, 2.1 GB/s
