# ═══════════════════════════════════════════════════════════════
# Module : Kafka — Instances, Volumes, Bastion, Cloud-Init
# ═══════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────
# Locals — Pré-calcul des chaînes de configuration
# Ces strings sont construites ici (côté Terraform) et passées
# au template comme variables scalaires simples, évitant tout
# conflit entre la syntaxe bash (${VAR%pattern}) et le moteur
# de templates Terraform.
# ─────────────────────────────────────────────
locals {
  # FQDN OCI DNS de chaque broker (DNS interne du VCN)
  # Format : <hostname>.<subnet_dns_label>.<vcn_dns_label>.oraclevcn.com
  broker_fqdns = [
    for i in range(var.kafka_broker_count) :
    "kafka-broker-${i}.private.${var.vcn_dns_label}.oraclevcn.com"
  ]

  # KRaft — controller.quorum.voters
  # Format : "0@fqdn0:9094,1@fqdn1:9094,..."
  controller_quorum_voters = join(",", [
    for i in range(var.kafka_broker_count) :
    "${i}@kafka-broker-${i}.private.${var.vcn_dns_label}.oraclevcn.com:9094"
  ])

  # ZooKeeper — zookeeper.connect
  # Format : "fqdn0:2181,fqdn1:2181,..."
  zk_connect = join(",", [
    for i in range(var.kafka_broker_count) :
    "kafka-broker-${i}.private.${var.vcn_dns_label}.oraclevcn.com:2181"
  ])

  # ZooKeeper — server list dans zookeeper.properties
  # Format : "server.0=fqdn0:2888:3888\nserver.1=fqdn1:2888:3888\n..."
  zk_servers_config = join("\n", [
    for i in range(var.kafka_broker_count) :
    "server.${i}=kafka-broker-${i}.private.${var.vcn_dns_label}.oraclevcn.com:2888:3888"
  ])
}

# ─────────────────────────────────────────────
# Volumes de données (bloc storage dédié Kafka)
# ─────────────────────────────────────────────
resource "oci_core_volume" "broker_data" {
  count = var.kafka_broker_count

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domains[count.index]
  display_name        = "${var.prefix}-kafka-broker-${count.index}-data"
  size_in_gbs         = var.broker_data_volume_size_gb
  vpus_per_gb         = var.broker_data_volume_vpus
  freeform_tags       = merge(var.common_tags, { "BrokerId" = tostring(count.index) })
}

# ─────────────────────────────────────────────
# Instances Brokers Kafka
# ─────────────────────────────────────────────
resource "oci_core_instance" "broker" {
  count = var.kafka_broker_count

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domains[count.index]
  display_name        = "${var.prefix}-kafka-broker-${count.index}"
  shape               = var.broker_shape
  freeform_tags       = merge(var.common_tags, { "KafkaBrokerId" = tostring(count.index) })

  shape_config {
    ocpus         = var.broker_ocpus
    memory_in_gbs = var.broker_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = var.broker_image_ocid
    boot_volume_size_in_gbs = var.broker_boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = var.private_subnet_id
    display_name     = "${var.prefix}-broker-${count.index}-vnic"
    assign_public_ip = false
    hostname_label   = "kafka-broker-${count.index}"
    nsg_ids          = [var.broker_nsg_id]
  }

  metadata = {
    ssh_authorized_keys = var.broker_ssh_authorized_keys

    # Toutes les valeurs complexes sont pré-calculées en locals Terraform
    # et passées comme strings simples — évite les conflits bash/template.
    user_data = base64encode(templatefile("${path.module}/templates/kafka_install.sh.tpl", {
      # Identité du broker
      broker_id    = count.index
      broker_count = var.kafka_broker_count

      # Kafka
      kafka_mode    = var.kafka_mode
      kafka_version = var.kafka_version
      scala_version = var.scala_version
      kafka_data_dir  = var.kafka_data_dir
      kafka_heap_opts = var.kafka_heap_opts

      # Paramètres broker (scalaires)
      kafka_default_replication_factor = var.kafka_default_replication_factor
      kafka_min_insync_replicas        = var.kafka_min_insync_replicas
      kafka_num_partitions             = var.kafka_num_partitions
      kafka_log_retention_hours        = var.kafka_log_retention_hours
      kafka_log_segment_bytes          = var.kafka_log_segment_bytes

      # Chaînes pré-calculées — aucun for-loop nécessaire dans le template
      controller_quorum_voters = local.controller_quorum_voters
      zk_connect               = local.zk_connect
      zk_servers_config        = local.zk_servers_config
    }))
  }

  preserve_boot_volume = false
}

# ─────────────────────────────────────────────
# Attachement des volumes de données
# ─────────────────────────────────────────────
resource "oci_core_volume_attachment" "broker_data" {
  count = var.kafka_broker_count

  attachment_type  = "paravirtualized"
  instance_id      = oci_core_instance.broker[count.index].id
  volume_id        = oci_core_volume.broker_data[count.index].id
  display_name     = "${var.prefix}-broker-${count.index}-data-attach"
  is_pv_encryption_in_transit_enabled = false

  depends_on = [oci_core_instance.broker]
}

# ─────────────────────────────────────────────
# Bastion (optionnel)
# ─────────────────────────────────────────────
resource "oci_core_instance" "bastion" {
  count = var.deploy_bastion ? 1 : 0

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domains[0]
  display_name        = "${var.prefix}-bastion"
  shape               = var.bastion_shape
  freeform_tags       = merge(var.common_tags, { "Role" = "bastion" })

  shape_config {
    ocpus         = var.bastion_ocpus
    memory_in_gbs = var.bastion_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = var.bastion_image_ocid
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = var.public_subnet_id
    display_name     = "${var.prefix}-bastion-vnic"
    assign_public_ip = true
    hostname_label   = "bastion"
    nsg_ids          = [var.bastion_nsg_id]
  }

  metadata = {
    ssh_authorized_keys = var.bastion_ssh_authorized_keys
    user_data = base64encode(<<-BASTION_INIT
      #!/bin/bash
      set -euo pipefail
      if command -v dnf &>/dev/null; then
        dnf update -y && dnf install -y nc wget curl bind-utils
      elif command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get upgrade -y
        apt-get install -y netcat wget curl dnsutils
      fi
      echo "Bastion ready." > /var/log/bastion-init.log
    BASTION_INIT
    )
  }
}
