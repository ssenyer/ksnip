#!/bin/bash

VERSION_REGEX="([0-9]{1,}\.)+[0-9]{1,}"
export BUILD_TIME=$(date +"%a, %d %b %Y %T %z")
export BUILD_DATE=$(date  +"%a %b %d %Y")
export BUILD_NUMBER=$(git rev-list --count HEAD)-$(git rev-parse --short HEAD)
export VERSION_NUMBER=$(grep "project.*" CMakeLists.txt | egrep -o "${VERSION_REGEX}")
export INSTALL_PREFIX="/usr"
export BUILD_TYPE="Release"

if [[ -z "${TRAVIS_TAG}" ]]; then
    echo "Build is not tagged this is a continues build"
    export VERSION_SUFFIX=continuous
    export VERSION=${VERSION_NUMBER}-${VERSION_SUFFIX}
else
    echo "--> Build is tagged this is not a continues build"
    echo "--> Building ksnip version ${VERSION_NUMBER}"
    export VERSION=${VERSION_NUMBER}
fi


if [[ -z "${TRAVIS_TAG}" ]]; then
    echo "--> Building ksnip with latest version of kColorPicker"
    echo "--> Building ksnip with latest version of kImageAnnotator"

    git clone --depth 1 git://github.com/ksnip/kColorPicker
    git clone --depth 1 git://github.com/ksnip/kImageAnnotator
else
    KCOLORPICKER_VERSION=$(grep "set.*KCOLORPICKER_MIN_VERSION" CMakeLists.txt | egrep -o "${VERSION_REGEX}")
    KIMAGEANNOTATOR_VERSION=$(grep "set.*KIMAGEANNOTATOR_MIN_VERSION" CMakeLists.txt | egrep -o "${VERSION_REGEX}")

    echo "--> Building ksnip with kColorPicker version ${KCOLORPICKER_VERSION}"
    echo "--> Building ksnip with kImageAnnotator version ${KIMAGEANNOTATOR_VERSION}"

    git clone --depth 1 --branch "v${KCOLORPICKER_VERSION}" git://github.com/ksnip/kColorPicker
    git clone --depth 1 --branch "v${KIMAGEANNOTATOR_VERSION}" git://github.com/ksnip/kImageAnnotator
fi


if [[ "${BINARY_TYPE}" == "AppImage" ]]; then
    source ci/scripts/common/setup_ubuntu_qt.sh
    source ci/scripts/common/setup_dependencies_ubuntu.sh

elif [[ "${BINARY_TYPE}" == "deb" ]]; then
    docker exec build-container apt-get update
    docker exec build-container apt-get -y install git \
                                                   cmake \
                                                   build-essential \
                                                   qt5-default \
                                                   libqt5x11extras5-dev \
												                           qttools5-dev \
                                                   qttools5-dev-tools \
                                                   extra-cmake-modules \
                                                   libqt5svg5-dev \
                                                   devscripts \
                                                   debhelper
    docker exec build-container bash -c "source ci/scripts/common/setup_dependencies_linux_noSudo.sh"

    source ci/scripts/deb/setup_deb_directory_structure.sh
    source ci/scripts/deb/setup_changelog_file.sh
    source ci/scripts/deb/setup_build_rules.sh
elif [[ "${BINARY_TYPE}" == "rpm" ]]; then
    docker exec build-container zypper --non-interactive install git \
                                                                 cmake \
                                                                 extra-cmake-modules \
                                                                 patterns-devel-C-C++-devel_C_C++ \
                                                                 libqt5-linguist-devel \
                                                                 libqt5-qtx11extras-devel \
                                                                 libqt5-qtdeclarative-devel \
                                                                 libqt5-qtbase-devel \
                                                                 libqt5-qtsvg-devel \
                                                                 rpm-build \
                                                                 update-desktop-files
    docker exec build-container bash -c "source ci/scripts/common/setup_dependencies_linux_noSudo.sh"

    source ci/scripts/rpm/setup_spec_file.sh
    source ci/scripts/rpm/setup_rpm_directory_structure.sh

    sudo chown -R root:root ksnip-${VERSION_NUMBER}
elif [[ "${BINARY_TYPE}" == "exe" ]]; then
    source ci/scripts/exe/setup_dependencies_windows.sh
elif [[ "${BINARY_TYPE}" == "app" ]]; then
    # brew upgrade qt    # qt is currently being updated to version qt6 which we don't support yet, trying to install qt5 below
    echo "--> Try install qt5"
    brew install qt5
    echo 'export PATH="/usr/local/opt/qt@5/bin:$PATH"' >> /Users/travis/.bash_profile

    export PATH="/usr/local/opt/qt/bin:$PATH"

    source ci/scripts/common/setup_dependencies_linux_noSudo.sh

    echo "--> Setup Certificates"
    chmod +x ci/scripts/app/add-osx-cert.sh;
    ./ci/scripts/app/add-osx-cert.sh;
fi
