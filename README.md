# ansible-role-redmine

[![Molecule](https://github.com/adriacloud/ansible-role-redmine/actions/workflows/molecule.yml/badge.svg)](https://github.com/adriacloud/ansible-role-redmine/actions/workflows/molecule.yml)
[![Unit Tests](https://github.com/adriacloud/ansible-role-redmine/actions/workflows/linters.yml/badge.svg)](https://github.com/adriacloud/ansible-role-redmine/actions/workflows/linters.yml)



Ansible role to install, configure, and upgrade [Redmine](https://www.redmine.org/) on Debian, Ubuntu, and Enterprise Linux (EL 10) systems.

## Features

- **Flexible Redmine version resolution**: Pin an exact version (`7.0.3`), a `major.minor` stream (`7.0`, `6.1`), a `major` stream (`7`, `6`), or `latest` — the role resolves the latest matching tarball from `redmine_releases_url` and verifies its SHA-256 checksum.
- **Consistent Ruby runtime**: Always installs a standalone prebuilt Ruby runtime (`/opt/ruby`) mapped by Redmine major version via `redmine_ruby_version_map`, ensuring the exact same Ruby version across all supported distributions.
- **Release-based upgrades & rollbacks**: Installs each release under `/opt/redmine/releases/redmine-<version>`, preserves `files/`, `log/`, `bundle/`, and `config/initializers/secret_token.rb` in `/opt/redmine/shared`, switches `/opt/redmine/redmine` symlink atomically, and runs `bundle install`, `db:migrate`, `redmine:plugins:migrate`, and `tmp:cache:clear` during upgrades.
- **Plugin & theme management & upgrades**: Supports plugins (`redmine_plugins`) and themes (`redmine_themes`, targeting `themes/` on Redmine ≥ 6 or `public/themes/` on Redmine 5) from:
  - Git repositories (`repo`, optional `version`)
  - Remote archives (`url`, optional `version`, `checksum`, `sub_dir`)
  - Deploy-host local directories or archives (`src`, optional `version`, `sub_dir`)
  - Removal (`state: absent`)
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

### Plugin Installation

Configure `redmine_plugins` to install, upgrade, or remove plugins from Git repositories, remote archives, or deploy-host paths:

```yaml
redmine_plugins:
  # From a Git repository (init.rb must be at the repository root)
  - name: redmine_code_review
    repo: https://github.com/haru/redmine_code_review.git
    version: "1.2.2" # branch, tag, or commit SHA (defaults to HEAD)

  # From a remote archive (.tar.gz, .tgz, .tar.bz2, .tar.xz, .zip)
  - name: redmine_issue_templates
    url: https://github.com/agileware-jp/redmine_issue_templates/archive/refs/tags/v1.2.3.tar.gz
    version: "1.2.3" # optional metadata marker to trigger re-extraction on version bump
    # checksum: "sha256:..." # optional get_url checksum
    # sub_dir: "redmine_issue_templates-1.2.1" # optional if not root or single top-level dir

  # From a local directory or archive on the Ansible control/deploy host
  - name: my_local_plugin
    src: "{{ playbook_dir }}/files/my_local_plugin/"

  - name: my_local_archive_plugin
    src: "{{ playbook_dir }}/files/my_local_archive_plugin.tar.gz"
    version: "0.1.0"

  # Remove an existing plugin
  - name: old_plugin
    state: absent
```

After installing or removing plugins, the role runs `bundle install`, `rake redmine:plugins:migrate`, `rake tmp:cache:clear`, and restarts `redmine.service`.

### Theme Installation

Configure `redmine_themes` using the same `repo`, `url`, `src`, and `state: absent` options (`themes/` is used on Redmine ≥ 6, `public/themes/` on Redmine 5):

```yaml
redmine_themes:
  - name: bleuclair
    url: https://github.com/farend/redmine_theme_farend_bleuclair/archive/refs/tags/v2.0.3.zip
    version: "2.0.3"

  - name: my_custom_theme
    src: "{{ playbook_dir }}/files/my_custom_theme/"
```

After theme changes on Redmine ≥ 6, the role runs `rake assets:precompile`, `rake tmp:cache:clear`, and restarts `redmine.service`.

### Custom Environment, Files, Shared Directories, and Lifecycle Hooks

For plugins or deployments that require extra Rails configuration, persistent directories, environment variables, or one-time setup tasks (such as Active Storage for `redmine_dmsf` 5.x, sub-URI mounts, or custom initializers), the role provides:

- `redmine_extra_env`: Dictionary of extra environment variables passed to both `redmine.service` and Bundler/Rake tasks.
- `redmine_extra_rb_environment`: Mapping of named Ruby snippets rendered (sorted by key, skipping empty/null entries) into `config/additional_environment.rb`.
- `redmine_extra_shared_dirs`: Directories created under `redmine_shared_dir` and symlinked into each release.
- `redmine_extra_files`: Extra files rendered into the release (`dest`, plus `content`, `yaml`, or `src`, and optional `mode`, `owner`, `group`, `state`).
- `redmine_pre_migrate_commands` / `redmine_post_migrate_commands`: Commands run inside the release directory before `db:migrate` or after `redmine:plugins:migrate` (`command`, plus optional `name`, `fact_key`, `creates`, `check_command`, `notify_restart`).

#### Example: Enabling Active Storage (e.g., for `redmine_dmsf` 5.x)

```yaml
redmine_extra_shared_dirs:
  - dmsf_as

redmine_extra_rb_environment:
  active_storage: |
    require 'active_storage/engine'
    require Rails.root.join('plugins', 'redmine_dmsf', 'lib', 'redmine_dmsf', 'xapian_analyzer').to_s
    config.active_storage.service = :local
    config.active_storage.analyzers.append RedmineDmsf::XapianAnalyzer

redmine_extra_files:
  - dest: config/storage.yml
    yaml:
      local:
        service: Disk
        root: "{{ redmine_shared_dir }}/dmsf_as"

redmine_pre_migrate_commands:
  - name: Install Active Storage migrations
    command: bundle exec rails active_storage:install
    fact_key: active_storage_installed
```

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
