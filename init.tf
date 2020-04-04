provider "google" {
  project = "miroc-sandbox"
  region = "europe-west6"
}

provider "kubernetes" {
  host = google_container_cluster.core.endpoint
  username = google_container_cluster.core.master_auth[0].username
  password = google_container_cluster.core.master_auth[0].password
  client_certificate = base64decode(google_container_cluster.core.master_auth.0.client_certificate)
  client_key = base64decode(google_container_cluster.core.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.core.master_auth.0.cluster_ca_certificate)
}

resource "google_container_cluster" "core" {
  name = "todo"
  location = "europe-west6-b"
  provider = google

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name = "todo"
  location = "europe-west6-b"
  cluster = google_container_cluster.core.name
  node_count = 2

  node_config {
    preemptible = true
    machine_type = "n1-standard-1"
    disk_size_gb = 30

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
  depends_on = [
    google_container_cluster.core
  ]
}

resource "kubernetes_namespace" "default_namespace" {
  metadata {
    labels = {
      istio-injection = "enabled"
    }
    name = "default"
  }
  depends_on = [
    google_container_cluster.core
  ]
}
