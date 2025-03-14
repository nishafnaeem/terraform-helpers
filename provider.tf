provider "google" {
    project = var.google_project_settings.project
    region  = var.google_project_settings.region
    zone    = var.google_project_settings.zone
}