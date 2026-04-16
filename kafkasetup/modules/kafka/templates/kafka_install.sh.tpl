#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Script d'installation Kafka — généré par Terraform
# Mode    : ${kafka_mode}
# Version : ${kafka_version} (Scala ${scala_version})
# Broker  : ${broker_id} / ${broker_count}
# ═══════════════════════════════════════════════════════════════════
# RÈGLES de syntaxe dans ce fichier :
#   Les placeholders Terraform utilisent la syntaxe avec accolades.
#   $BASH_VAR correspond a une variable bash.
#   $$(cmd) produit $(cmd) dans le script final.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

LOG="/var/log/kafka-install.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== [$(date -u +%FT%TZ)] Démarrage installation Kafka ==="
echo "  Mode          : ${kafka_mode}"
echo "  Version       : ${kafka_version}"
echo "  Scala         : ${scala_version}"
echo "  Broker ID     : ${broker_id} / $((${broker_count} - 1))"
echo "  Data dir      : ${kafka_data_dir}"

# ─────────────────────────────────────────────
# 1. Détection et montage du volume de données
# ─────────────────────────────────────────────
echo "--- Détection du volume de données ---"

DATA_DEVICE=""
for dev in /dev/oracleoci/oraclevdb /dev/sdb /dev/xvdb /dev/nvme1n1; do
  if [ -b "$dev" ]; then
    DATA_DEVICE="$dev"
    break
  fi
done

if [ -z "$DATA_DEVICE" ]; then
  echo "ERREUR : aucun volume de données secondaire détecté." >&2
  exit 1
fi

echo "Volume détecté : $DATA_DEVICE"

if ! blkid "$DATA_DEVICE" | grep -q ext4; then
  echo "Formatage en ext4..."
  mkfs.ext4 -F "$DATA_DEVICE"
fi

mkdir -p "${kafka_data_dir}"

if ! grep -qF "$DATA_DEVICE" /etc/fstab; then
  echo "$DATA_DEVICE  ${kafka_data_dir}  ext4  defaults,noatime  0 2" >> /etc/fstab
fi

mount -a
echo "Volume monté sur ${kafka_data_dir}"

# ─────────────────────────────────────────────
# 2. Pré-requis système
# ─────────────────────────────────────────────
echo "--- Installation des pré-requis ---"

if command -v dnf &>/dev/null; then
  dnf install -y java-17-openjdk-devel wget curl nc tar net-tools
elif command -v apt-get &>/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y openjdk-17-jdk wget curl netcat tar net-tools
else
  echo "ERREUR : gestionnaire de paquets inconnu." >&2
  exit 1
fi

java -version 2>&1

# ─────────────────────────────────────────────
# 3. Utilisateur système kafka
# ─────────────────────────────────────────────
id kafka 2>/dev/null || useradd -r -s /sbin/nologin -d /opt/kafka kafka

# ─────────────────────────────────────────────
# 4. Téléchargement et installation de Kafka
# ─────────────────────────────────────────────
KAFKA_ARCHIVE="kafka_${scala_version}-${kafka_version}.tgz"
KAFKA_URL="https://downloads.apache.org/kafka/${kafka_version}/$KAFKA_ARCHIVE"
KAFKA_HOME="/opt/kafka"

echo "--- Téléchargement de Kafka ${kafka_version} ---"

if [ ! -d "$KAFKA_HOME" ]; then
  wget -q --show-progress "$KAFKA_URL" -O "/tmp/$KAFKA_ARCHIVE" \
    || wget -q "https://archive.apache.org/dist/kafka/${kafka_version}/$KAFKA_ARCHIVE" -O "/tmp/$KAFKA_ARCHIVE"

  tar -xzf "/tmp/$KAFKA_ARCHIVE" -C /opt/
  mv "/opt/kafka_${scala_version}-${kafka_version}" "$KAFKA_HOME"
  rm -f "/tmp/$KAFKA_ARCHIVE"
  echo "Kafka installé dans $KAFKA_HOME"
