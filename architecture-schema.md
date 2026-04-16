# Schema d'architecture Kafka

Ce document decrit l'architecture deploiyee par Terraform dans ce projet.

## Vue d'ensemble

```mermaid
flowchart TB
    U["Administrateur / Operateur"] -->|SSH 22| B["Bastion OCI\nSubnet public\nIP publique"]
    U -->|Terraform apply| TF["Terraform\nRoot module"]

    TF --> N["Module network"]
    TF --> S["Module security"]
    TF --> K["Module kafka"]

    N --> VCN["VCN OCI"]
    VCN --> PUB["Public Subnet"]
    VCN --> PRIV["Private Subnet"]
    VCN --> IGW["Internet Gateway"]
    VCN --> NAT["NAT Gateway"]
    VCN --> SGW["Service Gateway"]

    S --> BNSG["NSG Bastion"]
    S --> KNSG["NSG Brokers"]

    PUB --> B
    BNSG --> B

    PRIV --> K1["Broker 0"]
    PRIV --> K2["Broker 1"]
    PRIV --> K3["Broker N"]
    KNSG --> K1
    KNSG --> K2
    KNSG --> K3

    K --> V1["Volume data 0"]
    K --> V2["Volume data 1"]
    K --> V3["Volume data N"]

    V1 --> K1
    V2 --> K2
    V3 --> K3

    B -->|SSH rebond| K1
    B -->|SSH rebond| K2
    B -->|SSH rebond| K3

    K1 <-->|Kafka inter-broker / KRaft / ZooKeeper| K2
    K2 <-->|Kafka inter-broker / KRaft / ZooKeeper| K3
    K1 <-->|Kafka inter-broker / KRaft / ZooKeeper| K3

    PRIV -->|Sortie packages| NAT
    PUB -->|Entree/sortie Internet| IGW
    PRIV -->|Services OCI| SGW
```

## Composants principaux

- `network` cree le VCN, les subnets, les gateways, les route tables et les security lists.
- `security` cree les NSG pour le bastion et les brokers Kafka.
- `kafka` cree les instances brokers, les volumes de donnees, le bastion optionnel et le bootstrap des services.

## Flux principaux

- Acces administration: Internet vers bastion, puis SSH vers les brokers.
- Acces Kafka: clients internes vers les brokers sur le port `9092`.
- Communication interne du cluster: ports KRaft ou ZooKeeper selon le mode deploye.
- Sortie reseau des brokers: NAT Gateway pour paquets, Service Gateway pour services OCI.
