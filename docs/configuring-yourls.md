<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up YOURLS

This is an [Ansible](https://www.ansible.com/) role which installs [YOURLS](https://yourls.org) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

YOURLS is a set of PHP scripts that will allow you to run Your Own URL Shortener, on your server.

See the project's [documentation](https://yourls.org/docs) to learn what YOURLS does and why it might be useful to you.

## Prerequisites

To run a YOURLS instance it is necessary to prepare a [MySQL](https://www.mysql.com/) compatible database server.

If you are looking for an Ansible role for [MariaDB](https://mariadb.org/), you can check out [this role (ansible-role-mariadb)](https://github.com/mother-of-all-self-hosting/ansible-role-mariadb) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team.

See [here](https://yourls.org/docs#server-requirements) on the official documentation to check server requirements.

## Adjusting the playbook configuration

To enable YOURLS with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# yourls                                                               #
#                                                                      #
########################################################################

yourls_enabled: true

########################################################################
#                                                                      #
# yourls                                                               #
#                                                                      #
########################################################################
```

### Set the hostname

To enable YOURLS you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
yourls_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting YOURLS under a subpath (by configuring the `yourls_path_prefix` variable) does not seem to be possible due to YOURLS's technical limitations.

### Set the admin username and password

You also need to create an instance's user to access to the admin UI after installation. To create one, add the following configuration to your `vars.yml` file. Make sure to replace `YOUR_ADMIN_USERNAME_HERE` and `YOUR_ADMIN_PASSWORD_HERE`.

```yaml
yourls_environment_variable_user: YOUR_ADMIN_USERNAME_HERE
yourls_environment_variable_pass: YOUR_ADMIN_PASSWORD_HERE
```

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `yourls_environment_variables_additional_variables` variable

For a complete list of YOURLS's config options that you could put in `yourls_environment_variables_additional_variables`, see its [environment variables](https://yourls.org/docs/guide/essentials/configuration).

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

YOURLS should be available at the specified hostname like `https://example.com`.

It can be used via [CLI client](https://github.com/timvisee/ffyourls). With the client you can upload a file specifying your host with `--host` option as below:

```sh
ffyourls upload --host https://example.com YOUR_FILE_PATH_HERE
```

To download the file, you can use `ffyourls download` command like below:

```sh
ffyourls download https://example.com/#url-to-the-uploaded-file
```

See its [documentation](https://github.com/timvisee/ffyourls/blob/master/README.md) for details about how to use the client.

### Takedown illegal materials

When a DMCA compliant was submitted or an abuse was detected, you need to remove the illegal material from the service. You can make the file inaccessible by following the steps below:

1. Take a note of an ID of the file which needs to make inaccessible. The ID is contained in the URL. For example, if the URL is https://example.com/download/fa04ec7f8ce1bc05/#PhQ5XsSkKwcLfaODf9-K3B, the file ID is `fa04ec7f8ce1bc05`.
2. Run a `DEL` command with the file ID from a host with access to the Redis server:

   ```sh
   redis-cli DEL fa04ec7f8ce1bc05
   ```

   If you run a Redis, KeyDB, or Valkey server on a Docker container along with the contaiener for YOURLS on the same server, you can directly run the command with `docker exec`:

   ```sh
   docker exec -it YOUR_CONTAINER_FOR_REDIS_HERE sh -c "redis-cli DEL fa04ec7f8ce1bc05"
   ```

   Replace `YOUR_CONTAINER_FOR_REDIS_HERE` with the Docker container's name before running the command. For example, if you enable a [Valkey instance with the playbook](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/services/valkey.md) by the MASH project, it should be `mash-valkey` (if is a shared one) or `mash-yourls-valkey` (if it is a dedicated one).

If the command returns `(integer) 1`, the record for the file has been removed, and the file has become inaccessible.

Also see: https://github.com/YOURLS/YOURLS/blob/master/docs/takedowns.md

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu yourls` (or how you/your playbook named the service, e.g. `mash-yourls`).
