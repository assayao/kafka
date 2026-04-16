# ═══════════════════════════════════════════════════════════════
# Module : Sécurité OCI — Network Security Groups (NSGs)
# ═══════════════════════════════════════════════════════════════
#
# Architecture :
#   bastion_nsg  → accès SSH depuis l'extérieur vers le bastion
#   broker_nsg   → accès Kafka/ZK inter-brokers + depuis clients internes
# ═══════════════════════════════════════════════════════════════

locals {
  # Ports Kafka broker
  kafka_plaintext_port = 9092
  kafka_ssl_port       = 9093
  kafka_jmx_port       = 9999
  kafka_controller_port = 9093   # KRaft controller listener

  # Ports ZooKeeper (utilisés uniquement si kafka_mode = "zookeeper")
  zk_client_port      = 2181
  zk_peer_port        = 2888
  zk_election_port    = 3888
}

# ─────────────────────────────────────────────
# NSG — Bastion
# ─────────────────────────────────────────────
resource "oci_core_network_security_group" "bastion" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.prefix}-nsg-bastion"
  freeform_tags  = var.common_tags
}

# Ingress : SSH depuis les CIDRs autorisés
resource "oci_core_network_security_group_security_rule" "bastion_ssh_ingress" {
  for_each = toset(var.allowed_ssh_cidrs)

  network_security_group_id = oci_core_network_security_group.bastion.id
  direction                 = "INGRESS"
  protocol                  = "6"   # TCP
  description               = "SSH depuis ${each.value}"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Egress : Tout le trafic sortant
resource "oci_core_network_security_group_security_rule" "bastion_egress_all" {
  network_security_group_id = oci_core_network_security_group.bastion.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Tout le trafic sortant"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# Egress : SSH vers le sous-réseau privé (rebond vers brokers)
resource "oci_core_network_security_group_security_rule" "bastion_ssh_to_private" {
  network_security_group_id = oci_core_network_security_group.bastion.id
  direction                 = "EGRESS"
  protocol                  = "6"
  description               = "SSH vers le sous-réseau privé (brokers)"
  destination               = var.private_subnet_cidr
  destination_type          = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# ─────────────────────────────────────────────
# NSG — Brokers Kafka
# ─────────────────────────────────────────────
resource "oci_core_network_security_group" "broker" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.prefix}-nsg-broker"
  freeform_tags  = var.common_tags
}

# Ingress : SSH depuis le bastion
resource "oci_core_network_security_group_security_rule" "broker_ssh_from_bastion" {
  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "SSH depuis le bastion"
  source                    = var.public_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Ingress : Kafka PLAINTEXT (9092) depuis le sous-réseau privé (clients internes)
resource "oci_core_network_security_group_security_rule" "broker_kafka_plaintext" {
  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Kafka PLAINTEXT depuis le réseau privé"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = local.kafka_plaintext_port
      max = local.kafka_plaintext_port
    }
  }
}

# Ingress : Kafka SSL (9093) depuis le sous-réseau privé
resource "oci_core_network_security_group_security_rule" "broker_kafka_ssl" {
  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Kafka SSL/TLS depuis le réseau privé"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = local.kafka_ssl_port
      max = local.kafka_ssl_port
    }
  }
}

# Ingress : Kafka inter-broker (KRaft controller port 9093)
resource "oci_core_network_security_group_security_rule" "broker_kraft_controller" {
  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Communication KRaft inter-broker (controller)"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 9094
      max = 9094
    }
  }
}

# Ingress : JMX (9999) depuis le sous-réseau privé (monitoring)
resource "oci_core_network_security_group_security_rule" "broker_jmx" {
  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "JMX pour le monitoring depuis le réseau privé"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = local.kafka_jmx_port
      max = local.kafka_jmx_port
    }
  }
}

# Ingress ZooKeeper (conditionnel — activé si kafka_mode = "zookeeper")
resource "oci_core_network_security_group_security_rule" "broker_zk_client" {
  count = var.kafka_mode == "zookeeper" ? 1 : 0

  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "ZooKeeper client port (2181)"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = local.zk_client_port
      max = local.zk_client_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "broker_zk_peer" {
  count = var.kafka_mode == "zookeeper" ? 1 : 0

  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "ZooKeeper peer port (2888)"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = local.zk_peer_port
      max = local.zk_peer_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "broker_zk_election" {
  count = var.kafka_mode == "zookeeper" ? 1 : 0

  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "ZooKeeper election port (3888)"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = local.zk_election_port
      max = local.zk_election_port
    }
  }
}

# Ingress : ICMP (ping) depuis le VCN
resource "oci_core_network_security_group_security_rule" "broker_icmp" {
  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "INGRESS"
  protocol                  = "1"   # ICMP
  description               = "ICMP depuis le VCN (diagnostics)"
  source                    = "10.0.0.0/8"
  source_type               = "CIDR_BLOCK"

  icmp_options {
    type = 3   # Destination Unreachable
    code = 4   # Fragmentation needed
  }
}

# Egress : Tout le trafic sortant
resource "oci_core_network_security_group_security_rule" "broker_egress_all" {
  network_security_group_id = oci_core_network_security_group.broker.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Tout le trafic sortant"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}
