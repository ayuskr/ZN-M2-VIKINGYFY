#!/bin/bash

set -e

# Install or update third-party packages
UPDATE_PACKAGE() {
	local PKG_NAME="$1"
	local PKG_REPO="$2"
	local PKG_BRANCH="$3"
	local PKG_SPECIAL="${4:-}"
	local PKG_LIST=("$PKG_NAME" ${5:-})
	local REPO_NAME="${PKG_REPO#*/}"

	echo
	echo "========== Updating ${PKG_NAME} =========="

	# Remove existing packages with the same or conflicting names
	for NAME in "${PKG_LIST[@]}"; do
		[ -z "$NAME" ] && continue

		echo "Searching existing package: $NAME"

		local FOUND_DIRS
		FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ \
			-maxdepth 3 \
			-type d \
			-iname "*${NAME}*" \
			2>/dev/null || true)

		if [ -n "$FOUND_DIRS" ]; then
			while IFS= read -r DIR; do
				[ -z "$DIR" ] && continue
				rm -rf "$DIR"
				echo "Deleted directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "No existing package found: $NAME"
		fi
	done

	# Remove a previous clone with the same repository name
	rm -rf "./${REPO_NAME}"

	# Clone the package repository
	git clone \
		--depth=1 \
		--single-branch \
		--branch "$PKG_BRANCH" \
		"https://github.com/${PKG_REPO}.git" \
		"./${REPO_NAME}"

	# Handle repositories containing multiple packages
	if [ "$PKG_SPECIAL" = "pkg" ]; then
		find "./${REPO_NAME}" \
			-mindepth 2 \
			-maxdepth 4 \
			-type d \
			-iname "*${PKG_NAME}*" \
			-prune \
			-exec cp -rf {} ./ \;

		rm -rf "./${REPO_NAME}"

	# Rename the cloned repository
	elif [ "$PKG_SPECIAL" = "name" ]; then
		mv -f "./${REPO_NAME}" "./${PKG_NAME}"
	fi
}

# Required packages only

# Aurora theme
UPDATE_PACKAGE \
	"aurora" \
	"eamonxg/luci-theme-aurora" \
	"master"

# Passwall LuCI application and related packages
UPDATE_PACKAGE \
	"passwall" \
	"Openwrt-Passwall/openwrt-passwall" \
	"main" \
	"pkg"

# Lucky LuCI application
# Also remove the old lucky package to avoid duplicate or conflicting files
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
	"lwb1978/openwrt-gecoosac" \
	"main"

# microsocks is provided by the official OpenWrt packages feed.
# No third-party repository needs to be cloned here.
