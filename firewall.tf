# ==============================================================================
# PRODUCER VPC FIREWALL RULES
# ==============================================================================

# Allow HTTP 8080 from Producer Subnet & PSC NAT Subnet (GCP Health Checks & PSC Ingress)
resource "google_compute_firewall" "producer_allow_http" {
  name    = "producer-allow-http"
  network = google_compute_network.producer_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [
    "10.0.0.0/8",    # Covers producer subnet & PSC NAT ranges
    "35.191.0.0/16", # GCP Health Check probes
    "130.211.0.0/22" # GCP Health Check probes
  ]
}

# Allow SSH / IAP and Ping/ICMP in Producer VPC
resource "google_compute_firewall" "producer_allow_mgmt" {
  name    = "producer-allow-mgmt"
  network = google_compute_network.producer_vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0", "35.235.240.0/20"] # 35.235.240.0/20 is GCP IAP
}

# ==============================================================================
# CONSUMER VPC FIREWALL RULES
# ==============================================================================

# Allow HTTP 8080 on consumer-vm-b from producer-vm (via PSC Network Attachment in consumer-subnet-b)
resource "google_compute_firewall" "consumer_allow_http" {
  name    = "consumer-allow-http"
  network = google_compute_network.consumer_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [
    var.consumer_subnet_a_cidr,
    var.consumer_subnet_b_cidr
  ]
}

# Allow SSH / IAP and Ping/ICMP in Consumer VPC
resource "google_compute_firewall" "consumer_allow_mgmt" {
  name    = "consumer-allow-mgmt"
  network = google_compute_network.consumer_vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0", "35.235.240.0/20"]
}
