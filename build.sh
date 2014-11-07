#!/usr/bin/env bash

### bash best practices ###
# exit on error code
set -o errexit
# exit on unset variable
set -o nounset
# return error of last failed command in pipe
set -o pipefail
# expand aliases
shopt -s expand_aliases
# print trace
set -o xtrace

### logfile ###
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
logfile="logfile_${timestamp}.txt"
echo "${0} ${@}" > "${logfile}"
# save stdout to logfile
exec 1> >(tee -a "${logfile}")
# redirect errors to stdout
exec 2> >(tee -a "${logfile}" >&2)

### environment variables ###
source crosscompile.sh
export NAME="fuse"
export DEST="/mnt/DroboFS/Shares/DroboApps/${NAME}"
export DEPS="${PWD}/target/install"
export CFLAGS="${CFLAGS:-} -Os -fPIC"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export CPPFLAGS="-I${DEPS}/include"
export LDFLAGS="${LDFLAGS:-} -Wl,-rpath,${DEST}/lib -L${DEST}/lib"
alias make="make -j8 V=1 VERBOSE=1"

# $1: file
# $2: url
# $3: folder
_download_tgz() {
  [[ ! -f "download/${1}" ]] && wget -O "download/${1}" "${2}"
  [[ -d "target/${3}" ]] && rm -v -fr "target/${3}"
  [[ ! -d "target/${3}" ]] && tar -zxvf "download/${1}" -C target
  return 0
}

# $1: file
# $2: url
# $3: folder
_download_app() {
  [[ ! -f "download/${1}" ]] && wget -O "download/${1}" "${2}"
  [[ -d "target/${3}" ]] && rm -v -fr "target/${3}"
  mkdir -p "target/${3}"
  tar -zxvf "download/${1}" -C target/${3}
  return 0
}

# $1: branch
# $2: folder
# $3: url
_download_git() {
  [[ -d "target/${2}" ]] && rm -v -fr "target/${2}"
  [[ ! -d "target/${2}" ]] && git clone --branch "${1}" --single-branch --depth 1 "${3}" "target/${2}"
  return 0
}

# $1: file
# $2: url
_download_file() {
  [[ ! -f "download/${1}" ]] && wget -O "download/${1}" "${2}"
  return 0
}

### MODULE ###
_build_module() {
local VERSION="3.2.27"
local FILE="fuse.ko"
local URL="https://github.com/droboports/kernel-drobo${DROBO}/releases/download/v${VERSION}/${FILE}"

_download_file "${FILE}" "${URL}"
mkdir -p "${DEST}/modules"
cp "download/${FILE}" "${DEST}/modules/"
}

### FUSE ###
_build_fuse() {
local VERSION="2.9.3"
local FOLDER="fuse-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://sourceforge.net/projects/fuse/files/fuse-2.X/${VERSION}/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd target/"${FOLDER}"
./configure --host=arm-none-linux-gnueabi --prefix="${DEST}" --mandir="${DEST}/man"
make
make install MOUNT_FUSE_PATH="${DEST}/sbin" INIT_D_PATH="${DEST}/etc/init.d" UDEV_RULES_PATH="${DEST}/etc/udev/rules.d"
popd
}

### BUILD ###
_build() {
  _build_module
  _build_fuse
  _package
}

_create_tgz() {
  local appname="$(basename ${PWD})"
  local appfile="${PWD}/${appname}.tgz"

  if [[ -f "${appfile}" ]]; then
    rm -v "${appfile}"
  fi

  pushd "${DEST}"
  tar --verbose --create --numeric-owner --owner=0 --group=0 --gzip --file "${appfile}" *
  popd
}

_package() {
  mkdir -p "${DEST}"
  cp -avfR src/dest/* "${DEST}"/
  find "${DEST}" -name "._*" -print -delete
  _create_tgz
}

_clean() {
  rm -v -fr "${DEPS}"
  rm -v -fr "${DEST}"
  rm -v -fr target/*
}

_dist_clean() {
  _clean
  rm -v -f logfile*
  rm -v -fr download/*
}

case "${1:-}" in
  clean)     _clean ;;
  distclean) _dist_clean ;;
  package)   _package ;;
  "")        _build ;;
  *)         _build_${1} ;;
esac