else
  echo "Kafka déjà présent dans $KAFKA_HOME — installation ignorée."
fi

chown -R kafka:kafka "$KAFKA_HOME"
chown -R kafka:kafka "${kafka_data_dir}"

# ─────────────────────────────────────────────
# 5. IP privée du broker (via IMDS OCI)
# ─────────────────────────────────────────────
BROKER_IP=$(curl -sf --max-time 5 \
  'http://169.254.169.254/opc/v1/vnics/' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['privateIp'])" \
  2>/dev/null \
  || hostname -I | awk '{print $1}')

echo "IP privée du broker : $BROKER_IP"

# ─────────────────────────────────────────────
# 6. Variables d'environnement globales
# ─────────────────────────────────────────────
cat > /etc/profile.d/kafka.sh <<ENVFILE
export KAFKA_HOME="/opt/kafka"
export KAFKA_HEAP_OPTS="${kafka_heap_opts}"
export PATH=\$PATH:\$KAFKA_HOME/bin
ENVFILE

# ═══════════════════════════════════════════════════════════════
# BRANCHE KRaft (Kafka sans ZooKeeper — recommandé Kafka ≥ 3.3)
# ═══════════════════════════════════════════════════════════════
%{ if kafka_mode == "kraft" }
echo "--- Configuration KRaft (mode ${kafka_mode}) ---"

# Cluster UUID — partagé entre tous les brokers via un fichier local.
# En production, injecter un UUID pré-généré via user_data ou un bucket OCI.
UUID_FILE="$KAFKA_HOME/cluster-uuid"
if [ ! -f "$UUID_FILE" ]; then
  $KAFKA_HOME/bin/kafka-storage.sh random-uuid > "$UUID_FILE"
fi
CLUSTER_UUID=$(cat "$UUID_FILE")
echo "Cluster UUID : $CLUSTER_UUID"

# Écriture de server.properties (KRaft)
cat > "$KAFKA_HOME/config/kraft/server.properties" <<KRAFTCFG
# ── KRaft server.properties — broker ${broker_id} ─────────────────────────
process.roles=broker,controller
node.id=${broker_id}

# Voters pré-calculés par Terraform : id@host:port,...
controller.quorum.voters=${controller_quorum_voters}

# Listeners
listeners=PLAINTEXT://$BROKER_IP:9092,CONTROLLER://$BROKER_IP:9094
advertised.listeners=PLAINTEXT://$BROKER_IP:9092
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT

# Stockage
log.dirs=${kafka_data_dir}
log.segment.bytes=${kafka_log_segment_bytes}
log.retention.hours=${kafka_log_retention_hours}

# Réplication
default.replication.factor=${kafka_default_replication_factor}
min.insync.replicas=${kafka_min_insync_replicas}
num.partitions=${kafka_num_partitions}

# Réseau et I/O
num.network.threads=8
num.io.threads=16
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
num.recovery.threads.per.data.dir=2

# Topics
auto.create.topics.enable=true
delete.topic.enable=true
KRAFTCFG

echo "Formatage du stockage KRaft..."
$KAFKA_HOME/bin/kafka-storage.sh format \
  --cluster-id "$CLUSTER_UUID" \
  --config "$KAFKA_HOME/config/kraft/server.properties" \
  --ignore-formatted

KAFKA_CFG="$KAFKA_HOME/config/kraft/server.properties"
KAFKA_START="$KAFKA_HOME/bin/kafka-server-start.sh"
%{ endif }

# ═══════════════════════════════════════════════════════════════
# BRANCHE ZooKeeper
# ═══════════════════════════════════════════════════════════════
%{ if kafka_mode == "zookeeper" }
echo "--- Configuration ZooKeeper (mode ${kafka_mode}) ---"

# Dossier et myid
mkdir -p "${kafka_data_dir}/zookeeper"
echo "${broker_id}" > "${kafka_data_dir}/zookeeper/myid"

