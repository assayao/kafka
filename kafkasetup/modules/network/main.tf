# ═══════════════════════════════════════════════════════════════
# Module : Réseau OCI — VCN, Subnets, Gateways, Route Tables
# ═══════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────
# VCN
# ─────────────────────────────────────────────
resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = var.vcn_dns_label
  freeform_tags  = var.common_tags
}

# ─────────────────────────────────────────────
# Gateways
# ─────────────────────────────────────────────
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-igw"
  enabled        = true
  freeform_tags  = var.common_tags
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-nat-gw"
  block_traffic  = false
  freeform_tags  = var.common_tags
}

resource "oci_core_service_gateway" "svc_gw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-svc-gw"
  freeform_tags  = var.common_tags

  services {
    service_id = data.oci_core_services.all_oci_services.services[0].id
  }
}

data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# ─────────────────────────────────────────────
# DHCP Options
# ─────────────────────────────────────────────
resource "oci_core_dhcp_options" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-dhcp-public"
  freeform_tags  = var.common_tags

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  options {
    type                = "SearchDomain"
    search_domain_names = ["${var.vcn_dns_label}.oraclevcn.com"]
  }
}

resource "oci_core_dhcp_options" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-dhcp-private"
  freeform_tags  = var.common_tags

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  options {
    type                = "SearchDomain"
    search_domain_names = ["${var.vcn_dns_label}.oraclevcn.com"]
  }
}

# ─────────────────────────────────────────────
# Route Tables
# ─────────────────────────────────────────────
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-rt-public"
  freeform_tags  = var.common_tags

  route_rules {
    description       = "Trafic Internet sortant via IGW"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-rt-private"
  freeform_tags  = var.common_tags

  route_rules {
    description       = "Trafic Internet sortant via NAT (mises à jour, packages)"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }

  route_rules {
    description       = "Trafic OCI Services (Object Storage, etc.) via Service Gateway"
    destination       = data.oci_core_services.all_oci_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.svc_gw.id
  }
}

# ─────────────────────────────────────────────
# Security Lists (règles de base — les NSGs
# du module security affinent le filtrage)
# ─────────────────────────────────────────────
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-sl-public"
  freeform_tags  = var.common_tags

  # Autoriser tout le trafic sortant
  egress_security_rules {
    description = "Tout le trafic sortant"
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.prefix}-sl-private"
  freeform_tags  = var.common_tags

  # Autoriser tout le trafic sortant
  egress_security_rules {
    description = "Tout le trafic sortant"
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Communication intra-cluster (brokers ↔ brokers)
  ingress_security_rules {
    description = "Trafic interne au sous-réseau privé"
    source      = var.private_subnet_cidr
    protocol    = "all"
    stateless   = false
  }
}

# ─────────────────────────────────────────────
# Sous-réseau Public (Bastion)
# ─────────────────────────────────────────────
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${var.prefix}-subnet-public"
  cidr_block                 = var.public_subnet_cidr
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  dhcp_options_id            = oci_core_dhcp_options.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  freeform_tags              = var.common_tags
}

# ─────────────────────────────────────────────
# Sous-réseau Privé Principal (Brokers Kafka)
# ─────────────────────────────────────────────
resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${var.prefix}-subnet-private"
  cidr_block                 = var.private_subnet_cidr
  dns_label                  = "private"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  dhcp_options_id            = oci_core_dhcp_options.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.common_tags
}

# ─────────────────────────────────────────────
# Sous-réseaux Privés Additionnels (multi-AD)
# ─────────────────────────────────────────────
resource "oci_core_subnet" "private_additional" {
  for_each = { for idx, cidr in var.private_subnet_additional_cidrs : idx => cidr }

  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${var.prefix}-subnet-private-${each.key + 2}"
  cidr_block                 = each.value
  dns_label                  = "private${each.key + 2}"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  dhcp_options_id            = oci_core_dhcp_options.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.common_tags
}
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}
