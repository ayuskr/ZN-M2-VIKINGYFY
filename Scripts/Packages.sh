#!/usr/bin/env bash

set -Eeuo pipefail

# Install or update packages from an OpenWrt package repository.
#
# Arguments:
#   $1: Primary package name
#   $2: GitHub repository, for example owner/repository
#   $3: Repository branch
#   $4: Repository mode:
#       root - repository root is an OpenWrt package
#       pkg  - extract package directories from a multi-package repository
#   $5: Additional package names separated by spaces
UPDATE_PACKAGE() {
	local PKG_NAME="${1:?Missing package name}"
	local PKG_REPO="${2:?Missing GitHub repository}"
	local PKG_BRANCH="${3:?Missing repository branch}"
	local PKG_MODE="${4:-root}"
	local EXTRA_NAMES="${5:-}"
	local REPO_NAME="${PKG_REPO##*/}"
	local CLONE_DIR="./.source-${REPO_NAME}"

	local -a PKG_LIST=("$PKG_NAME")
	local -a EXTRA_NAME_LIST=()

	if [[ -n "$EXTRA_NAMES" ]]; then
		read -r -a EXTRA_NAME_LIST <<< "$EXTRA_NAMES"
		PKG_LIST+=("${EXTRA_NAME_LIST[@]}")
	fi

	echo
	echo "========== Updating ${PKG_NAME} =========="

	# Remove old or conflicting package directories.
	for NAME in "${PKG_LIST[@]}"; do
		[[ -z "$NAME" ]] && continue

		echo "Searching existing package: ${NAME}"

		local FOUND_DIRS
		FOUND_DIRS="$(
			find \
				../feeds/luci \
				../feeds/packages \
				. \
				-mindepth 1 \
				-maxdepth 6 \
				-type d \
				-name "$NAME" \
				-not -path './.source-*' \
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

	# Remove leftovers from previous workflow runs.
	rm -rf -- "$CLONE_DIR"
	rm -rf -- "./${REPO_NAME}"

	git clone \
		--depth=1 \
		--single-branch \
		--branch "$PKG_BRANCH" \
		"https://github.com/${PKG_REPO}.git" \
		"$CLONE_DIR"

	case "$PKG_MODE" in
		root)
			# The repository root itself must be an OpenWrt package.
			if [[ ! -f "${CLONE_DIR}/Makefile" ]]; then
				echo "ERROR: repository root has no Makefile: ${PKG_REPO}"
				echo "Available Makefiles:"

				find "$CLONE_DIR" \
					-mindepth 2 \
					-maxdepth 7 \
					-type f \
					-name Makefile \
					-print || true

				rm -rf -- "$CLONE_DIR"
				exit 1
			fi

			rm -rf -- "./${PKG_NAME}"
			mv -- "$CLONE_DIR" "./${PKG_NAME}"
			rm -rf -- "./${PKG_NAME}/.git"

			echo "Installed root package: ./${PKG_NAME}"
			;;

		pkg)
			local COPIED_COUNT=0
			local NAME
			local DIR
			local TARGET_DIR
			local -A COPIED_DIRS=()

			# Extract each requested package directory containing a Makefile.
			for NAME in "${PKG_LIST[@]}"; do
				while IFS= read -r -d '' DIR; do
					[[ -f "${DIR}/Makefile" ]] || continue

					if [[ -n "${COPIED_DIRS["$DIR"]+exists}" ]]; then
						continue
					fi

					TARGET_DIR="./$(basename "$DIR")"

					rm -rf -- "$TARGET_DIR"
					cp -a -- "$DIR" "$TARGET_DIR"
					rm -rf -- "${TARGET_DIR}/.git"

					COPIED_DIRS["$DIR"]=1
					COPIED_COUNT=$((COPIED_COUNT + 1))

					echo "Copied package: ${DIR} -> ${TARGET_DIR}"
				done < <(
					find "$CLONE_DIR" \
						-mindepth 1 \
						-maxdepth 7 \
						-type d \
						-name "$NAME" \
						-print0
				)
			done

			if (( COPIED_COUNT == 0 )); then
				echo "ERROR: no requested package was found in ${PKG_REPO}"
				echo "Requested package names: ${PKG_LIST[*]}"
				echo "Available package Makefiles:"

				find "$CLONE_DIR" \
					-maxdepth 8 \
					-type f \
					-name Makefile \
					-print || true

				rm -rf -- "$CLONE_DIR"
				exit 1
			fi

			# Confirm that every requested package was extracted.
			for NAME in "${PKG_LIST[@]}"; do
				if [[ ! -f "./${NAME}/Makefile" ]]; then
					echo "ERROR: requested package was not extracted: ${NAME}"
					echo "Repository: ${PKG_REPO}"
					echo "Available Makefiles:"

					find "$CLONE_DIR" \
						-maxdepth 8 \
						-type f \
						-name Makefile \
						-print || true

					rm -rf -- "$CLONE_DIR"
					exit 1
				fi
			done

			rm -rf -- "$CLONE_DIR"
			;;

		*)
			echo "ERROR: unsupported package mode: ${PKG_MODE}"
			rm -rf -- "$CLONE_DIR"
			exit 1
			;;
	esac
}

# Verify that an extracted package exists and has a Makefile.
VERIFY_PACKAGE() {
	local PKG_NAME="${1:?Missing package name}"
	local MAKEFILE="./${PKG_NAME}/Makefile"

	if [[ ! -f "$MAKEFILE" ]]; then
		echo "ERROR: package Makefile was not found: ${MAKEFILE}"
		return 1
	fi

	echo "Found ${PKG_NAME}: ${MAKEFILE}"
}

# --------------------------------------------------------------------
# Third-party packages
# --------------------------------------------------------------------

# Aurora theme.
# Its repository root is the OpenWrt package.
UPDATE_PACKAGE \
	"luci-theme-aurora" \
	"eamonxg/luci-theme-aurora" \
	"master" \
	"root"

# PassWall LuCI application.
# The selected proxy cores and dependencies are resolved through feeds/config.
UPDATE_PACKAGE \
	"luci-app-passwall" \
	"Openwrt-Passwall/openwrt-passwall" \
	"main" \
	"pkg"

# Lucky LuCI application and Lucky executable.
UPDATE_PACKAGE \
	"luci-app-lucky" \
	"gdy666/luci-app-lucky" \
	"main" \
	"pkg" \
	"lucky"

# MosDNS LuCI application and MosDNS executable.
UPDATE_PACKAGE \
	"luci-app-mosdns" \
	"sbwml/luci-app-mosdns" \
	"v5" \
	"pkg" \
	"mosdns"

# Gecoosac LuCI application and Gecoosac executable.
# This is a multi-package repository; its root has no Makefile.
UPDATE_PACKAGE \
	"luci-app-gecoosac" \
	"laipeng668/luci-app-gecoosac" \
	"main" \
	"pkg" \
	"gecoosac"

# microsocks is provided by the official OpenWrt/ImmortalWrt feeds.
# No third-party repository needs to be cloned.

echo
echo "========== Package source update completed =========="

echo
echo "========== Verify package Makefiles =========="

VERIFY_PACKAGE "luci-theme-aurora"
VERIFY_PACKAGE "luci-app-passwall"
VERIFY_PACKAGE "luci-app-lucky"
VERIFY_PACKAGE "lucky"
VERIFY_PACKAGE "luci-app-mosdns"
VERIFY_PACKAGE "mosdns"
VERIFY_PACKAGE "luci-app-gecoosac"
VERIFY_PACKAGE "gecoosac"

echo
echo "========== All required packages are ready =========="
