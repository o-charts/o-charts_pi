#!/usr/bin/env bash

#
# Upload the .tar.gz and .xml artifacts to cloudsmith
#

set -xe

UNSTABLE_REPO=${CLOUDSMITH_UNSTABLE_REPO:-'david-register/ocpn-plugins-unstable'}
STABLE_REPO=${CLOUDSMITH_STABLE_REPO:-'david-register/ocpn-plugins-stable'}

source $HOME/project/ci/commons.sh

if [ -z "$CIRCLECI" ]; then
    exit 0;
fi

if [ -z "$CLOUDSMITH_API_KEY" ]; then
    echo 'Cannot deploy to cloudsmith, missing $CLOUDSMITH_API_KEY'
    exit 0
fi

sudo apt -qq update || apt update
sudo apt-get -qq install devscripts equivs software-properties-common

if [ -n  "$USE_DEADSNAKES_PY37" ]; then
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt -qq update
    sudo  apt-get -q install  python3.7
    for py in $(ls /usr/bin/python3.[0-9]); do
        sudo update-alternatives --install /usr/bin/python3 python3 $py 1
    done
    sudo update-alternatives --set python3 /usr/bin/python3.7
fi

#if pyenv versions 2>&1 >/dev/null; then
#    pyenv global 3.7.0
#    python -m pip install cloudsmith-cli
#    pyenv rehash
#elif dnf --version 2>&1 >/dev/null; then
#    sudo dnf install python3-pip python3-setuptools
#    sudo python3 -m pip install -q cloudsmith-cli
#elif apt-get --version 2>&1 >/dev/null; then
#    sudo apt-get install python3-pip python3-setuptools
#    sudo python3 -m pip install -q cloudsmith-cli
#else
#    sudo -H python3 -m ensurepip
#    sudo -H python3 -m pip install -q setuptools
#    sudo -H python3 -m pip install -q cloudsmith-cli
#fi

BUILD_ID=${CIRCLE_BUILD_NUM:-1}
commit=$(git rev-parse --short=7 HEAD) || commit="unknown"
tag=$(git tag --contains HEAD)

xml=$(ls $HOME/project/build/*.xml)
tarball=$(ls $HOME/project/build/*.tar.gz)
tarball_basename=${tarball##*/}

# extract the project name for a filename.  e.g. oernc-pi... sets PROJECT to  "oernc"
PROJECT=${tarball_basename%%_pi*}

source $HOME/project/build/pkg_version.sh
test -n "$tag" && VERSION="$tag" || VERSION="${VERSION}.${commit}"
test -n "$tag" && REPO="$STABLE_REPO" || REPO="$UNSTABLE_REPO"
tarball_name=${PROJECT}-${PKG_TARGET}-${PKG_TARGET_VERSION}-tarball

sudo sed -i -e "s|@pkg_repo@|$REPO|" $xml
sudo sed -i -e "s|@name@|$tarball_name|" $xml
sudo sed -i -e "s|@version@|$VERSION|" $xml
sudo sed -i -e "s|@filename@|$tarball_basename|" $xml

# Repack using gnu tar (cmake's is problematic) and add metadata.
cp $xml metadata.xml
sudo chmod 666 $tarball
repack $tarball metadata.xml


cloudsmith push raw --republish --no-wait-for-sync \
    --name ${PROJECT}-${PKG_TARGET}-${PKG_TARGET_VERSION}-metadata \
    --version ${VERSION} \
    --summary "opencpn plugin metadata for automatic installation" \
    $REPO $xml

cloudsmith push raw --republish --no-wait-for-sync \
    --name $tarball_name \
    --version ${VERSION} \
    --summary "opencpn plugin tarball for automatic installation" \
    $REPO $tarball
