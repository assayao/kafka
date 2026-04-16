variable "prefix" {
  description = "Préfixe commun pour nommer les ressources de sécurité"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID du compartiment"
  type        = string
}

variable "vcn_id" {
  description = "OCID du VCN"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR du sous-réseau public"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR du sous-réseau privé"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs autorisés pour SSH vers le bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kafka_mode" {
  description = "Mode Kafka : 'kraft' ou 'zookeeper'"
  type        = string
  default     = "kraft"
}

variable "common_tags" {
  description = "Tags communs appliqués à toutes les ressources"
  type        = map(string)
  default     = {}
}
