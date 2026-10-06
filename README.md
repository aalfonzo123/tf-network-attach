# Private Service Connect (PSC) Network Attachment Demo

This repository contains a complete Terraform deployment demonstrating cross-VPC communication using **Google Cloud Private Service Connect (PSC)**.

It showcases both directions of PSC traffic:
1. **PSC Ingress (Consumer $\rightarrow$ Producer)**: `consumer-vm-a` calls a PSC Endpoint in `consumer-subnet-a`, which connects across PSC to an Internal Load Balancer and `producer-vm` in `producer-vpc`.
2. **PSC Egress / Network Attachment (Producer $\rightarrow$ Consumer)**: `producer-vm` uses a secondary interface (`nic1`) attached to a **PSC Network Attachment** (`network-attachment-b`) in `consumer-vpc` to directly reach `consumer-vm-b` in `consumer-subnet-b`.

---

## Architecture Diagram

```mermaid
flowchart TB
    subgraph CONSUMER_VPC["Consumer VPC (consumer-vpc)"]
        direction TB

        subgraph SUBNET_A["consumer-subnet-a (10.1.0.0/24)"]
            CONSUMER_VM_A["consumer-vm-a<br/>(10.1.0.10)<br/>Python Client Script"]
            PSC_ENDPOINT["PSC Endpoint: psc-endpoint-a<br/>(10.1.0.2:8080)"]
        end

        subgraph SUBNET_B["consumer-subnet-b (10.2.0.0/24)"]
            CONSUMER_VM_B["consumer-vm-b<br/>(10.2.0.10:8080)<br/>Python HTTP Server"]
            NET_ATTACH_B["PSC Network Attachment<br/>(network-attachment-b)"]
        end

        CONSUMER_NAT["Cloud Router & NAT<br/>(consumer-nat)"]
        CONSUMER_FW["Firewall Rules<br/>(consumer-allow-http, mgmt)"]
    end

    subgraph PRODUCER_VPC["Producer VPC (producer-vpc)"]
        direction TB

        subgraph PRODUCER_SUBNET["producer-subnet (10.100.0.0/24)"]
            PRODUCER_VM["producer-vm<br/>nic0: 10.100.0.10<br/>nic1: 10.2.0.3 (via PSC NA)<br/>Python HTTP Server"]
            PRODUCER_UMIG["Unmanaged Instance Group<br/>(producer-umig)"]
            PRODUCER_ILB["Internal Load Balancer<br/>(producer-ilb: 10.100.0.2:8080)"]
            PRODUCER_HC["Health Check<br/>(producer-hc: /healthz)"]
        end

        subgraph PSC_NAT_SUBNET["producer-psc-nat-subnet (10.100.1.0/24)<br/>purpose = PRIVATE_SERVICE_CONNECT"]
            SERVICE_ATTACH["PSC Service Attachment<br/>(producer-service-attachment)"]
        end

        PRODUCER_NAT["Cloud Router & NAT<br/>(producer-nat)"]
        PRODUCER_FW["Firewall Rules<br/>(producer-allow-http, mgmt)"]
    end

    %% Component Relationships
    PRODUCER_UMIG -->|contains| PRODUCER_VM
    PRODUCER_ILB -->|backend service| PRODUCER_UMIG
    PRODUCER_HC -->|monitors| PRODUCER_ILB
    SERVICE_ATTACH -->|target service| PRODUCER_ILB

    NET_ATTACH_B -.->|subnetwork binding| SUBNET_B

    %% PSC Links
    PSC_ENDPOINT ==>|1. PSC Ingress Tunnel| SERVICE_ATTACH
    PRODUCER_VM -.->|2. PSC Egress (nic1 interface)| NET_ATTACH_B

    %% Call Flow
    CONSUMER_VM_A -->|"Step 1: GET http://10.1.0.2:8080"| PSC_ENDPOINT
    PRODUCER_VM -->|"Step 2: GET http://10.2.0.10:8080 (via nic1)"| CONSUMER_VM_B
```

---

## File Contents

| File | Description |
| :--- | :--- |
| [main.tf](main.tf) | Provider requirements and Google provider initialization. |
| [variables.tf](variables.tf) | Input variable declarations (`project_id`, `region`, `zone`, CIDRs). |
| [terraform.tfvars](terraform.tfvars) | Variable values set to project `as-alf-argolis`. |
| [networks.tf](networks.tf) | Defines VPCs (`producer-vpc`, `consumer-vpc`), subnets, PSC Endpoint, Service Attachment, Network Attachment, and Cloud NATs. |
| [firewall.tf](firewall.tf) | Ingress firewall rules for internal HTTP (`8080`), ICMP, and IAP SSH. |
| [vms.tf](vms.tf) | Compute instances (`producer-vm`, `consumer-vm-a`, `consumer-vm-b`) with auto-starting Python HTTP servers configured with Shielded VM Secure Boot. |
| [outputs.tf](outputs.tf) | Terraform outputs including internal IPs and test commands. |
| [diagram.mmd](diagram.mmd) | Raw Mermaid source code for the architecture diagram. |

---

## Deployment & Verification Instructions

### 1. Deploy with Terraform
```bash
terraform init
terraform apply -auto-approve
```

### 2. Verify End-to-End Execution
SSH into `consumer-vm-a` via IAP and execute the Python client script:

```bash
gcloud compute ssh consumer-vm-a \
  --zone=us-central1-a \
  --project=[project-id] \
  --tunnel-through-iap \
  --command="python3 /opt/consumer_a_client.py"
```

### 3. Expected Output Payload
```json
==================================================
Triggering call from consumer-vm-a to PSC Endpoint: http://10.1.0.2:8080
==================================================
SUCCESS! Full response payload:
{
  "status": "success",
  "message": "producer-vm successfully processed request and queried consumer-vm-b via PSC Network Attachment!",
  "producer_hostname": "producer-vm",
  "consumer_b_response": {
    "status": "success",
    "message": "Hello from consumer-vm-b!",
    "hostname": "consumer-vm-b",
    "vm": "consumer-vm-b",
    "my-external-ip": "35.254.189.28"
  }
}
```

---

## Clean Up
To delete all resources created by Terraform:

```bash
terraform destroy -auto-approve
```
