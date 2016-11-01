# Instructions

- Install Docker.
- `pip install -r requirements.txt` to install Ansible
- Generate ssh keys for local test: `ssh-keygen -t rsa -f dev/id_rsa`
- Run it: `dev/test.sh -fc`
- `dev/test.sh --help` for available options.

# Files in `dev/`:

- `dev/inventory` - hosts setup for local dev. Mirrors main ansible `inventory` file, but with `*.ans.local` hostnames.
- `dev/vars.yml` - put vars in there that should override vars from main ansible config.
- `dev/Dockerfile` - Dockerfile for test containers.

# How it works:

- Docker image `ansible_local_test` is built.
- `dev/inventory` is parsed to pull out hostnames like `*.ans.local`.
- For each hostname:
  - An alias IP is created and added to lo0.
  - An `/etc/hosts` entry is added pointing to corresponding alias ip.
  - Docker container started from `ansible_local_test` for each hostname:
  - Container name is hostname.
  - Port `22` exposed on alias IP.
  - Host docker socket mounted into container.