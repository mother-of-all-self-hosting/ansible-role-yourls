<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

Currently these testing scenarios are available:

Both scenarios run YOURLS against a MariaDB installed by [ansible-role-mariadb](https://github.com/mother-of-all-self-hosting/ansible-role-mariadb) and reached over a Unix socket, and both deliberately configure a port, a database name and a table prefix that are *not* the role's defaults, so that a configuration file which never reached the container shows up as a failure rather than as a pass.

Neither YOURLS nor its container image creates the database schema: a freshly deployed instance answers HTTP but has no tables, and 307-redirects every path — including `/nonexistent` — to `/admin/install.php`, which itself answers 200. Because of that, "the endpoint responds" proves nothing here. Each scenario performs the installation itself (as a Molecule `side_effect`) and then verifies against surfaces that an uninstalled instance cannot produce.

### `default`

Tests a standard YOURLS installation, using the container image the role pins.

The verification does not stop at "the systemd service is active" — `Restart=always` makes even a crash-looping container look active. It:

- asserts the running container came from `docker.io/yourls:<yourls_version>`
- asserts the admin area answers 200 without following redirects, which it only does once the schema exists (an uninstalled YOURLS, and one with a pending schema upgrade, both 307-redirect away instead)
- asserts the application-reported version matches the version the role pins after allowing only an optional terminal `-dev` suffix, and that the page carries that exact application version and the configured site URL
- creates a short URL over the YOURLS API using the credentials the role wrote into `env`, and checks the returned short URL was built from `yourls_environment_variable_site`
- checks that the same API call with a wrong password is refused, so that the successful call above means something
- follows the short URL without following redirects, and asserts it answers 301 to the exact target
- reads the row back out of MariaDB, under the database name and table prefix this scenario configured
- asserts the version YOURLS recorded in its own options table exactly matches the version the running application reports

### `default-selfbuild`

Tests the same installation with `yourls_container_image_self_build` enabled.

It repeats the round trip above on a different port and with a different probe keyword, and adds what is specific to self-building: that the container runs the locally built image rather than the published one, that the cloned source tree sits at the pinned revision, and that the image's packaged version matches the `yourls_version` file which upstream's build recipe ships — which is what proves the image really was built from this source tree, rather than resolved from a cache. The application-reported version may additionally carry a terminal `-dev` suffix, but the rendered page and database must agree with that exact value.

The scenario prints, but does not assert, how the packaged YOURLS compares with `yourls_version`. Upstream publishes the release and the build recipe for it as two separate things, so Renovate bumps them as two updates that are allowed to disagree until both have landed.

This scenario is not part of the regular CI matrix. It runs on branches where a `*_version:` line in `defaults/main.yml` changed, and on manual `workflow_dispatch`.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
