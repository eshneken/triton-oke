provider "oci" {}

locals {
  compartment_id = "ocid1.compartment.oc1...."
  k8s_version    = "v1.27.2"
  ssh_public_key = "ssh-rsa ..."
  gpu_node_count = "1"
  cpu_node_count = "1"
}

resource "oci_core_vcn" "generated_oci_core_vcn" {
	cidr_block = "10.0.0.0/16"
	compartment_id = local.compartment_id
	display_name = "oke-vcn-quick-triton-cluster-9594134af"
	dns_label = "tritoncluster"
}

resource "oci_core_internet_gateway" "generated_oci_core_internet_gateway" {
	compartment_id = local.compartment_id
	display_name = "oke-igw-quick-triton-cluster-9594134af"
	enabled = "true"
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_nat_gateway" "generated_oci_core_nat_gateway" {
	compartment_id = local.compartment_id
	display_name = "oke-ngw-quick-triton-cluster-9594134af"
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_service_gateway" "generated_oci_core_service_gateway" {
	compartment_id = local.compartment_id
	display_name = "oke-sgw-quick-triton-cluster-9594134af"
	services {
		service_id = "ocid1.service.oc1.iad.aaaaaaaam4zfmy2rjue6fmglumm3czgisxzrnvrwqeodtztg7hwa272mlfna"
	}
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_route_table" "generated_oci_core_route_table" {
	compartment_id = local.compartment_id
	display_name = "oke-private-routetable-triton-cluster-9594134af"
	route_rules {
		description = "traffic to the internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		network_entity_id = "${oci_core_nat_gateway.generated_oci_core_nat_gateway.id}"
	}
	route_rules {
		description = "traffic to OCI services"
		destination = "all-iad-services-in-oracle-services-network"
		destination_type = "SERVICE_CIDR_BLOCK"
		network_entity_id = "${oci_core_service_gateway.generated_oci_core_service_gateway.id}"
	}
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_subnet" "service_lb_subnet" {
	cidr_block = "10.0.20.0/24"
	compartment_id = local.compartment_id
	display_name = "oke-svclbsubnet-quick-triton-cluster-9594134af-regional"
	dns_label = "lbsub3ee427b22"
	prohibit_public_ip_on_vnic = "false"
	route_table_id = "${oci_core_default_route_table.generated_oci_core_default_route_table.id}"
	security_list_ids = ["${oci_core_vcn.generated_oci_core_vcn.default_security_list_id}"]
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_subnet" "node_subnet" {
	cidr_block = "10.0.10.0/24"
	compartment_id = local.compartment_id
	display_name = "oke-nodesubnet-quick-triton-cluster-9594134af-regional"
	dns_label = "sub262e4565b"
	prohibit_public_ip_on_vnic = "true"
	route_table_id = "${oci_core_route_table.generated_oci_core_route_table.id}"
	security_list_ids = ["${oci_core_security_list.node_sec_list.id}"]
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_subnet" "kubernetes_api_endpoint_subnet" {
	cidr_block = "10.0.0.0/28"
	compartment_id = local.compartment_id
	display_name = "oke-k8sApiEndpoint-subnet-quick-triton-cluster-9594134af-regional"
	dns_label = "suba461cd64a"
	prohibit_public_ip_on_vnic = "false"
	route_table_id = "${oci_core_default_route_table.generated_oci_core_default_route_table.id}"
	security_list_ids = ["${oci_core_security_list.kubernetes_api_endpoint_sec_list.id}"]
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_default_route_table" "generated_oci_core_default_route_table" {
	display_name = "oke-public-routetable-triton-cluster-9594134af"
	route_rules {
		description = "traffic to/from internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		network_entity_id = "${oci_core_internet_gateway.generated_oci_core_internet_gateway.id}"
	}
	manage_default_resource_id = "${oci_core_vcn.generated_oci_core_vcn.default_route_table_id}"
}

