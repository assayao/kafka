output "vcn_id" {
  description = "OCID du VCN"
  value       = oci_core_vcn.this.id
}

output "vcn_cidr" {
  description = "Bloc CIDR du VCN"
  value       = var.vcn_cidr
}

output "public_subnet_id" {
  description = "OCID du sous-réseau public"
  value       = oci_core_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR du sous-réseau public"
  value       = oci_core_subnet.public.cidr_block
}

output "private_subnet_id" {
  description = "OCID du sous-réseau privé principal"
  value       = oci_core_subnet.private.id
}

output "private_subnet_cidr" {
  description = "CIDR du sous-réseau privé principal"
  value       = oci_core_subnet.private.cidr_block
}

output "private_additional_subnet_ids" {
  description = "OCIDs des sous-réseaux privés additionnels"
  value       = { for k, v in oci_core_subnet.private_additional : k => v.id }
}

output "igw_id" {
  description = "OCID de l'Internet Gateway"
  value       = oci_core_internet_gateway.igw.id
}

output "nat_gw_id" {
  description = "OCID de la NAT Gateway"
  value       = oci_core_nat_gateway.nat.id
}

output "service_gw_id" {
  description = "OCID de la Service Gateway"
  value       = oci_core_service_gateway.svc_gw.id
}
