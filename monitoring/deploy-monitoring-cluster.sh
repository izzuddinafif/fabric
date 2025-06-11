#!/bin/bash

# Deploy comprehensive monitoring across all nodes
echo "🚀 Deploying monitoring stack across 3-node Fabric cluster..."

# Deploy on orderer (already running)
echo "✅ Orderer monitoring already active"

# Deploy node-exporter + cadvisor on org1
echo "📊 Deploying monitoring on org1 (10.104.0.2)..."
ssh fabricadmin@10.104.0.2 << 'EOF'
# Stop existing if any
docker stop node-exporter cadvisor 2>/dev/null || true
docker rm node-exporter cadvisor 2>/dev/null || true

# Deploy node-exporter
docker run -d \
  --name node-exporter \
  --restart unless-stopped \
  -p 9100:9100 \
  --network host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  prom/node-exporter:v1.6.0 \
  --path.procfs=/host/proc \
  --path.rootfs=/rootfs \
  --path.sysfs=/host/sys \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($|/)'

# Deploy cadvisor  
docker run -d \
  --name cadvisor \
  --restart unless-stopped \
  -p 8080:8080 \
  --privileged \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:rw \
  -v /sys:/sys:ro \
  -v /var/lib/docker:/var/lib/docker:ro \
  -v /dev/disk/:/dev/disk:ro \
  --device /dev/kmsg:/dev/kmsg \
  gcr.io/cadvisor/cadvisor:v0.47.0

echo "✅ Org1 monitoring deployed"
EOF

# Deploy node-exporter + cadvisor on org2  
echo "📊 Deploying monitoring on org2 (10.104.0.4)..."
ssh fabricadmin@10.104.0.4 << 'EOF'
# Stop existing if any
docker stop node-exporter cadvisor 2>/dev/null || true
docker rm node-exporter cadvisor 2>/dev/null || true

# Deploy node-exporter
docker run -d \
  --name node-exporter \
  --restart unless-stopped \
  -p 9100:9100 \
  --network host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  prom/node-exporter:v1.6.0 \
  --path.procfs=/host/proc \
  --path.rootfs=/rootfs \
  --path.sysfs=/host/sys \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($|/)'

# Deploy cadvisor
docker run -d \
  --name cadvisor \
  --restart unless-stopped \
  -p 8080:8080 \
  --privileged \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:rw \
  -v /sys:/sys:ro \
  -v /var/lib/docker:/var/lib/docker:ro \
  -v /dev/disk/:/dev/disk:ro \
  --device /dev/kmsg:/dev/kmsg \
  gcr.io/cadvisor/cadvisor:v0.47.0

echo "✅ Org2 monitoring deployed"
EOF

echo "🔄 Restarting Prometheus to pick up all targets..."
cd /home/fabricadmin/fabric/monitoring
docker-compose -f docker-compose-monitoring.yaml restart prometheus

sleep 15

echo "🎯 Monitoring deployment complete!"
echo "📊 Access dashboards:"
echo "   Grafana: http://localhost:3000 (admin/zakatadmin123)"
echo "   Prometheus: http://localhost:9090"
echo "   Pushgateway: http://localhost:9091"

echo "📈 Checking target status..."
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job):\(.labels.instance) - \(.health)"'