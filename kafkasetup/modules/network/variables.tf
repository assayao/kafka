variable "prefix" {
  description = "Préfixe commun pour nommer les ressources réseau"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID du compartiment"
  type        = string
}

variable "vcn_cidr" {
  description = "Bloc CIDR du VCN"
  type        = string
}

variable "vcn_dns_label" {
  description = "Label DNS du VCN"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR du sous-réseau public (bastion)"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR du sous-réseau privé principal (brokers)"
  type        = string
}

variable "private_subnet_additional_cidrs" {
  description = "CIDRs additionnels pour des sous-réseaux privés supplémentaires"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Tags communs appliqués à toutes les ressources"
  type        = map(string)
  default     = {}
}
