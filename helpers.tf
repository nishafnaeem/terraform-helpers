# We are reusing the cluster and this expects that cluster is already provisioned.
#data "google_container_cluster" "vetted-kubernetes-cluster" {
#  name     = var.google_project_settings.project
#  location = var.google_project_settings.region
#}

#resource "google_service_account" "gke-service-account" {
#  account_id   = var.google_project_settings.project
#  display_name = var.gke_cluster_settings.service_account_name
#}


resource "google_container_cluster" "primary" {
  deletion_protection = false
  name               = var.gke_cluster_settings.cluster_name
  location           = var.gke_cluster_settings.location
  node_locations = var.gke_cluster_settings.node_locations != null ? var.gke_cluster_settings.node_locations : null
  initial_node_count = var.gke_cluster_settings.default_node_pool_config.initial_nodes

  release_channel {
    channel = var.gke_cluster_settings.release_channel
  }
  node_config {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    oauth_scopes = var.gke_cluster_settings.default_node_pool_config.oauth_scopes
    image_type = var.gke_cluster_settings.default_node_pool_config.image_type
    disk_size_gb = var.gke_cluster_settings.default_node_pool_config.disk_size
    disk_type = var.gke_cluster_settings.default_node_pool_config.disk_type
    machine_type = var.gke_cluster_settings.default_node_pool_config.machine_type
    service_account = var.gke_cluster_settings.default_node_pool_config.service_account
    local_ssd_encryption_mode = var.gke_cluster_settings.default_node_pool_config.encryption
  }
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
    ]
  }
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
    ]
    managed_prometheus {
      enabled = false
    }
  }
  timeouts {
    create = "30m"
    update = "40m"
  }
}


resource "google_container_node_pool" "service_nodes" {
  for_each = { for index, value in var.gke_cluster_settings.additional_node_pool_configs : index => value }



  name       = each.value.name
  cluster    = google_container_cluster.primary.id
  node_count = 1
  location = each.value.location
  node_locations = each.value.node_locations

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
  node_config {
    machine_type = each.value.machine_type
    image_type = each.value.image_type
    disk_size_gb = each.value.disk_size
    disk_type = each.value.disk_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = each.value.service_account
    oauth_scopes = each.value.oauth_scopes


    dynamic "taint" {
       for_each = each.value.taint != null ? [each.value.taint] : []
       content {
         key    = "service_name"
         value  = taint.value
         effect = "NO_SCHEDULE"
       }
    }

    labels = each.value.node_selector != null ? {
        service_name = each.value.node_selector
    } : null
  }
  autoscaling {
    total_min_node_count = each.value.autoscaling.min_node_count
    total_max_node_count = each.value.autoscaling.max_node_count
    location_policy      = each.value.autoscaling.location
  }

  timeouts {
    create = "30m"
    update = "20m"
  }
  depends_on = [google_container_cluster.primary]
}

resource "local_file" "kube_config" {
    filename = "${path.module}/${google_container_cluster.primary.name}-config"
    content = <<-EOT
  apiVersion: v1
  kind: Config
  clusters:
  - name: ${google_container_cluster.primary.name}
    cluster:
      server: https://${google_container_cluster.primary.endpoint}
      certificate-authority-data: ${google_container_cluster.primary.master_auth[0].cluster_ca_certificate}
  contexts:
  - name: ${google_container_cluster.primary.name}
    context:
      cluster: ${google_container_cluster.primary.name}
      user: terraform_deployment_user
  current-context: ${google_container_cluster.primary.name}
  users:
    - name: terraform_deployment_user
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1beta1
          command: gke-gcloud-auth-plugin
          installHint: Install gke-gcloud-auth-plugin for use with kubectl by following
            https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke
          interactiveMode: IfAvailable
          provideClusterInfo: true
  EOT
}

output "kube_cluster_config" {
  value = google_container_cluster.primary
}
