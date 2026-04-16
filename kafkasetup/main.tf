# ─────────────────────────────────────────────
# Data sources
# ─────────────────────────────────────────────
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Résolution automatique de l'image Oracle Linux 8 si aucun OCID fourni
data "oci_core_images" "oracle_linux_8" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.broker_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  prefix = "${var.project_name}-${var.environment}"

  # Sélection automatique de l'image si aucun OCID fourni
  broker_image_ocid  = var.broker_image_ocid != "" ? var.broker_image_ocid : data.oci_core_images.oracle_linux_8.images[0].id
  bastion_image_ocid = var.bastion_image_ocid != "" ? var.bastion_image_ocid : local.broker_image_ocid

  # Répartition des brokers sur les Availability Domains disponibles
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains
  broker_ads = [
    for i in range(var.kafka_broker_count) :
    local.availability_domains[i % length(local.availability_domains)].name
  ]

  # Tags communs appliqués à toutes les ressources
  common_tags = merge(
    {
      "Project"     = var.project_name
      "Environment" = var.environment
      "ManagedBy"   = "Terraform"
    },
    var.free_form_tags
  )
}

# ─────────────────────────────────────────────
# Module : Réseau
# ─────────────────────────────────────────────
module "network" {
  source = "./modules/network"

  prefix              = local.prefix
  compartment_ocid    = var.compartment_ocid
  vcn_cidr            = var.vcn_cidr
  vcn_dns_label       = var.vcn_dns_label
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  private_subnet_additional_cidrs = var.private_subnet_additional_cidrs
  common_tags         = local.common_tags
}

# ─────────────────────────────────────────────
# Module : Sécurité (NSGs)
# ─────────────────────────────────────────────
module "security" {
  source = "./modules/security"

  prefix              = local.prefix
  compartment_ocid    = var.compartment_ocid
  vcn_id              = module.network.vcn_id
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  allowed_ssh_cidrs   = var.allowed_ssh_cidrs
  kafka_mode          = var.kafka_mode
  common_tags         = local.common_tags
}

# ─────────────────────────────────────────────
# Module : Kafka (brokers + volumes + bastion)
# ─────────────────────────────────────────────
module "kafka" {
  source = "./modules/kafka"

  prefix               = local.prefix
  compartment_ocid     = var.compartment_ocid
  availability_domains = local.broker_ads
  vcn_dns_label        = var.vcn_dns_label

  # Réseau
  private_subnet_id  = module.network.private_subnet_id
  public_subnet_id   = module.network.public_subnet_id
  broker_nsg_id      = module.security.broker_nsg_id
  bastion_nsg_id     = module.security.bastion_nsg_id

  # Cluster Kafka
  kafka_broker_count               = var.kafka_broker_count
  kafka_version                    = var.kafka_version
  scala_version                    = var.scala_version
  kafka_mode                       = var.kafka_mode
  kafka_data_dir                   = var.kafka_data_dir
  kafka_heap_opts                  = var.kafka_heap_opts
  kafka_default_replication_factor = var.kafka_default_replication_factor
  kafka_min_insync_replicas        = var.kafka_min_insync_replicas
  kafka_num_partitions             = var.kafka_num_partitions
  kafka_log_retention_hours        = var.kafka_log_retention_hours
  kafka_log_segment_bytes          = var.kafka_log_segment_bytes

  # Compute — brokers
  broker_shape               = var.broker_shape
  broker_ocpus               = var.broker_ocpus
  broker_memory_gb           = var.broker_memory_gb
  broker_image_ocid          = local.broker_image_ocid
  broker_boot_volume_size_gb = var.broker_boot_volume_size_gb
  broker_ssh_authorized_keys = var.broker_ssh_authorized_keys

  # Volumes de données
  broker_data_volume_size_gb = var.broker_data_volume_size_gb
  broker_data_volume_vpus    = var.broker_data_volume_vpus

  # Bastion
  deploy_bastion              = var.deploy_bastion
  bastion_shape               = var.bastion_shape
  bastion_ocpus               = var.bastion_ocpus
  bastion_memory_gb           = var.bastion_memory_gb
  bastion_image_ocid          = local.bastion_image_ocid
  bastion_ssh_authorized_keys = var.bastion_ssh_authorized_keys

  common_tags = local.common_tags
}
