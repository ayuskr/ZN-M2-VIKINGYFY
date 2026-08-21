#!/usr/bin/env bash

set -Eeuo pipefail

UPDATE_PACKAGE() {
	local PKG_NAME="${1:?Missing package name}"
	local PKG_REPO="${2:?Missing GitHub repository}"
	local PKG_BRANCH="${3:?Missing repository branch}"
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

	for NAME in "${PKG_LIST[@]}"; do
		[[ -z "$NAME" ]] && continue

		echo "Searching existing package: ${NAME}"

		local FOUND_DIRS
		FOUND_DIRS="$(
			find ../feeds/luci ../feeds/packages . \
				-maxdepth 4 \
				-type d \
				-iname "*${NAME}*" \
				-not -path './.*' \
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

	rm -rf -- "./${REPO_NAME}"

	git clone \
		--depth=1 \
		--single-branch \
		--branch "$PKG_BRANCH" \
		"https://github.com/${PKG_REPO}.git" \
		"./${REPO_NAME}"

	case "$PKG_SPECIAL" in
		pkg)
			local COPIED_COUNT=0
			local DIR
			local TARGET_NAME
			local -A COPIED_DIRS=()

			for NAME in "${PKG_LIST[@]}"; do
				while IFS= read -r -d '' DIR; do
					[[ -f "${DIR}/Makefile" ]] || continue

					if [[ -n "${COPIED_DIRS["$DIR"]+exists}" ]]; then
						continue
					fi

					TARGET_NAME="$(basename "$DIR")"

					rm -rf -- "./${TARGET_NAME}"
					cp -a -- "$DIR" "./${TARGET_NAME}"

					COPIED_DIRS["$DIR"]=1
					COPIED_COUNT=$((COPIED_COUNT + 1))

					echo "Copied package: ${DIR} -> ./${TARGET_NAME}"
				done < <(
					find "./${REPO_NAME}" \
						-mindepth 1 \
						-maxdepth 5 \
						-type d \
						-iname "$NAME" \
						-print0
				)
			done

			if (( COPIED_COUNT == 0 )); then
				echo "ERROR: no matching package directory found in ${PKG_REPO}"
				find "./${REPO_NAME}" \
					-maxdepth 5 \
					-type f \
					-name Makefile \
					-print || true
				exit 1
			fi

			rm -rf -- "./${REPO_NAME}"
			;;

		name)
			if [[ "./${REPO_NAME}" != "./${PKG_NAME}" ]]; then
				rm -rf -- "./${PKG_NAME}"
				mv -- "./${REPO_NAME}" "./${PKG_NAME}"
			fi
			;;

		"")
			;;

		*)
			echo "ERROR: unsupported package mode: ${PKG_SPECIAL}"
			exit 1
			;;
	esac
}

# Aurora theme
UPDATE_PACKAGE \
	"luci-theme-aurora" \
	"eamonxg/luci-theme-aurora" \
	"master" \
	"name"

# PassWall LuCI application and related packages
UPDATE_PACKAGE \
	"luci-app-passwall" \
	"Openwrt-Passwall/openwrt-passwall" \
	"main" \
	"pkg" \
	"passwall"

# Lucky LuCI application
UPDATE_PACKAGE \
	"luci-app-lucky" \
	"gdy666/luci-app-lucky" \
	"main" \
	"" \
	"lucky"

# MosDNS
UPDATE_PACKAGE \
	"luci-app-mosdns" \
	"sbwml/luci-app-mosdns" \
	"v5" \
	"name" \
	"mosdns"

# Gecoosac
UPDATE_PACKAGE \
	"luci-app-gecoosac" \
	"laipeng668/luci-app-gecoosac" \
	"main" \
	"name" \
	"gecoosac"

# microsocks is provided by the official packages feed.

echo
echo "========== Package source update completed =========="

echo
echo "========== Verify package Makefiles =========="

REQUIRED_MAKEFILES=(
	"./luci-theme-aurora/Makefile"
	"./luci-app-passwall/Makefile"
	"./luci-app-lucky/Makefile"
	"./luci-app-mosdns/Makefile"
	"./luci-app-gecoosac/Makefile"
)

for MAKEFILE in "${REQUIRED_MAKEFILES[@]}"; do
	if [[ ! -f "$MAKEFILE" ]]; then
		echo "ERROR: required package Makefile does not exist: ${MAKEFILE}"
		exit 1
	fi

	echo "Found: ${MAKEFILE}"
done
