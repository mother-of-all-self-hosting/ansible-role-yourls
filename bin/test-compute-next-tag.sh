#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the real
# script, tagging as it goes just like the autotag workflow does. This repository is
# never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at YOURLS 1.10.4 which has already seen two
# releases of it (v1.10.4-0 and v1.10.4-1), plus `v1-0` and `v1.10-0`. Docker Hub
# publishes floating `1` and `1.10` tags alongside the real ones, and the
# commit-message era read the version straight out of Renovate's subject line, so
# tags shaped like that are exactly what a regression would produce. They must not
# be counted as releases of anything.
#
# The defaults file carries the traps this role's real one has: a commented-out
# example of the version variable, an image tag derived from it, and a second
# variable whose name also ends in `_version` but holds a commit SHA of an
# unrelated repository. None of them may be picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# yourls_version: 9.9.9
		# renovate: datasource=docker depName=yourls versioning=semver
		yourls_version: 1.10.4
		yourls_container_image: "{{ yourls_container_image_registry_prefix }}yourls:{{ yourls_container_image_tag }}"
		yourls_container_image_tag: "{{ yourls_version }}"
		yourls_container_image_self_build_repo_version: "decafc1d99dabbf82d3d47a17bae6f8ce3d71007"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v1-0 v1.10-0 v1.10.4-0 v1.10.4-1; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^yourls_version: 1.10.4|yourls_version: 1.10.5|' defaults/main.yml"
revert_version="sed -i 's|^yourls_version: 1.10.5|yourls_version: 1.10.4|' defaults/main.yml"
bump_selfbuild_revision="sed -i 's|decafc1d99dabbf82d3d47a17bae6f8ce3d71007|0123456789abcdef0123456789abcdef01234567|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a field\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with every
# update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v1.10.5-0 "$(merge "$bump_version")"
expect 'task edit'    v1.10.5-1 "$(merge "$edit_task")"
expect 'template'     v1.10.5-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v1.10.4-2 "$(merge "$edit_task")"
expect 'version bump' v1.10.5-0 "$(merge "$bump_version")"

# `v1-0` and `v1.10-0` exist in every scenario. If the version were ever read as a
# bare major or as `major.minor` - which is exactly what Docker Hub's floating tags
# and the commit-message era invite - the counter would continue from those instead
# of starting afresh.
scenario 'The floating tags that a version misread would land on'
expect 'a task' v1.10.4-2 "$(merge "$edit_task")"

# The self-build revision is a commit SHA of YOURLS/containers, not a YOURLS
# version, but the variable holding it also ends in `_version`. Bumping it is a real
# change to the role, so it releases - as a release of the YOURLS version that
# defaults/main.yml still pins, never as a release of the SHA.
scenario 'A self-build revision bump'
expect 'self-build revision' v1.10.4-2 "$(merge "$bump_selfbuild_revision")"

scenario 'Commits that do not affect the role'
expect 'README'   ''          "$(merge "$edit_readme")"
expect 'a script' ''          "$(merge "$edit_script")"
expect 'meta'     v1.10.4-2   "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v1.10.4-$release_number"
done
expect 'a task' v1.10.4-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v1.10.4-1 already published, so there is
# nothing new to release.
expect 'a revert' '' "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v1.10.4-2 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
