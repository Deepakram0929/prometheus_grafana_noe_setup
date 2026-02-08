# Download Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz
tar -xf prometheus-2.43.0.linux-amd64.tar.gz

# Move binaries
sudo mv prometheus-2.43.0.linux-amd64/prometheus \
        prometheus-2.43.0.linux-amd64/promtool \
        /usr/local/bin/

# Create directories
sudo mkdir -p /etc/prometheus /var/lib/prometheus

# Move console files (IMPORTANT)
sudo mv prometheus-2.43.0.linux-amd64/consoles /etc/prometheus
sudo mv prometheus-2.43.0.linux-amd64/console_libraries /etc/prometheus

#sudo vim /etc/hosts 
#3.101.56.72 worker-1
#54.193.223.22 worker-2

# Prometheus Configuration

sudo tee /etc/prometheus/prometheus.yml <<EOF
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

# Prometheus User & Permissions

sudo useradd -rs /bin/false prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Prometheus systemd Service (UPDATED)

sudo tee /etc/systemd/system/prometheus.service <<EOF
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

# Start Prometheus

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus --no-pager

