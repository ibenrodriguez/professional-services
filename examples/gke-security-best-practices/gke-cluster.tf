# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

/*
  This file manages GKE cluster resources
*/

//create our GKE cluster
resource "google_container_cluster" "acme-cluster" {
  provider = "google-beta"
  project  = "${var.project}"
  name     = "${var.name}"
  zone     = "${var.zone}"

  //Set private cluster properties

  private_cluster_config {
    enable_private_nodes    = "${var.enable_private_nodes}"
    enable_private_endpoint = "${var.enable_private_endpoint}"
    master_ipv4_cidr_block  = "${var.master_ipv4_cidr_block}"
  }

  //private clusters require secondary address ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.network_name}-pods"
    services_secondary_range_name = "${var.network_name}-services"
  }

  //Enable regional high availability
  additional_zones = "${var.additional_zones}"

  ////Set latest GKE version
  min_master_version      = "${data.google_container_engine_versions.acme-cluster.latest_node_version}"
  enable_kubernetes_alpha = "${var.kubernetes_alpha}"

  logging_service    = "${var.logging_service}"
  monitoring_service = "${var.monitoring_service}"

  //Enable Binary Authorization
  enable_binary_authorization = "${var.enable_binary_authorization}"

  master_auth {
    //disable static username and password auth
    username = ""
    password = ""

    //^^ setting a blank username/password ^^ effectively disables PW auth

    client_certificate_config {
      //Disable Client Certificate authentication
      issue_client_certificate = false
    }
  }

  //specify a dedicated network and subnetwork
  network    = "${google_compute_subnetwork.acme-cluster.name}"
  subnetwork = "${google_compute_subnetwork.acme-cluster.name}"

  // Enable network policy and a provider
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  // If need to use legacy ABAC until these issues are resolved: 
  //   https://github.com/mcuadros/terraform-provider-helm/issues/56
  //   https://github.com/terraform-providers/terraform-provider-kubernetes/pull/73
  enable_legacy_abac = "${var.kubernetes_legacy_abac}"

  addons_config {
    http_load_balancing {
      disabled = "${var.http_load_balancing}"
    }

    horizontal_pod_autoscaling {
      disabled = "${var.horizontal_pod_autoscaling}"
    }

    //disable the  k8s dashboard as it is insecure
    kubernetes_dashboard {
      disabled = "${var.kubernetes_dashboard}"
    }
  }

  // Constrain our maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "${var.daily_maintenance_window_start_time}"
    }
  }

  lifecycle {
    ignore_changes = ["node_count"]
  }

  node_pool {
    name       = "${var.name}"
    node_count = "${var.node_count}"

    autoscaling {
      min_node_count = "${var.min_node_count}"
      max_node_count = "${var.max_node_count}"
    }

    node_config {
      preemptible      = "${var.preemptible}"
      disk_size_gb     = "${var.disk_size_gb}"
      local_ssd_count  = "${var.local_ssd_count}"
      disk_type        = "${var.disk_type}"
      machine_type     = "${var.machine_type}"
      min_cpu_platform = "${var.min_cpu_platform}"
      image_type       = "${var.image_type}"

      service_account = "${var.node_config_svc_account}@${var.project}.iam.gserviceaccount.com"

      // TODO: How to tighten the metadata service methods scopes?
      // metadata = "" //if needed
      // node_metadata_config = "" //if needed

      workload_metadata_config {
        node_metadata = "${var.workload_metadata_config}"
      }

      // Enable any required services scopes here:
      oauth_scopes = "${var.gke_oauth_scopes}"
      tags         = ["acme-dev-pool"]
    }
    management {
      auto_repair  = "${var.auto_repair}"
      auto_upgrade = true                               // Best Practice to Auto-Upgrade Nodes
    }
  }
}
