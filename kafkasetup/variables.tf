# ─────────────────────────────────────────────
# OCI Authentication
# ─────────────────────────────────────────────
variable "tenancy_ocid" {
  description = "OCID du tenant OCI"
  type        = string
}

variable "user_ocid" {
  description = "OCID de l'utilisateur OCI"
  type        = string
}

variable "fingerprint" {
  description = "Empreinte de la clé API OCI"
  type        = string
}

variable "private_key_path" {
  description = "Chemin vers la clé privée API OCI (.pem)"
  type        = string
}

variable "region" {
  description = "Région OCI cible (ex: eu-paris-1)"
  type        = string
  default     = "us-ashburn-1"
}

# ─────────────────────────────────────────────
# Projet / Tags
# ─────────────────────────────────────────────
variable "project_name" {
  description = "Nom du projet — utilisé comme préfixe pour toutes les ressources"
  type        = string
  default     = "kafka-lab"
}

variable "environment" {
  description = "Environnement cible (dev / staging / prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "La valeur doit être 'dev', 'staging' ou 'prod'."
  }
}

variable "compartment_ocid" {
  description = "OCID du compartiment où déployer les ressources"
  type        = string
}

variable "free_form_tags" {
  description = "Tags libres appliqués à toutes les ressources"
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────
# Réseau
# ─────────────────────────────────────────────
variable "vcn_cidr" {
  description = "Bloc CIDR principal du VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vcn_dns_label" {
  description = "Étiquette DNS du VCN (alphanumérique, max 15 car.)"
  type        = string
  default     = "kafkavcn"
}

variable "public_subnet_cidr" {
  description = "Bloc CIDR du sous-réseau public (bastion)"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "Bloc CIDR du sous-réseau privé (brokers Kafka)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_additional_cidrs" {
  description = "Blocs CIDR supplémentaires pour des sous-réseaux privés additionnels (multi-AD)"
  type        = list(string)
  default     = []
  # Exemple : ["10.0.2.0/24", "10.0.3.0/24"] pour AD-2 et AD-3
}

# ─────────────────────────────────────────────
# Kafka — Cluster
# ─────────────────────────────────────────────
variable "kafka_broker_count" {
  description = "Nombre de brokers Kafka (≥ 1 ; recommandé : 3)"
  type        = number
  default     = 3

  validation {
    condition     = var.kafka_broker_count >= 1
    error_message = "Le nombre de brokers doit être d'au moins 1."
  }
}

variable "kafka_version" {
  description = "Version de Kafka à installer (ex: 3.7.0)"
  type        = string
  default     = "3.7.0"
}

variable "scala_version" {
  description = "Version de Scala embarquée dans Kafka (ex: 2.13)"
  type        = string
  default     = "2.13"
}

variable "kafka_mode" {
  description = "Mode de déploiement : 'kraft' (sans ZooKeeper, Kafka ≥ 3.3) ou 'zookeeper'"
  type        = string
  default     = "kraft"

  validation {
    condition     = contains(["kraft", "zookeeper"], var.kafka_mode)
    error_message = "kafka_mode doit être 'kraft' ou 'zookeeper'."
  }
}

variable "kafka_data_dir" {
  description = "Répertoire de stockage des logs Kafka sur les brokers"
  type        = string
  default     = "/kafka/data"
}

variable "kafka_heap_opts" {
  description = "Options JVM HEAP pour Kafka (ex: -Xmx6g -Xms6g)"
  type        = string
  default     = "-Xmx4g -Xms4g"
}

# ─────────────────────────────────────────────
# Kafka — Paramètres broker
# ─────────────────────────────────────────────
variable "kafka_default_replication_factor" {
  description = "Facteur de réplication par défaut des topics"
  type        = number
  default     = 3
}

variable "kafka_min_insync_replicas" {
  description = "Nombre minimum de répliques en sync (min.insync.replicas)"
  type        = number
  default     = 2
}

variable "kafka_num_partitions" {
  description = "Nombre de partitions par défaut par topic"
  type        = number
  default     = 6
}

variable "kafka_log_retention_hours" {
  description = "Durée de rétention des messages en heures"
  type        = number
  default     = 168
}

variable "kafka_log_segment_bytes" {
  description = "Taille maximale d'un segment de log en octets"
  type        = number
  default     = 1073741824
}

# ─────────────────────────────────────────────
# Compute — Brokers
# ─────────────────────────────────────────────
variable "broker_shape" {
  description = "Shape OCI pour les brokers (ex: VM.Standard.E4.Flex, VM.Standard.A1.Flex)"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "broker_ocpus" {
  description = "Nombre d'OCPUs par broker (shapes Flex uniquement)"
  type        = number
  default     = 2
}

variable "broker_memory_gb" {
  description = "Mémoire RAM en Go par broker (shapes Flex uniquement)"
  type        = number
  default     = 16
}

variable "broker_image_ocid" {
  description = "OCID de l'image Oracle Linux 8 (ou Ubuntu 22.04) pour les brokers"
  type        = string
  default     = ""
  # Remplacer par l'OCID correspondant à votre région
  # Oracle Linux 8 : disponible via oci_core_images data source
}

variable "broker_boot_volume_size_gb" {
  description = "Taille du volume de boot des brokers en Go"
  type        = number
  default     = 50
}

variable "broker_ssh_authorized_keys" {
  description = "Clé(s) SSH publique(s) autorisée(s) sur les brokers"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────
# Compute — Volumes de données
# ─────────────────────────────────────────────
variable "broker_data_volume_size_gb" {
  description = "Taille du volume bloc dédié aux données Kafka (Go)"
  type        = number
  default     = 200
}

variable "broker_data_volume_vpus" {
  description = "Performance du volume bloc (0=Low, 10=Balanced, 20=High, 30=Ultra High)"
  type        = number
  default     = 10

  validation {
    condition     = contains([0, 10, 20, 30], var.broker_data_volume_vpus)
    error_message = "vpus_per_gb doit être 0, 10, 20 ou 30."
  }
}

# ─────────────────────────────────────────────
# Bastion (optionnel)
# ─────────────────────────────────────────────
variable "deploy_bastion" {
  description = "Déployer une instance bastion dans le sous-réseau public"
  type        = bool
  default     = true
}

variable "bastion_shape" {
  description = "Shape OCI pour le bastion"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "bastion_ocpus" {
  description = "Nombre d'OCPUs pour le bastion"
  type        = number
  default     = 1
}

variable "bastion_memory_gb" {
  description = "Mémoire RAM en Go pour le bastion"
  type        = number
  default     = 4
}

variable "bastion_image_ocid" {
  description = "OCID de l'image pour le bastion (peut être identique à broker_image_ocid)"
  type        = string
  default     = ""
}

variable "bastion_ssh_authorized_keys" {
  description = "Clé(s) SSH publique(s) autorisée(s) sur le bastion"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "Liste de CIDRs autorisés à se connecter en SSH sur le bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
