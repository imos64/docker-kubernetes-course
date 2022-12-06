
# create an AKS cluster
RG="rg-aks-demo"
AKS="aks-cluster"

az group create -n $RG -l westeurope

az aks create -g $RG -n $AKS \
              --kubernetes-version "1.25.2" \
              --enable-managed-identity \
              --node-count 2 \
              --network-plugin azure \
              --enable-addons azure-keyvault-secrets-provider \
              --enable-secret-rotation \
              --rotation-poll-interval 5m

az aks get-credentials --name $AKS -g $RG --overwrite-existing

# verify connection to the cluster
kubectl get nodes

az aks show -n $AKS -g $RG --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv
# 47744279-8b5e-4c77-9102-7c6c1874587a
# we won't use this (default) managed identity, we'll use our own

# create Keyvault resource

AKV_NAME="akvaksapp07"
az keyvault create -n $AKV_NAME -g $RG
az keyvault secret set --vault-name $AKV_NAME --name MySecretPassword --value "P@ssw0rd123!"