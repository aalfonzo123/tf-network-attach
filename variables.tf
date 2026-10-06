variable "project_id" {
  type        = string
  description = "The GCP Project ID where resources will be created"
}

variable "region" {
  type        = string
  description = "GCP Region for all resources"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP Zone for Compute Engine instances"
  default     = "us-central1-a"
}

variable "producer_cidr" {
  type        = string
  description = "CIDR range for producer-subnet"
  default     = "10.100.0.0/24"
}

variable "psc_nat_cidr" {
  type        = string
  description = "CIDR range for PSC NAT subnetwork in producer-vpc"
  default     = "10.100.1.0/24"
}

variable "consumer_subnet_a_cidr" {
  type        = string
  description = "CIDR range for consumer-subnet-a"
  default     = "10.1.0.0/24"
}

variable "consumer_subnet_b_cidr" {
  type        = string
  description = "CIDR range for consumer-subnet-b"
  default     = "10.2.0.0/24"
}
