#!/usr/bin/env bash

set -Eeuo pipefail

# Clone and install an OpenWrt package repository.
#
# Arguments:
#   $1 package matching name
#   $2 GitHub repository
#   $3 branch
#   $4 special mode: pkg or name
#   $5 additional matching names, separated by spaces
UPDATE_PACKAGE() {
	local PKG_NAME="${1:?Missing package name}"
	local PKG_REPO="${2:?Missing repository}"
	local PKG_BRANCH="${3:?Missing branch}"
	local PKG_SPECIAL="${4:-}"
	local EXTRA_NAMES="${5:-}"
	local REPO_NAME="${PKG_REPO##*/}"

	local -a PKG_LIST=("$PKG_NAME")
	local -a EXTRA_NAME_LIST=()

	if [[ -n "$EXTRA_NAMES" ]]; then
		read -r -a EXTRA_NAME_LIST <<< "$EXTRA_NAMES"
		PKG_LIST+=("${EXTRA_NAME_LIST[@]}")
	fi

	echo
	echo "========== Updating ${PKG_NAME} =========="

	# Remove old packages from the official feeds.
	for NAME in "${PKG_LIST[@]}"; do
		[[ -z "$NAME" ]] && continue

		echo "Searching existing package: ${NAME}"

		local FOUND_DIRS
		FOUND_DIRS="$(
			find ../feeds/luci ../feeds/packages \
				-maxdepth 3 \
				-type d \
				-iname "*${NAME}*" \
				-print \
				2>/dev/null || true
		)"

		if [[ -n "$FOUND_DIRS" ]]; then
			while IFS= read -r DIR; do
				[[ -z "$DIR" ]] && continue

				rm -rf -- "$DIR"
				echo "Deleted directory: ${DIR}"
			done <<< "$FOUND_DIRS"
		else
			echo "No existing package found: ${NAME}"
		fi
	done

	# Remove a previous clone.
	rm -rf -- "./${REPO_NAME}"

	# Clone the repository.
	git clone \
		--depth=1 \
		--single-branch \
		--branch "$PKG_BRANCH" \
		"https://github.com/${PKG_REPO}.git" \
		"./${REPO_NAME}"

	case "$PKG_SPECIAL" in
		pkg)
			local COPIED_COUNT=0
			local -A COPIED_DIRS=()

			# Copy only matching package directories from a multi-package repository.
			for NAME in "${PKG_LIST[@]}"; do
				while IFS= read -r -d '' DIR; do
					[[ -f "${DIR}/Makefile" ]] || continue

					# Avoid copying the same directory twice.
					if [[ -n "${COPIED_DIRS["$DIR"]+exists}" ]]; then
						continue
					fi

					cp -a -- "$DIR" ./
					COPIED_DIRS["$DIR"]=1
					COPIED_COUNT=$((COPIED_COUNT + 1))

					echo "Copied package: ${DIR}"
				done < <(
					find "./${REPO_NAME}" \
						-mindepth 1 \
						-maxdepth 4 \
						-type d \
						-iname "$NAME" \
						-print0
				)
			done

			if (( COPIED_COUNT == 0 )); then
				echo "No package directory found in ${PKG_REPO}" >&2
				exit 1
			fi

			rm -rf -- "./${REPO_NAME}"
			;;

		name)
			rm -rf -- "./${PKG_NAME}"
			mv -- "./${REPO_NAME}" "./${PKG_NAME}"
			;;

		"")
			# Keep the cloned repository as a package feed.
			;;

		*)
			echo "Unsupported package mode: ${PKG_SPECIAL}" >&2
			exit 1
			;;
	esac
}

# --------------------------------------------------------------------
# Required packages only
# --------------------------------------------------------------------

# Aurora theme
UPDATE_PACKAGE \
	"aurora" \
	"eamonxg/luci-theme-aurora" \
	"master"

# PassWall.
# The repository may contain both "passwall" and "luci-app-passwall".
UPDATE_PACKAGE \
	"passwall" \
	"Openwrt-Passwall/openwrt-passwall" \
	"main" \
	"pkg" \
	"luci-app-passwall"

# Lucky LuCI application
UPDATE_PACKAGE \
	"luci-app-lucky" \
	"gdy666/luci-app-lucky" \
	"main" \
	"" \
	"lucky"

# MosDNS
UPDATE_PACKAGE \
	"mosdns" \
	"sbwml/luci-app-mosdns" \
	"v5"

# Gecoosac
UPDATE_PACKAGE \
	"gecoosac" \
	"laipeng668/luci-app-gecoosac" \
	"main"

# microsocks is provided by the upstream OpenWrt/ImmortalWrt feeds.
# It does not need to be cloned here.

echo
echo "========== Package source update completed =========="
