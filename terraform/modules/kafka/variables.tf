variable "prefix" {
  description = "Préfixe commun pour nommer les ressources Kafka"
  type        = string
}

variable "vcn_dns_label" {
  description = "Label DNS du VCN — utilisé pour construire les FQDNs des brokers"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID du compartiment"
  type        = string
}

variable "availability_domains" {
  description = "Liste des Availability Domains pour chaque broker (calculée dans main.tf racine)"
  type        = list(string)
}

# ─────────────────────────────────────────────
# Réseau
# ─────────────────────────────────────────────
variable "private_subnet_id" {
  description = "OCID du sous-réseau privé principal"
  type        = string
}

variable "public_subnet_id" {
  description = "OCID du sous-réseau public (bastion)"
  type        = string
}

variable "broker_nsg_id" {
  description = "OCID du NSG des brokers"
  type        = string
}

variable "bastion_nsg_id" {
  description = "OCID du NSG du bastion"
  type        = string
}

# ─────────────────────────────────────────────
# Cluster Kafka
# ─────────────────────────────────────────────
variable "kafka_broker_count" {
  description = "Nombre de brokers Kafka"
  type        = number
  default     = 3
}

variable "kafka_version" {
  description = "Version de Kafka"
  type        = string
  default     = "3.7.0"
}

variable "scala_version" {
  description = "Version de Scala embarquée"
  type        = string
  default     = "2.13"
}

variable "kafka_mode" {
  description = "Mode : 'kraft' ou 'zookeeper'"
  type        = string
  default     = "kraft"
}

variable "kafka_data_dir" {
  description = "Répertoire de données Kafka"
  type        = string
  default     = "/kafka/data"
}

variable "kafka_heap_opts" {
  description = "Options JVM HEAP"
  type        = string
  default     = "-Xmx4g -Xms4g"
}

variable "kafka_default_replication_factor" {
  type    = number
  default = 3
}

variable "kafka_min_insync_replicas" {
  type    = number
  default = 2
}

variable "kafka_num_partitions" {
  type    = number
  default = 6
}

variable "kafka_log_retention_hours" {
  type    = number
  default = 168
}

variable "kafka_log_segment_bytes" {
  type    = number
  default = 1073741824
}

# ─────────────────────────────────────────────
# Compute — Brokers
# ─────────────────────────────────────────────
variable "broker_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "broker_ocpus" {
  type    = number
  default = 2
}

variable "broker_memory_gb" {
  type    = number
  default = 16
}

variable "broker_image_ocid" {
  type = string
}

variable "broker_boot_volume_size_gb" {
  type    = number
  default = 50
}

variable "broker_ssh_authorized_keys" {
  type      = string
  sensitive = true
}

# ─────────────────────────────────────────────
# Volumes de données
# ─────────────────────────────────────────────
variable "broker_data_volume_size_gb" {
  type    = number
  default = 200
}

variable "broker_data_volume_vpus" {
  type    = number
  default = 10
}

# ─────────────────────────────────────────────
# Bastion
# ─────────────────────────────────────────────
variable "deploy_bastion" {
  type    = bool
  default = true
}

variable "bastion_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "bastion_ocpus" {
  type    = number
  default = 1
}

variable "bastion_memory_gb" {
  type    = number
  default = 4
}

variable "bastion_image_ocid" {
  type = string
}

variable "bastion_ssh_authorized_keys" {
  type      = string
  sensitive = true
}

variable "common_tags" {
  description = "Tags communs appliqués à toutes les ressources"
  type        = map(string)
  default     = {}
}
