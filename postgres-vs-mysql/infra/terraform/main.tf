locals {
  cloud_config_db = templatefile("${path.module}/../config/cloud-config-db.yml", {
    public_key = file(var.ssh_public_key_path)
  })
  cloud_config_benchmarker = templatefile("${path.module}/../config/cloud-config-benchmarker.yml", {
    public_key = file(var.ssh_public_key_path)
  })
}

resource "digitalocean_ssh_key" "mybenchvm-key" {
  name       = "mybenchvm-key"
  public_key = file(var.ssh_public_key_path)
}

resource "digitalocean_droplet" "mybenchvm-db" {
  image    = "ubuntu-24-04-x64"
  name     = "mybenchvm-my"
  region   = "sgp1"
  size     = "s-8vcpu-16gb-amd"
  ssh_keys = [digitalocean_ssh_key.mybenchvm-key.fingerprint]

  user_data = local.cloud_config_db
}

resource "digitalocean_droplet" "mybenchvm-benchmarker" {
  image    = "ubuntu-24-04-x64"
  name     = "mybenchvm-benchmarker"
  region   = "sgp1"
  size     = "s-2vcpu-2gb"
  ssh_keys = [digitalocean_ssh_key.mybenchvm-key.fingerprint]

  user_data = local.cloud_config_benchmarker
}

output "db_public_ip" {
  value = digitalocean_droplet.mybenchvm-db.ipv4_address
}

output "benchmarker_public_ip" {
  value = digitalocean_droplet.mybenchvm-benchmarker.ipv4_address
}