# zookeeper.properties — liste de serveurs pré-calculée par Terraform
cat > "$KAFKA_HOME/config/zookeeper.properties" <<ZKCFG
# ── zookeeper.properties — nœud ${broker_id} ──────────────────────────────
dataDir=${kafka_data_dir}/zookeeper
clientPort=2181
maxClientCnxns=100
tickTime=2000
initLimit=10
syncLimit=5

# Serveurs pré-calculés par Terraform
${zk_servers_config}
ZKCFG

# server.properties Kafka
cat > "$KAFKA_HOME/config/server.properties" <<SVRCFG
# ── server.properties — broker ${broker_id} ───────────────────────────────
broker.id=${broker_id}

# ZooKeeper connect pré-calculé par Terraform
zookeeper.connect=${zk_connect}
zookeeper.connection.timeout.ms=18000

# Listeners
listeners=PLAINTEXT://$BROKER_IP:9092
advertised.listeners=PLAINTEXT://$BROKER_IP:9092
inter.broker.listener.name=PLAINTEXT

# Stockage
log.dirs=${kafka_data_dir}
log.segment.bytes=${kafka_log_segment_bytes}
log.retention.hours=${kafka_log_retention_hours}

# Réplication
default.replication.factor=${kafka_default_replication_factor}
min.insync.replicas=${kafka_min_insync_replicas}
num.partitions=${kafka_num_partitions}

# Réseau et I/O
num.network.threads=8
num.io.threads=16
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
num.recovery.threads.per.data.dir=2

# Topics
auto.create.topics.enable=true
delete.topic.enable=true
SVRCFG

KAFKA_CFG="$KAFKA_HOME/config/server.properties"
KAFKA_START="$KAFKA_HOME/bin/kafka-server-start.sh"

# ── Service systemd ZooKeeper ────────────────────────────────────────
cat > /etc/systemd/system/zookeeper.service <<ZKSVC
[Unit]
Description=Apache ZooKeeper (Kafka cluster)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=kafka
Group=kafka
Environment=JAVA_HOME=/usr
Environment=KAFKA_HEAP_OPTS=${kafka_heap_opts}
ExecStart=$KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties
ExecStop=$KAFKA_HOME/bin/zookeeper-server-stop.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
ZKSVC

systemctl daemon-reload
systemctl enable zookeeper
systemctl start zookeeper

echo "Attente démarrage ZooKeeper (max 60s)..."
for i in $(seq 1 30); do
  nc -z localhost 2181 2>/dev/null && echo "ZooKeeper prêt (tentative $i)." && break
  sleep 2
done
%{ endif }

# ─────────────────────────────────────────────
# 7. Service systemd Kafka
# ─────────────────────────────────────────────
%{ if kafka_mode == "zookeeper" }
AFTER_UNIT="zookeeper.service"
REQUIRES_UNIT="Requires=zookeeper.service"
%{ else }
AFTER_UNIT="network-online.target"
REQUIRES_UNIT=""
%{ endif }

cat > /etc/systemd/system/kafka.service <<KAFKASVC
[Unit]
Description=Apache Kafka Broker ${broker_id}
After=$AFTER_UNIT
$REQUIRES_UNIT

[Service]
Type=simple
User=kafka
Group=kafka
Environment=JAVA_HOME=/usr
Environment=KAFKA_HEAP_OPTS=${kafka_heap_opts}
ExecStart=$KAFKA_START $KAFKA_CFG
ExecStop=$KAFKA_HOME/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
KAFKASVC

systemctl daemon-reload
systemctl enable kafka
systemctl start kafka

# ─────────────────────────────────────────────
# 8. Vérification de démarrage
# ─────────────────────────────────────────────
echo "Attente démarrage Kafka (max 120s)..."
for i in $(seq 1 60); do
  nc -z localhost 9092 2>/dev/null && echo "Kafka broker ${broker_id} prêt (tentative $i)." && break
  sleep 2
done

echo "=== [$(date -u +%FT%TZ)] Installation terminée ==="
echo "  Bootstrap : $BROKER_IP:9092"
echo "  Logs      : journalctl -u kafka -f"
