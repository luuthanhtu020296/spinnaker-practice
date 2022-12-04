
#! /bin/bash

export HOME=/home/spinnaker



#create namespace

eksctl create cluster --name=eks-spinnaker --nodes=2 --region=us-west-2 --write-kubeconfig=false
aws eks update-kubeconfig --name eks-spinnaker --region us-west-2 --alias eks-spinnaker
kubectl create namespace spinnaker
hal config provider kubernetes enable
kubectl config use-context eks-spinnaker
CONTEXT=$(kubectl config current-context --kubeconfig "/home/spinnaker/.kube/config")
kubectl apply --context $CONTEXT -f service-account.yaml
TOKEN=$(kubectl get secret --context $CONTEXT \
   $(kubectl get serviceaccount spinnaker-service-account \
       --context $CONTEXT \
       -n spinnaker \
       -o jsonpath='{.secrets[0].name}') \
   -n spinnaker \
   -o jsonpath='{.data.token}' | base64 --decode)
kubectl config set-credentials ${CONTEXT}-token-user --token $TOKEN
kubectl config set-context $CONTEXT --user ${CONTEXT}-token-user
hal config provider kubernetes account add eks-spinnaker --kubeconfig-file "/home/spinnaker/.kube/config" --context $(kubectl config current-context --kubeconfig "/home/spinnaker/.kube/config")
hal config features edit --artifacts true
hal config deploy edit --type distributed --account-name eks-spinnaker
hal config storage s3 edit \
 --access-key-id $ACCESS_KEY \
 --secret-access-key $SECRET_KEY --region us-west-2
hal config storage edit --type s3
export VERSION=1.29.0
hal config version edit --version $VERSION
sudo chmod 777 /home/spinnaker/.kube/config
hal -l DEBUG deploy apply
# eksctl delete cluster --name eks-spinnaker
export NAMESPACE=spinnaker
# Expose Gate and Deck
kubectl -n ${NAMESPACE} expose service spin-gate --type LoadBalancer \
  --port 80 --target-port 8084 --name spin-gate-public

kubectl -n ${NAMESPACE} expose service spin-deck --type LoadBalancer \
  --port 80 --target-port 9000 --name spin-deck-public

export API_URL=$(kubectl -n $NAMESPACE get svc spin-gate-public \
 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

export UI_URL=$(kubectl -n $NAMESPACE get svc spin-deck-public \
 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Configure the URL for Gate
hal config security api edit --override-base-url http://${API_URL}

# Configure the URL for Deck
hal config security ui edit --override-base-url http://${UI_URL}

# Apply your changes to Spinnaker
hal deploy apply
kubectl -n $NAMESPACE get svc spin-deck-public -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'


