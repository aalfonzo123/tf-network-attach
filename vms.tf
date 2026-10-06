# ==============================================================================
# CONSUMER VM B (IN CONSUMER SUBNET B)
# ==============================================================================

resource "google_compute_instance" "consumer_vm_b" {
  name         = "consumer-vm-b"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.consumer_subnet_b.id
    network_ip = "10.2.0.10"
  }

  metadata_startup_script = <<EOF
#!/bin/bash
apt-get update
apt-get install -y python3

cat << 'PYEOF' > /opt/consumer_b_server.py
import http.server
import json
import socket
import urllib.request

class SimpleHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/healthz':
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
            return

        ext_ip = "unknown"
        try:
            req = urllib.request.urlopen("https://api.ipify.org/", timeout=5)
            ext_ip = req.read().decode('utf-8').strip()
        except Exception as e:
            ext_ip = f"error: {str(e)}"

        response = {
            "status": "success",
            "message": "Hello from consumer-vm-b!",
            "hostname": socket.gethostname(),
            "vm": "consumer-vm-b",
            "my-external-ip": ext_ip
        }
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', 8080), SimpleHTTPRequestHandler)
    print("Consumer B HTTP server starting on port 8080...")
    server.serve_forever()
PYEOF

cat << 'SERVICEEOF' > /etc/systemd/system/consumer-b.service
[Unit]
Description=Consumer B HTTP Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/consumer_b_server.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable consumer-b
systemctl start consumer-b
EOF
}

# ==============================================================================
# PRODUCER VM (IN PRODUCER SUBNET & ATTACHED TO CONSUMER SUBNET B NETWORK ATTACHMENT)
# ==============================================================================

resource "google_compute_instance" "producer_vm" {
  name         = "producer-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # Primary Interface in Producer VPC
  network_interface {
    subnetwork = google_compute_subnetwork.producer_subnet.id
    network_ip = "10.100.0.10"
  }

  # Secondary Interface via PSC Network Attachment into Consumer Subnet B
  network_interface {
    network_attachment = google_compute_network_attachment.attachment_b.id
  }

  metadata_startup_script = <<EOF
#!/bin/bash
apt-get update
apt-get install -y python3

cat << 'PYEOF' > /opt/producer_server.py
import http.server
import urllib.request
import json
import socket

CONSUMER_B_URL = "http://10.2.0.10:8080"

class ProducerHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/healthz':
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
            return

        consumer_b_data = {}
        try:
            req = urllib.request.urlopen(CONSUMER_B_URL, timeout=5)
            raw_data = req.read().decode('utf-8')
            consumer_b_data = json.loads(raw_data)
        except Exception as e:
            consumer_b_data = {"error": f"Failed to reach consumer-vm-b: {str(e)}"}

        response = {
            "status": "success",
            "message": "producer-vm successfully processed request and queried consumer-vm-b via PSC Network Attachment!",
            "producer_hostname": socket.gethostname(),
            "consumer_b_response": consumer_b_data
        }
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', 8080), ProducerHTTPRequestHandler)
    print("Producer HTTP server starting on port 8080...")
    server.serve_forever()
PYEOF

cat << 'SERVICEEOF' > /etc/systemd/system/producer.service
[Unit]
Description=Producer HTTP Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/producer_server.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable producer
systemctl start producer
EOF
}

# ==============================================================================
# CONSUMER VM A (IN CONSUMER SUBNET A)
# ==============================================================================

resource "google_compute_instance" "consumer_vm_a" {
  name         = "consumer-vm-a"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.consumer_subnet_a.id
    network_ip = "10.1.0.10"
  }

  metadata_startup_script = <<EOF
#!/bin/bash
apt-get update
apt-get install -y python3

cat << 'PYEOF' > /opt/consumer_a_client.py
import urllib.request
import json
import sys

PSC_ENDPOINT_IP = "${google_compute_address.psc_endpoint_ip.address}"
URL = f"http://{PSC_ENDPOINT_IP}:8080"

print(f"==================================================")
print(f"Triggering call from consumer-vm-a to PSC Endpoint: {URL}")
print(f"==================================================")

try:
    req = urllib.request.urlopen(URL, timeout=10)
    data = req.read().decode('utf-8')
    parsed = json.loads(data)
    print("SUCCESS! Full response payload:")
    print(json.dumps(parsed, indent=2))
except Exception as e:
    print(f"ERROR: Failed to call PSC endpoint: {e}")
    sys.exit(1)
PYEOF

chmod +x /opt/consumer_a_client.py
EOF
}
