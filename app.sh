# app-specific functions

### MODULE ###
_build_module() {
local VERSION="$1"
local FILE="fuse.ko"
local URL="https://github.com/droboports/kernel-drobo${DROBO}/releases/download/v${VERSION}/${FILE}"

_download_file "${FILE}" "${URL}"
mkdir -p "${DEST}/modules/${VERSION}"
cp "download/${FILE}" "${DEST}/modules/${VERSION}/"
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
  _build_module 3.2.27
  #_build_module 3.2.58
  _build_fuse
  _package
}
