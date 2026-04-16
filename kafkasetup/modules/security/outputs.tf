output "bastion_nsg_id" {
  description = "OCID du Network Security Group bastion"
  value       = oci_core_network_security_group.bastion.id
}

output "broker_nsg_id" {
  description = "OCID du Network Security Group des brokers Kafka"
  value       = oci_core_network_security_group.broker.id
}
