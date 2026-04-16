# ─────────────────────────────────────────────
# Réseau
# ─────────────────────────────────────────────
output "vcn_id" {
  description = "OCID du VCN"
  value       = module.network.vcn_id
}

output "public_subnet_id" {
  description = "OCID du sous-réseau public"
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "OCID du sous-réseau privé"
  value       = module.network.private_subnet_id
}

# ─────────────────────────────────────────────
# Bastion
# ─────────────────────────────────────────────
output "bastion_public_ip" {
  description = "IP publique du bastion (null si deploy_bastion = false)"
  value       = module.kafka.bastion_public_ip
}

# ─────────────────────────────────────────────
# Brokers Kafka
# ─────────────────────────────────────────────
output "broker_private_ips" {
  description = "IPs privées de chaque broker Kafka"
  value       = module.kafka.broker_private_ips
}

output "broker_instance_ids" {
  description = "OCIDs des instances broker"
  value       = module.kafka.broker_instance_ids
}

output "kafka_bootstrap_servers" {
  description = "Chaîne bootstrap.servers à configurer dans les clients Kafka"
  value       = module.kafka.kafka_bootstrap_servers
}

output "kafka_cluster_summary" {
  description = "Résumé du cluster Kafka déployé"
  value = {
    mode         = var.kafka_mode
    version      = var.kafka_version
    broker_count = var.kafka_broker_count
    region       = var.region
    environment  = var.environment
  }
}
