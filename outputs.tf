output "psc_endpoint_ip" {
  description = "The internal IP address of the PSC Endpoint in consumer-subnet-a"
  value       = google_compute_address.psc_endpoint_ip.address
}

output "consumer_vm_a_internal_ip" {
  description = "Internal IP address of consumer-vm-a"
  value       = google_compute_instance.consumer_vm_a.network_interface[0].network_ip
}

output "consumer_vm_b_internal_ip" {
  description = "Internal IP address of consumer-vm-b"
  value       = google_compute_instance.consumer_vm_b.network_interface[0].network_ip
}

output "producer_vm_primary_ip" {
  description = "Primary internal IP address of producer-vm in producer-subnet"
  value       = google_compute_instance.producer_vm.network_interface[0].network_ip
}

output "network_attachment_id" {
  description = "ID of the Network Attachment in consumer-vpc"
  value       = google_compute_network_attachment.attachment_b.id
}

output "consumer_nat_external_ip" {
  description = "Static external IP address of consumer-nat"
  value       = google_compute_address.consumer_nat_ip.address
}

output "test_instructions" {
  description = "Commands to verify the PSC Network Attachment demo"
  value       = <<EOF

To verify the end-to-end Private Service Connect flow:

1. SSH into consumer-vm-a via IAP:
   gcloud compute ssh consumer-vm-a --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap

2. Run the test script on consumer-vm-a:
   python3 /opt/consumer_a_client.py

Expected Flow:
  consumer-vm-a ---> PSC Endpoint (${google_compute_address.psc_endpoint_ip.address}:8080)
                ---> Service Attachment (producer-vpc)
                ---> Internal Load Balancer
                ---> producer-vm
                ---> PSC Network Attachment (nic1 into consumer-subnet-b)
                ---> consumer-vm-b (10.2.0.10:8080)
EOF
}
