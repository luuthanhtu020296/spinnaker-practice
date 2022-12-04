#!/bin/bash#

sudo -su
export HOME=/home/spinnaker
# install docker

# sudo apt update -y
# sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# sudo apt update -y
# sudo apt install -y docker-ce
# sudo usermod -aG docker ${USER}
# sudo chmod 777 /var/run/docker.sock
# install kubenetenes

sudo apt install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip awscliv2.zip
sudo ./aws/install
# curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator
# chmod +x ./aws-iam-authenticator
# mkdir -p $HOME/bin && cp ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$HOME/bin:$PATH
# echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
#install hal
# Download and configure Halyard
curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh

sudo useradd halyard

sudo bash InstallHalyard.sh



#create namespace
sudo aws configure set aws_access_key_id $ACCESS_KEY
sudo aws configure set aws_secret_access_key $SECRET_KEY
sudo aws configure set default.region us-west-2
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
export VERSION=1.19.2
hal config version edit --version $VERSION
hal -l DEBUG deploy apply
# eksctl delete cluster --name eks-spinnaker

