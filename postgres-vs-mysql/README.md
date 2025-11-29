# Benchmark Postgres vs MySQL

## Setup

```bash
# Terraform
cd infra/terraform
terraform init
terraform apply -auto-approve

# Ansible
cd infra/ansible
ansible-playbook -i inventory.yml -u root -k -K -b -e "ansible_python_interpreter=/usr/bin/python3" site.yml
```