resource "oci_core_security_list" "service_lb_sec_list" {
	compartment_id = local.compartment_id
	display_name = "oke-svclbseclist-quick-triton-cluster-9594134af"
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_security_list" "node_sec_list" {
	compartment_id = local.compartment_id
	display_name = "oke-nodeseclist-quick-triton-cluster-9594134af"
	egress_security_rules {
		description = "Allow pods on one worker node to communicate with pods on other worker nodes"
		destination = "10.0.10.0/24"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = "false"
	}
	egress_security_rules {
		description = "Access to Kubernetes API Endpoint"
		destination = "10.0.0.0/28"
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
	}
	egress_security_rules {
		description = "Kubernetes worker to control plane communication"
		destination = "10.0.0.0/28"
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
	}
	egress_security_rules {
		description = "Path discovery"
		destination = "10.0.0.0/28"
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = "false"
	}
	egress_security_rules {
		description = "Allow nodes to communicate with OKE to ensure correct start-up and continued functioning"
		destination = "all-iad-services-in-oracle-services-network"
		destination_type = "SERVICE_CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
	}
	egress_security_rules {
		description = "ICMP Access from Kubernetes Control Plane"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = "false"
	}
	egress_security_rules {
		description = "Worker Nodes access to Internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Allow pods on one worker node to communicate with pods on other worker nodes"
		protocol = "all"
		source = "10.0.10.0/24"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Path discovery"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		source = "10.0.0.0/28"
		stateless = "false"
	}
	ingress_security_rules {
		description = "TCP access from Kubernetes Control Plane"
		protocol = "6"
		source = "10.0.0.0/28"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Inbound SSH traffic to worker nodes"
		protocol = "6"
		source = "0.0.0.0/0"
		stateless = "false"
	}
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_security_list" "kubernetes_api_endpoint_sec_list" {
	compartment_id = local.compartment_id
	display_name = "oke-k8sApiEndpoint-quick-triton-cluster-9594134af"
	egress_security_rules {
		description = "Allow Kubernetes Control Plane to communicate with OKE"
		destination = "all-iad-services-in-oracle-services-network"
		destination_type = "SERVICE_CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
	}
	egress_security_rules {
		description = "All traffic to worker nodes"
		destination = "10.0.10.0/24"
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
	}
	egress_security_rules {
		description = "Path discovery"
		destination = "10.0.10.0/24"
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = "false"
	}
	ingress_security_rules {
		description = "External access to Kubernetes API endpoint"
		protocol = "6"
		source = "0.0.0.0/0"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Kubernetes worker to Kubernetes API endpoint communication"
		protocol = "6"
		source = "10.0.10.0/24"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Kubernetes worker to control plane communication"
		protocol = "6"
		source = "10.0.10.0/24"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Path discovery"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		source = "10.0.10.0/24"
		stateless = "false"
	}
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_containerengine_cluster" "generated_oci_containerengine_cluster" {
	cluster_pod_network_options {
		cni_type = "FLANNEL_OVERLAY"
	}
	compartment_id = local.compartment_id
	endpoint_config {
		is_public_ip_enabled = "true"
		subnet_id = "${oci_core_subnet.kubernetes_api_endpoint_subnet.id}"
	}
	freeform_tags = {
		"OKEclusterName" = "triton-cluster"
	}
	kubernetes_version = local.k8s_version
	name = "triton-cluster"
	options {
		admission_controller_options {
			is_pod_security_policy_enabled = "false"
		}
		persistent_volume_config {
			freeform_tags = {
				"OKEclusterName" = "triton-cluster"
			}
		}
		service_lb_config {
			freeform_tags = {
				"OKEclusterName" = "triton-cluster"
			}
		}
		service_lb_subnet_ids = ["${oci_core_subnet.service_lb_subnet.id}"]
	}
	type = "ENHANCED_CLUSTER"
	vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_containerengine_node_pool" "create_gpu_pool" {
	cluster_id = "${oci_containerengine_cluster.generated_oci_containerengine_cluster.id}"
	compartment_id = local.compartment_id
	freeform_tags = {
		"OKEnodePoolName" = "gpu-pool"
	}
	initial_node_labels {
		key = "name"
		value = "triton-cluster"
	}
	initial_node_labels {
		key = "nvidia.com/gpu"
		value = "true"
	}
	kubernetes_version = local.k8s_version
	name = "gpu-pool"
	node_config_details {
		freeform_tags = {
			"OKEnodePoolName" = "gpu-pool"
		}
		node_pool_pod_network_option_details {
			cni_type = "FLANNEL_OVERLAY"
			pod_subnet_ids = [oci_core_subnet.node_subnet.id]
		}
		placement_configs {
			availability_domain = "yOlF:US-ASHBURN-AD-1"
			subnet_id = "${oci_core_subnet.node_subnet.id}"
		}
		placement_configs {
			availability_domain = "yOlF:US-ASHBURN-AD-2"
			subnet_id = "${oci_core_subnet.node_subnet.id}"
		}
		placement_configs {
			availability_domain = "yOlF:US-ASHBURN-AD-3"
			subnet_id = "${oci_core_subnet.node_subnet.id}"
		}
		size = local.gpu_node_count
	}
	node_eviction_node_pool_settings {
		eviction_grace_duration = "PT60M"
	}
	node_shape = "VM.GPU.A10.1"
	node_source_details {
		image_id = "ocid1.image.oc1.iad.aaaaaaaa7xnvcutee7u4xd2jqceqnmb4at4wzozsuoadagjfdf6bijyij5ba"
		source_type = "IMAGE"
	}
	ssh_public_key = local.ssh_public_key
}

resource "oci_containerengine_node_pool" "create_cpu_pool" {
	cluster_id = "${oci_containerengine_cluster.generated_oci_containerengine_cluster.id}"
	compartment_id = local.compartment_id
	freeform_tags = {
		"OKEnodePoolName" = "cpu-pool"
	}
	initial_node_labels {
		key = "name"
		value = "triton-cluster"
	}
	kubernetes_version = local.k8s_version
	name = "cpu-pool"
	node_config_details {
		freeform_tags = {
			"OKEnodePoolName" = "cpu-pool"
		}
		node_pool_pod_network_option_details {
			cni_type = "FLANNEL_OVERLAY"
			pod_subnet_ids = [oci_core_subnet.node_subnet.id]
		}
		placement_configs {
			availability_domain = "yOlF:US-ASHBURN-AD-1"
			subnet_id = "${oci_core_subnet.node_subnet.id}"
		}
		placement_configs {
			availability_domain = "yOlF:US-ASHBURN-AD-2"
			subnet_id = "${oci_core_subnet.node_subnet.id}"
		}
		placement_configs {
			availability_domain = "yOlF:US-ASHBURN-AD-3"
			subnet_id = "${oci_core_subnet.node_subnet.id}"
		}
		size = local.cpu_node_count
	}
	node_eviction_node_pool_settings {
		eviction_grace_duration = "PT60M"
	}
	node_shape = "VM.Standard.E4.Flex"
	node_shape_config {
		memory_in_gbs = "16"
		ocpus = "1"
	}
	node_source_details {
		image_id = "ocid1.image.oc1.iad.aaaaaaaairuqkf7p2b37jpyklvnqhxxlhyr3fpk55jmi5yklnkdrbsao7msa"
		source_type = "IMAGE"
	}
	ssh_public_key = local.ssh_public_key
}

