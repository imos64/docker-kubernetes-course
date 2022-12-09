## Using HTTPS in Kubernetes Ingress and Pods

Create an AKS cluster

```bash
AKS_RG="rg-aks-demo-tls"
AKS_NAME="aks-cluster"

az group create -n $AKS_RG -l westeurope

az aks create -g $AKS_RG -n $AKS_NAME \
              --kubernetes-version "1.25.2" \
              --enable-managed-identity \
              --node-count 2 \
              --network-plugin azure

az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

kubectl get nodes

NAMESPACE_APP="dotnet-app"

kubectl create namespace $NAMESPACE_APP
```

Create TLS certificate

```bash
APP_CERT_NAME="app-tls-cert"

SERVICE_NAME="app-svc"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -out "${APP_CERT_NAME}.crt" \
    -keyout "${APP_CERT_NAME}.key" \
    -subj "/CN=$SERVICE_NAME.$NAMESPACE_APP.svc.cluster.local/O=aks-ingress-tls" \
    -addext "subjectAltName=DNS:$SERVICE_NAME.$NAMESPACE_APP.svc.cluster.local"

openssl pkcs12 -export -in "${APP_CERT_NAME}.crt" -inkey "${APP_CERT_NAME}.key" -out "${APP_CERT_NAME}.pfx"
```

Save TLS certificate into Secret generic object

```bash
APP_SECRET_TLS="app-tls-cert-secret"

kubectl create secret generic $APP_SECRET_TLS --from-file="${APP_CERT_NAME}.pfx" --namespace $NAMESPACE_APP
# secret/app-tls-cert-secret created

kubectl describe secret $APP_SECRET_TLS --namespace $NAMESPACE_APP
# Name:         app-tls-cert-secret
# Namespace:    dotnet-app
# Labels:       <none>
# Annotations:  <none>

# Type:  kubernetes.io/tls

# Data
# ====
# tls.crt:  1326 bytes
# tls.key:  1704 bytes
```

Create sample deployment object that uses TLS certificate from secret to cnfigure HTTPS.
The configuration for the TLS certificate depends on the platform/app. 
Nodejs, Java and others might define a different set of env variables to configure certificate.

```bash
cat <<EOF >app-deploy.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: demo-app
  name: $SERVICE_NAME
spec:
  ports:
  - port: 443
    protocol: TCP
    targetPort: 443
  selector:
    app: demo-app
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: demo-app
  name: demo-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      restartPolicy: Always
      volumes:
      - name: demo-app-tls
        secret:
          secretName: $APP_SECRET_TLS
      containers:
      - name: demo-app
        image: mcr.microsoft.com/dotnet/samples:aspnetapp
        ports:
        - containerPort: 443
        volumeMounts:
        - name: demo-app-tls
          mountPath: /secrets/tls-cert
          readOnly: true
        env:
        - name: ASPNETCORE_Kestrel__Certificates__Default__Password
          value: ""
        - name: ASPNETCORE_Kestrel__Certificates__Default__Path
          value: /secrets/tls-cert/$APP_CERT_NAME.pfx
        - name: ASPNETCORE_URLS
          value: "https://+;http://+" # "https://+:443;http://+:80"
        - name: ASPNETCORE_HTTPS_PORT
          value: "443"
EOF

kubectl apply -f app-deploy.yaml -n $NAMESPACE_APP
# service/app-svc created
# deployment.apps/demo-app created

kubectl get pods,svc -n $NAMESPACE_APP
# NAME                            READY   STATUS    RESTARTS   AGE
# pod/demo-app-69b8774746-9v8mm   1/1     Running   0          2m8s

# NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# service/app-svc   ClusterIP   10.0.179.173   <none>        443/TCP   2m9s
```

Verify HTTPS is working

```bash
kubectl run nginx --image=nginx
kubectl exec -it nginx -- curl -v -k https://app-svc.dotnet-app.svc.cluster.local
# * Trying 10.0.154.220:443...
# * Connected to app-svc.dotnet-app.svc.cluster.local (10.0.154.220) port 443 (#0)
# * ALPN, offering h2
# * ALPN, offering http/1.1
# * successfully set certificate verify locations:
# *  CAfile: /etc/ssl/certs/ca-certificates.crt
# *  CApath: /etc/ssl/certs
# * TLSv1.3 (OUT), TLS handshake, Client hello (1):
# * TLSv1.3 (IN), TLS handshake, Server hello (2):
# * TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
# * TLSv1.3 (IN), TLS handshake, Certificate (11):
# * TLSv1.3 (IN), TLS handshake, CERT verify (15):
# * TLSv1.3 (IN), TLS handshake, Finished (20):
# * TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
# * TLSv1.3 (OUT), TLS handshake, Finished (20):
# * SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
# * ALPN, server accepted to use h2
# * Server certificate:
# *  subject: CN=app-svc.dotnet-app.svc.cluster.local; O=aks-ingress-tls
# *  start date: Nov 27 12:44:43 2022 GMT
# *  expire date: Nov 27 12:44:43 2023 GMT
# *  issuer: CN=app-svc.dotnet-app.svc.cluster.local; O=aks-ingress-tls
# *  SSL certificate verify result: self signed certificate (18), continuing anyway.
# ...
```