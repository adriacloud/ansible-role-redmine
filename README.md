# ansible-role-redmine

Ansible role to install, configure, and upgrade [Redmine](https://www.redmine.org/) on Debian, Ubuntu, and Enterprise Linux (EL 10) systems.

## Features

- **Flexible Redmine version resolution**: Pin an exact version (`7.0.3`), a `major.minor` stream (`7.0`, `6.1`), a `major` stream (`7`, `6`), or `latest` — the role resolves the latest matching tarball from `redmine_releases_url` and verifies its SHA-256 checksum.
- **Consistent Ruby runtime**: Always installs a standalone prebuilt Ruby runtime (`/opt/ruby`) mapped by Redmine major version via `redmine_ruby_version_map`, ensuring the exact same Ruby version across all supported distributions.
- **Release-based upgrades & rollbacks**: Installs each release under `/opt/redmine/releases/redmine-<version>`, preserves `files/`, `log/`, `bundle/`, and `config/initializers/secret_token.rb` in `/opt/redmine/shared`, switches `/opt/redmine/redmine` symlink atomically, and runs `bundle install`, `db:migrate`, `redmine:plugins:migrate`, and `tmp:cache:clear` during upgrades.
- **Plugin management & upgrades**: Supports plugins from:
  - Git repositories (`repo`, optional `version`)
  - Remote archives (`url`, optional `version`, `checksum`, `sub_dir`)
  - Deploy-host local directories or archives (`src`, optional `version`, `sub_dir`)
  - Plugin removal (`state: absent`)
- **Systemd management**: Uses OpenStack-Ansible `systemd_service` role to run Puma (`redmine.service`).
- **Apache HTTPD & TLS**: Uses OpenStack-Ansible `httpd` + `pki` roles as reverse proxy, supporting:
  - Internal PKI self-signed/ownca certificates (default)
  - User-supplied certificates (`redmine_user_ssl_cert`, `redmine_user_ssl_key`, optional `redmine_user_ssl_ca_cert`)
  - Automated ACME / Let's Encrypt certificates via `certbot` (`redmine_ssl_letsencrypt_enable: true`)
  - Plain HTTP (`redmine_ssl: false`)
- **External database**: Database engine deployment is decoupled from this role (see `examples/playbook.yml` for an optional `galera_server` example).

## Requirements

Install role and collection dependencies:

```bash
ansible-galaxy install -r requirements.yml
```

## Role Variables

See [defaults/main.yml](defaults/main.yml) for the complete list and documentation of all variables.

## Example Playbook

See [examples/playbook.yml](examples/playbook.yml).

## Testing

Tests use Tox and Molecule with Docker:

```bash
tox -e linters
tox -e molecule-deploy
REDMINE_N1_RELEASE=6.1.6 REDMINE_RELEASE=7.0.3 tox -e molecule-upgrade
```

You can also override `DOCKER_IMAGE_TAG` and `REDMINE_RELEASE` (e.g. `DOCKER_IMAGE_TAG=rockylinux-systemd:10 REDMINE_RELEASE=7 tox -e molecule-deploy`).

## License

Apache-2.0
