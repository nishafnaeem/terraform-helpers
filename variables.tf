variable "gke_cluster_settings" {
  type = object({
    cluster_name = string
    location = string
    node_locations = optional(list(string))
    release_channel = string
    service_account_name = string
    default_node_pool_config = object({
      oauth_scopes = list(string)
      image_type = string
      machine_type = string
      disk_size = number
      disk_type = string
      initial_nodes = number
      service_account = string
      encryption = string
    })
    additional_node_pool_configs = list(object({
      name            = string
      oauth_scopes    = list(string)
      image_type      = string
      machine_type    = string
      disk_size       = number
      disk_type       = string
      service_account = string
      encryption      = string
      node_selector   = optional(string)
      taint           = optional(string)
      location        = string
      node_locations  = list(string)
      autoscaling     = object({
        min_node_count = number
        max_node_count = number
        location       = string
      })
    }))
  })
}

variable "google_project_settings" {
    description = "The Google project settings"
    type        = object({
        project = string
        region  = string
        zone    = string
    })
}
