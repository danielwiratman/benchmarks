locals {
  cloud_config = templatefile("${path.module}/../config/cloud-config.yml", {
    public_key = file(var.ssh_public_key_path)
  })
}

resource "digitalocean_ssh_key" "mybenchvm-key" {
  name       = "mybenchvm-key"
  public_key = file(var.ssh_public_key_path)
}

resource "digitalocean_droplet" "mybenchvm-db" {
  image    = "ubuntu-24-04-x64"
  name     = "mybenchvm-db"
  region   = "sgp1"
  size     = "s-8vcpu-16gb-amd"
  ssh_keys = [digitalocean_ssh_key.mybenchvm-key.fingerprint]

  user_data = local.cloud_config
}

output "db_public_ip" {
  value = digitalocean_droplet.mybenchvm-db.ipv4_address
}


resource "digitalocean_droplet" "mybenchvm-benchmarker" {
  image    = "ubuntu-24-04-x64"
  name     = "mybenchvm-benchmarker"
  region   = "sgp1"
  size     = "s-2vcpu-2gb"
  ssh_keys = [digitalocean_ssh_key.mybenchvm-key.fingerprint]

  user_data = local.cloud_config
}

output "benchmarker_public_ip" {
  value = digitalocean_droplet.mybenchvm-benchmarker.ipv4_address
}

resource "ansible_host" "db" {
  name = "mybenchvm-db"
  variables = {
    ansible_host                 = digitalocean_droplet.mybenchvm-db.ipv4_address
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = var.ssh_private_key_path
  }
  groups = ["db"]
}

resource "ansible_host" "benchmarker" {
  name = "mybenchvm-benchmarker"
  variables = {
    ansible_host                 = digitalocean_droplet.mybenchvm-benchmarker.ipv4_address
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = var.ssh_private_key_path
  }
  groups = ["benchmarker"]
}

resource "ansible_group" "db" {
  name = "db"
}

resource "ansible_group" "benchmarker" {
  name = "benchmarker"
}

resource "ansible_group" "all" {
  name = "all"
  children = [
    ansible_group.db.name,
    ansible_group.benchmarker.name,
  ]
}
