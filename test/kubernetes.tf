terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


# Creating a Security Group
resource "aws_security_group" "proj-sg" {
  name        = "proj-sg"
  description = "Enable web traffic for the project"
  ingress {
    description = "HTTPS traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "proj-sg1"
  }
}


# Creating an Ubuntu EC2 instance
resource "aws_instance" "proj-instance" {
  ami               = "ami-0729e439b6769d6ab"
  instance_type     = "t2.medium"
  availability_zone = "us-east-1b"
  key_name          = "devopsnew"
  vpc_security_group_ids = [aws_security_group.proj-sg.id]
  user_data = <<-EOF
#!/bin/bash
#Docker Installation 
apt-get update
apt-get install docker.io -y
echo '{"exec-opts": ["native.cgroupdriver=systemd"]}' >> /etc/docker/daemon.json
sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker
#Making Docker socket available---- only in new version 
git clone https://github.com/Mirantis/cri-dockerd.git
wget https://storage.googleapis.com/golang/getgo/installer_linux
chmod +x ./installer_linux
./installer_linux
source ~/.bash_profile
cd cri-dockerd
mkdir bin
go get && go build -o bin/cri-dockerd
mkdir -p /usr/local/bin
install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
cp -a packaging/systemd/* /etc/systemd/system
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket
# Install kubelet kubeadm kubectl on all nodes 
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl



#Only Master Node Configuration 
#######################################
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all --cri-socket=unix:///var/run/containerd/containerd.sock
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl get no
kubectl get po --all-namespaces
kubectl get po --all-namespaces -o wide
kubectl get no
kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master-

#Helm installation

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm -y
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard
kubectl create serviceaccount dashboard -n default
kubectl create clusterrolebinding dashboard-admin -n default --clusterrole=cluster-admin --serviceaccount=default:dashboard
echo "apiVersion: v1
kind: Secret
metadata:
  name: dashboard
  annotations:
    kubernetes.io/service-account.name: dashboard
type: kubernetes.io/service-account-token
" >serviceaccount.yaml
kubectl apply -f serviceaccount.yaml
kubectl get svc kubernetes-dashboard -o yaml >dashboardsvc.yaml
sed -i 's/type: ClusterIP/type: NodePort/g' dashboardsvc.yaml
kubectl apply -f dashboardsvc.yaml
kubectl describe svc kubernetes-dashboard |grep NodePort |grep https |awk '{print $2"://nodeip:"$NF}'|awk -F "/TCP" '{print "Use below link for Browse your Dashboard   "   $1}'
EOF
  tags = {
    Name = "DebopsK8s"
  }
}


