# Terraform GKE Cluster Configuration
This repository contains Terraform code to provision a Google Kubernetes Engine (GKE) cluster with multiple node pools. Below are the key highlights and instructions for using this configuration.  


## Important Concepts
### Looping Over a List of Dictionaries
In the google_container_node_pool resource, we loop over a list of dictionaries using the for_each construct. This allows us to dynamically create multiple node pools based on the configuration provided in the .env.tfvars file.
By default the `for_each` loop only except map of objects. So if you have a list you can do `{ for index, value in var.gke_cluster_settings.additional_node_pool_configs : index => value }` to generate a map of objects against your list which can be used with `for_each` attribute.

```terraform
resource "google_container_node_pool" "service_nodes" {
  for_each = { for index, value in var.gke_cluster_settings.additional_node_pool_configs : index => value }

  name       = each.value.name
  cluster    = google_container_cluster.primary.id
  node_count = 1
  location   = each.value.location
  node_locations = each.value.node_locations

  # Other configurations...
}
```

### Defining Optional Blocks with Dynamic Resource
We use the dynamic block to define optional blocks within the google_container_node_pool resource. This is useful for conditionally including blocks based on the presence of certain values.
```terraform
dynamic "taint" {
  for_each = each.value.taint != null ? [each.value.taint] : []
  content {
    key    = "service_name"
    value  = taint.value
    effect = "NO_SCHEDULE"
  }
}
```

### Making Resource Attributes Optional
To make resource attributes optional, we use conditional expressions. For example, the node_locations attribute is set to null if it is not provided.
```terraform
resource "google_container_cluster" "primary" {
  # Other configurations...

  node_locations = var.gke_cluster_settings.node_locations != null ? var.gke_cluster_settings.node_locations : null

  # Other configurations...
}
```

### Making Resource Attributes Optional
To make resource attributes optional, we use conditional expressions. For example, the node_locations attribute is set to null if it is not provided.
```terraform
resource "google_container_cluster" "primary" {
  # Other configurations...

  node_locations = var.gke_cluster_settings.node_locations != null ? var.gke_cluster_settings.node_locations : null

  # Other configurations...
}
```

### Terraform List Order Sensitivity
When using lists in Terraform to provision multiple resources, the order of elements within the list matters significantly. If you rely on the index of list elements to define your resources (e.g., using `count.index` or accessing elements directly by index), changing the order of the list will trigger Terraform to perceive these resources as new or modified.

**Specifically:**

* If you have a list like `["resource1", "resource2", "resource3"]` and use `count.index` or direct indexing to create resources, Terraform associates `resource1` with index 0, `resource2` with index 1, and `resource3` with index 2.
* If you then change the list order to `["resource2", "resource3", "resource1"]`, Terraform now sees `resource2` at index 0, `resource3` at index 1, and `resource1` at index 2.
* Even though the actual resource values haven't changed, Terraform interprets this as a complete change in the resources at each index, leading to the destruction of the old resources and the creation of new ones.

**This results in unnecessary destruction and recreation of resources, leading to potential downtime and increased deployment times.**

**Why This Happens**

Terraform's default behavior is to track resources based on their identifiers and their position within the configuration. When you use list indices, the index becomes a critical part of the resource's identifier. Therefore, a change in list order is interpreted as a change in the resource itself.

**Solution: Use Unique Identifiers**

To avoid this issue, it is highly recommended to use unique identifiers for your resources instead of relying on list indices. This can be accomplished in several ways:

1.  **Use `for_each` with a Map:**
    * If possible, convert your list into a map where each resource has a unique key.
    * Use the `for_each` meta-argument to iterate over the map, using the keys as unique identifiers.
    * This provides a much more stable method of resource management.

    ```terraform
    variable "resources" {
      type = map(string)
      default = {
        resource1 = "value1"
        resource2 = "value2"
        resource3 = "value3"
      }
    }

    resource "example_resource" "example" {
      for_each = var.resources
      name     = each.key
      value    = each.value
    }
    ```

2.  **Use Unique Values in a List with `for_each`:**
    * If you must use a list, ensure that the elements are unique.
    * Use `for_each` with `toset()` to create a set from the list, ensuring uniqueness and allowing Terraform to identify resources by their unique values.

    ```terraform
    variable "resources" {
      type = list(string)
      default = ["resource1", "resource2", "resource3"]
    }

    resource "example_resource" "example" {
      for_each = toset(var.resources)
      name     = each.value
    }
    ```

3.  **Generate Unique Identifiers:**
    * If your list does not contain unique values, generate unique identifiers based on the list elements or other relevant data.

**Key Takeaways**

* Avoid using list indices (`count.index`) to define resources whenever possible.
* Use unique identifiers to ensure Terraform can correctly track and manage resources.
* Prefer `for_each` with maps or sets for more robust and predictable resource management.
* Always test your terraform code in a development environment before applying it to production.

## Usage
- Clone the repository:  
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```
- Configure the .env.tfvars file: Update the .env.tfvars file with your desired GKE cluster settings.  
- Initialize Terraform:  
    ```bash
    terraform init
    ```

- Apply the Terraform configuration:
    ```bash
    terraform apply -var-file=".env.tfvars"
    ```