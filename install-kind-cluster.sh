#!/bin/bash

#!/bin/bash
set -e

echo "🧼 重新安裝 Docker..."
sudo apt-get update
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

echo "✅ 驗證 Docker 是否能執行 container..."
docker run hello-world

echo "⬇️ 安裝 kind..."
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

echo "⬇️ 安裝 kubectl（v1.27.3）..."
curl -LO "https://dl.k8s.io/release/v1.27.3/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "✅ Docker / Kind / Kubectl 安裝完成"


echo "✅ 建立 kind cluster 設定檔..."
cat <<EOF > kind-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    image: kindest/node:v1.27.3
  - role: worker
    image: kindest/node:v1.27.3
    labels:
      role: infra
  - role: worker
    image: kindest/node:v1.27.3
    labels:
      role: app
  - role: worker
    image: kindest/node:v1.27.3
    labels:
      role: app
kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    cgroupDriver: systemd
EOF

echo "✅ 建立 kind cluster..."
kind create cluster --name dynasafe-cluster --config kind-cluster-config.yaml

echo "⏳ 等待節點準備中..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "✅ 節點狀態如下："
kubectl get nodes -o wide

echo "✅ Kind Cluster 建立完成！"