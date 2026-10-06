# ==============================================================================
# PRODUCER VPC & SUBNETS
# ==============================================================================

resource "google_compute_network" "producer_vpc" {
  name                    = "producer-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "producer_subnet" {
  name          = "producer-subnet"
  ip_cidr_range = var.producer_cidr
  region        = var.region
  network       = google_compute_network.producer_vpc.id
}

# NAT Subnetwork required for Private Service Connect Service Attachment
resource "google_compute_subnetwork" "psc_nat_subnet" {
  name          = "producer-psc-nat-subnet"
  ip_cidr_range = var.psc_nat_cidr
  region        = var.region
  network       = google_compute_network.producer_vpc.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

# ==============================================================================
# CONSUMER VPC & SUBNETS
# ==============================================================================

resource "google_compute_network" "consumer_vpc" {
  name                    = "consumer-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "consumer_subnet_a" {
  name          = "consumer-subnet-a"
  ip_cidr_range = var.consumer_subnet_a_cidr
  region        = var.region
  network       = google_compute_network.consumer_vpc.id
}

resource "google_compute_subnetwork" "consumer_subnet_b" {
  name          = "consumer-subnet-b"
  ip_cidr_range = var.consumer_subnet_b_cidr
  region        = var.region
  network       = google_compute_network.consumer_vpc.id
}

# ==============================================================================
# PSC NETWORK ATTACHMENT (PRODUCER EGRESS INTO CONSUMER SUBNET B)
# ==============================================================================

resource "google_compute_network_attachment" "attachment_b" {
  name                  = "network-attachment-b"
  region                = var.region
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.consumer_subnet_b.id]
}

# ==============================================================================
# PRODUCER ILB & SERVICE ATTACHMENT (CONSUMER INGRESS TO PRODUCER VM)
# ==============================================================================

resource "google_compute_instance_group" "producer_umig" {
  name      = "producer-umig"
  zone      = var.zone
  instances = [google_compute_instance.producer_vm.self_link]

  named_port {
    name = "http"
    port = 8080
  }
}

resource "google_compute_region_health_check" "producer_hc" {
  name               = "producer-hc"
  region             = var.region
  check_interval_sec = 5
  timeout_sec        = 5

  http_health_check {
    port         = 8080
    request_path = "/healthz"
  }
}

resource "google_compute_region_backend_service" "producer_backend" {
  name                  = "producer-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_region_health_check.producer_hc.id]

  backend {
    group          = google_compute_instance_group.producer_umig.id
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_forwarding_rule" "producer_ilb" {
  name                  = "producer-ilb"
  region                = var.region
  network               = google_compute_network.producer_vpc.id
  subnetwork            = google_compute_subnetwork.producer_subnet.id
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.producer_backend.id
  ports                 = ["8080"]
}

resource "google_compute_service_attachment" "producer_service_attachment" {
  name                  = "producer-service-attachment"
  region                = var.region
  enable_proxy_protocol = false
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = [google_compute_subnetwork.psc_nat_subnet.id]
  target_service        = google_compute_forwarding_rule.producer_ilb.id
}

# ==============================================================================
# CONSUMER PSC ENDPOINT (FORWARDING RULE IN CONSUMER SUBNET A)
# ==============================================================================

resource "google_compute_address" "psc_endpoint_ip" {
  name         = "psc-endpoint-ip"
  subnetwork   = google_compute_subnetwork.consumer_subnet_a.id
  address_type = "INTERNAL"
  region       = var.region
}

resource "google_compute_forwarding_rule" "psc_endpoint_a" {
  name                  = "psc-endpoint-a"
  region                = var.region
  network               = google_compute_network.consumer_vpc.id
  subnetwork            = google_compute_subnetwork.consumer_subnet_a.id
  ip_address            = google_compute_address.psc_endpoint_ip.id
  target                = google_compute_service_attachment.producer_service_attachment.id
  load_balancing_scheme = ""
}

# ==============================================================================
# CLOUD NAT FOR OUTBOUND INTERNET ACCESS (WITHOUT EXTERNAL IPS ON VMS)
# ==============================================================================

resource "google_compute_router" "producer_router" {
  name    = "producer-router"
  region  = var.region
  network = google_compute_network.producer_vpc.id
}

resource "google_compute_router_nat" "producer_nat" {
  name                               = "producer-nat"
  router                             = google_compute_router.producer_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_address" "consumer_nat_ip" {
  name   = "consumer-nat-ip"
  region = var.region
}

resource "google_compute_router" "consumer_router" {
  name    = "consumer-router"
  region  = var.region
  network = google_compute_network.consumer_vpc.id
}

resource "google_compute_router_nat" "consumer_nat" {
  name                               = "consumer-nat"
  router                             = google_compute_router.consumer_router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.consumer_nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
