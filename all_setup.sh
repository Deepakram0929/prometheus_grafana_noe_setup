#!/bin/bash
set -e

echo "===== PROMETHEUS + GRAFANA + NODE EXPORTER SETUP STARTED ====="

############################
# PROMETHEUS INSTALLATION
############################

cd /opt

wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz
tar -xf prometheus-2.43.0.linux-amd64.tar.gz

# Move binaries
mv prometheus-2.43.0.linux-amd64/prometheus \
   prometheus-2.43.0.linux-amd64/promtool \
   /usr/local/bin/

# Create directories
mkdir -p /etc/prometheus /var/lib/prometheus

# Move console files
mv prometheus-2.43.0.linux-amd64/consoles /etc/prometheus
mv prometheus-2.43.0.linux-amd64/console_libraries /etc/prometheus

# Cleanup
rm -rf prometheus-2.43.0.linux-amd64*

# Create Prometheus user
id prometheus &>/dev/null || useradd -rs /bin/false prometheus

# Permissions
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

############################
# PROMETHEUS CONFIG
############################

cat <<EOF >/etc/prometheus/prometheus.yml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: prometheus_metrics
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: node_exporter_metrics
    scrape_interval: 5s
    static_configs:
      - targets:
        - localhost:9100
        - worker-1:9100
        - worker-2:9100
EOF

############################
# PROMETHEUS SYSTEMD
############################

cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.listen-address=0.0.0.0:9090 \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries
Restart=always

[Install]
WantedBy=multi-user.target
EOF

############################
# NODE EXPORTER INSTALLATION
############################

cd /opt

wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar -xf node_exporter-1.5.0.linux-amd64.tar.gz

mv node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.5.0.linux-amd64*

# Create node_exporter user
id node_exporter &>/dev/null || useradd -rs /bin/false node_exporter
chown node_exporter:node_exporter /usr/local/bin/node_exporter

############################
# NODE EXPORTER SYSTEMD
############################

cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=0.0.0.0:9100
Restart=always

[Install]
WantedBy=multi-user.target
EOF

############################
# GRAFANA INSTALLATION
############################

wget -q -O gpg.key https://rpm.grafana.com/gpg.key
rpm --import gpg.key

cat <<EOF >/etc/yum.repos.d/grafana.repo
[grafana]
name=Grafana
baseurl=https://rpm.grafana.com
enabled=1
repo_gpgcheck=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
exclude=*beta*
EOF

yum install grafana -y

############################
# FIREWALL RULES
############################

if systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --add-port=9090/tcp
  firewall-cmd --permanent --add-port=9100/tcp
  firewall-cmd --permanent --add-port=3000/tcp
  firewall-cmd --reload
fi

############################
# START SERVICES
############################

systemctl daemon-reload

systemctl enable prometheus node_exporter grafana-server
systemctl restart prometheus node_exporter grafana-server

echo "===== SETUP COMPLETED SUCCESSFULLY ====="
echo "Prometheus : http://<server-ip>:9090"
echo "Grafana    : http://<server-ip>:3000 (admin/admin)"
echo "Node Exp   : http://<node-ip>:9100/metrics"
