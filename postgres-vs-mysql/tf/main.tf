terraform {
  required_version = ">= 1.0.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "do_token" {
  type      = string
  sensitive = true
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

provider "digitalocean" {
  token = var.do_token
}

locals {
  cloud_config_pg = templatefile("${path.module}/cloud-config-pg.yml", {
    public_key = file(var.ssh_public_key_path)
  })
  cloud_config_my = templatefile("${path.module}/cloud-config-my.yml", {
    public_key = file(var.ssh_public_key_path)
  })
}

resource "digitalocean_ssh_key" "deployer" {
  name       = "mybenchvm-key"
  public_key = file(var.ssh_public_key_path)
}


resource "digitalocean_droplet" "mybenchvm-pg" {
  image    = "ubuntu-24-04-x64"
  name     = "mybenchvm-pg"
  region   = "sgp1"
  size     = "s-8vcpu-16gb-amd"
  ssh_keys = [digitalocean_ssh_key.deployer.fingerprint]

  user_data = local.cloud_config_pg
}

resource "digitalocean_droplet" "mybenchvm-my" {
  image    = "ubuntu-24-04-x64"
  name     = "mybenchvm-my"
  region   = "sgp1"
  size     = "s-8vcpu-16gb-amd"
  ssh_keys = [digitalocean_ssh_key.deployer.fingerprint]

  user_data = local.cloud_config_my
}


output "pg_public_ip" {
  value = digitalocean_droplet.mybenchvm-pg.ipv4_address
}

output "my_public_ip" {
  value = digitalocean_droplet.mybenchvm-my.ipv4_address
}

