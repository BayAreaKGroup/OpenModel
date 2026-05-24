resource "google_compute_instance" "t4_n1_standard" {
  name         = "t4-n1-standard"
  machine_type = "n1-standard-4"
  zone         = "us-central1-a"
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 512
    }
  }

  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral IP
    }
  }

  tags = ["t4-n1-standard"]

  metadata = {
    enable-oslogin = "TRUE"
  }

  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = false
  }

  lifecycle {
    ignore_changes = all # Do not touch this
  }
}

resource "google_compute_firewall" "t4_n1_standard_iap_ssh_allowed" {
  name    = "t4-n1-standard-iap-ssh-allowed"
  network = "default"
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = local.iap_ssh_allowed_source_ranges
  target_tags   = ["t4-n1-standard"]
}
