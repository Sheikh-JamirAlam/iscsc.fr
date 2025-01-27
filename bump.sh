#!/bin/sh

# ----------- Basic Checking -----------

# Check that 1 arg has been supplied
if [ "$#" != "1" ]; then
	echo "[-] Exactly one argument is needed."
	echo '[?] Example: `./bump.sh 0.2.6`'
	exit 1
fi

dependencies=(
	semver
	git
	npm
)

# Check that required binaries are installed
for package in ${dependencies[@]}; do
	if [ ! $(which $package) ]; then
		echo "[-] All of '${dependencies[@]}' are needed to bump version"
		exit 1
	fi
done

# Check that supplied version is semantically correct
if [ ! "$1" = "$(semver $1)" ]; then
	echo "[-] $1 is not a valid version number according to semver"
	exit 1
fi

# Check that git working directory is clean...
if [ -n "$(git status --short --untracked-files=no)" ]; then
	echo "[-] git working directory isn't clean"
	exit 1
fi

# ----------- Variable definition -----------

# Define needed variables
CURRENT_VERSION=$(npm pkg get version | sed 's/"//g')
NEW_VERSION=$1
BUMP_BRANCH="${NEW_VERSION}-version-bump"
ISCSC_REMOTE=$(git remote -v | grep 'git@github.com:iScsc/iscsc.fr.git' | awk '{print $1}' | head --lines 1)

# ----------- Version checking -----------

# Check if targeted version is > than current
echo "[+] Current version is '${CURRENT_VERSION}'"
if [ ! $(semver "${NEW_VERSION}" -r ">${CURRENT_VERSION}") ]; then
	echo "[-] '${NEW_VERSION}'<='${CURRENT_VERSION}', '${NEW_VERSION}' isn't accepted as new version."
	exit 1
fi
echo "[+] '${NEW_VERSION}'>'${CURRENT_VERSION}', '${NEW_VERSION}' is accepted as new version."

# ----------- Git setup -----------

# ...and checkout on main to create a version bump branch
echo "[+] Checkout on ${ISCSC_REMOTE}/main"
[ -z "$DRY_RUN" ] && git checkout ${ISCSC_REMOTE}/main
echo "[+] switching to ${BUMP_BRANCH}"
[ -z "$DRY_RUN" ] && git switch -c ${BUMP_BRANCH}

# ----------- Version Bump -----------
# ---- Bump frontend and backend -----

echo '[+] Bumping `frontend`'
(
	cd frontend
	[ -z "$DRY_RUN" ] && npm version "${NEW_VERSION}" --no-git-tag-version
)
echo '[+] Bumping `backend`'
(
	cd backend
	[ -z "$DRY_RUN" ] && npm version "${NEW_VERSION}" --no-git-tag-version
)

echo '[+] Commiting `frontend` and `backend` bump'
[ -z "$DRY_RUN" ] && { git commit -m "Bump frontend and backend versions to ${NEW_VERSION}" || exit 1; }

# ------ Bump root and push ------

echo '[+] Bumping `root`'
[ -z "$DRY_RUN" ] && { npm version "${NEW_VERSION}" -m "Bump to version %s" || exit 1; }

echo '[+] Pushing branch and new version tag'
echo "[~] pushing to \`${ISCSC_REMOTE}\` please type your passphrase/password if required:"
[ -z "$DRY_RUN" ] && { git push ${ISCSC_REMOTE} ${BUMP_BRANCH} v${CURRENT_VERSION} || echo "[-] push failed, you can push with \`git push ${ISCSC_REMOTE} ${BUMP_BRANCH} v${CURRENT_VERSION}\`"; }

echo '[!] `npm install` has been run during the bump, you MUST review the changes during PR review to ensure package.json and package-lock.json where compatible!!!'

