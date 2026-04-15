output "broker_instance_ids" {
  description = "OCIDs des instances broker"
  value       = oci_core_instance.broker[*].id
}

output "broker_private_ips" {
  description = "IPs privées de chaque broker"
  value       = oci_core_instance.broker[*].private_ip
}

output "broker_hostnames" {
  description = "Hostnames DNS internes des brokers"
  value       = oci_core_instance.broker[*].hostname_label
}

output "broker_data_volume_ids" {
  description = "OCIDs des volumes de données"
  value       = oci_core_volume.broker_data[*].id
}

output "bastion_public_ip" {
  description = "IP publique du bastion"
  value       = var.deploy_bastion ? oci_core_instance.bastion[0].public_ip : null
}

output "bastion_instance_id" {
  description = "OCID de l'instance bastion"
  value       = var.deploy_bastion ? oci_core_instance.bastion[0].id : null
}

output "kafka_bootstrap_servers" {
  description = "Chaîne bootstrap.servers pour les clients Kafka"
  value = join(",", [
    for ip in oci_core_instance.broker[*].private_ip :
    "${ip}:9092"
  ])
}

output "ssh_command_bastion" {
  description = "Commande SSH pour se connecter au bastion"
  value       = var.deploy_bastion ? "ssh -i <your-key> opc@${oci_core_instance.bastion[0].public_ip}" : "Bastion non déployé"
}

output "ssh_command_broker_via_bastion" {
  description = "Exemple de commande SSH vers le broker-0 via le bastion"
  value = var.deploy_bastion ? join("\n", [
    "# Tunnel SSH vers broker-0 via bastion :",
    "ssh -J opc@${oci_core_instance.bastion[0].public_ip} opc@${oci_core_instance.broker[0].private_ip}"
  ]) : "Bastion non déployé"
}
