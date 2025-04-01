# Dynasafe Kubernetes Monitoring + HPA Lab

## 作業題目

請使用 Kind 建立 Kubernetes 軟體介面監控與 Auto Scaling 系統。

---

## 資料組織構造

```
dynasafe-monitoring-hpa/
├── manifests/
│   ├── kind-cluster-config.yaml
│   ├── metallb-config.yaml
│   ├── prometheus-values.yaml
│   ├── nginx-with-stress.yaml
│   └── hpa.yaml（可選）
├── grafana/
│   ├── docker-compose.yml
│   ├── provisioning/
│   │   ├── datasources/prometheus.yml
│   │   └── dashboards/{*.json, dashboard.yaml}
├── diagrams/
│   └── architecture.png
├── README.md（說明安裝步驟、儀表板意義、如何觀察 CPU throttling）
├── install-kind-cluster.sh (安裝檔)
```

---
## 基本環境安裝

### 1. 安裝 基礎環境
```bash
./install-kind-cluster.sh
```

## MetalLB 安裝

### 1. 安裝 MetalLB Core Components
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

### 2. 啟用 Layer 2 模式 (AddressPool)
1. 檢查 Docker 網樓節點:
```bash
docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}'
```
2. 將找到的 IP 範圍寫入 `metallb-config.yaml`
3. 啟用:
```bash
kubectl apply -f metallb-config.yaml
```

### 3. 限制 speaker 僅部署在 role=infra 的 node
```bash
kubectl -n metallb-system patch daemonset speaker \
  --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"role": "infra"}}]'
```

### 4. 驗證 speaker 位置 & IP 配置
```bash
kubectl -n metallb-system get pods -o wide
```

---

## Prometheus 安裝

### 1. 安裝 Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. 新增 Helm repo
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 3. 安裝 Prometheus Stack
```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml
```

### 4. 檢查部署狀態
```bash
kubectl get pods -n monitoring -o wide
```

### 5. 開啟 Prometheus Web UI (port-forward)
```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090
```
打開: http://localhost:9090

---

## Grafana 安裝

### 1. 查看 Prometheus LoadBalancer IP
```bash
kubectl get svc -n monitoring
```

### 2. 變更 Service 為 LoadBalancer
```bash
kubectl patch svc monitoring-kube-prometheus-prometheus \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'
```

### 3. 寫入 provisioning/datasources/prometheus.yml
```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://<MetalLB_IP>:9090
    isDefault: true
```

### 4. 修改 grafana-storage 權限:
```bash
sudo chown -R 472:472 grafana-storage
```

### 5. 啟動 Grafana
```bash
docker-compose up -d
# or
docker compose up -d
```

### 6. 開啟 Grafana UI
http://localhost:3000

---

## 應用部署 + HPA 壓力測試

### 1. 安裝 metrics-server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 2. 設定 metrics-server 使其可以用於 KIND
```bash
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

### 3. 部署 nginx + stress
```bash
kubectl apply -f nginx-with-stress.yaml
```

### 4. 啟用 HPA
```bash
kubectl autoscale deployment nginx --cpu-percent=50 --min=1 --max=10
```

監控:
```bash
kubectl get hpa -w
```

