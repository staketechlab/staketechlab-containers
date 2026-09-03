# StakeTechLab Containers

One-command installers for the Docker containers I actually run on my
homelab — the same stack you can read about at
[staketechlab.com](https://staketechlab.com). Each app ships with a tested
`docker-compose.yml`, a starter config, and install notes that cover the
parts that usually aren't in the README: reverse-proxy wiring, hostname
gotchas, and what I changed from the default setup.

Everything here is MIT-licensed and readable — read the script before you
run it.

## Requirements

- A Linux box — any distro Docker supports (the commands below are Ubuntu / Debian flavored)
- **Docker Engine** installed
- **Docker Compose** — the v2 plugin (`docker compose`) or the standalone binary (`docker-compose`) both work; the installer detects either
- Your user in the `docker` group, so no `sudo` is needed to run containers
- No root required for the installer itself

**First time with Docker?** On Ubuntu / Debian this installs Engine + the Compose plugin:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # then log out and back in
docker --version && docker compose version   # sanity check
```

## Quick start

```bash
# Clone and install, or fetch just the installer:
git clone https://github.com/staketechlab/staketechlab-containers.git
cd staketechlab-containers
./install.sh homepage

# One-liner (no clone):
bash <(curl -fsSL https://raw.githubusercontent.com/staketechlab/staketechlab-containers/main/install.sh) homepage
```

The installer picks a sensible default (`~/docker/<app>`, port `3000`) —
override either:

```bash
./install.sh homepage ~/docker/homepage 8080
```

## Apps

| App | What it is | Blog post |
|-----|-----------|-----------|
| `homepage` | gethomepage.dev — the dashboard in front of my whole homelab | https://staketechlab.com/homepage-the-dashboard-in-front-of-my-whole-homelab-with-a-one-line-installer/ |

More apps land weekly — the catalog is the point.

## Notes & conventions

- Ubuntu 24.04 + Docker Engine + compose plugin assumed; nothing here
  needs root (install to `~/docker/...`, your user just needs to be in the
  `docker` group).
- Secrets never live in `config/*.yaml`. Use `{{HOMEPAGE_VAR_...}}`
  placeholders and put real values in the `.env` file next to
  `docker-compose.yml` (it's gitignored).
- Exposed to the internet? These apps have no login of their own — put a
  reverse proxy + SSO (Authentik, Authelia) in front of them, the way I do.

## License

MIT — do whatever you want with it, but no warranty, and run scripts you
found on the internet at your own risk. (Including mine.)
