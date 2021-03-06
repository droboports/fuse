#!/usr/bin/env sh
#
# Fuse service

# import DroboApps framework functions
source /etc/service.subr

### app-specific section

# DroboApp framework version
framework_version="2.0"

# app description
name="fuse"
version="2.9.3"
description="FUSE (Filesystem in Userspace) support"

# framework-mandated variables
pidfile="/tmp/DroboApps/${name}/pid.txt"
logfile="/tmp/DroboApps/${name}/log.txt"
statusfile="/tmp/DroboApps/${name}/status.txt"
errorfile="/tmp/DroboApps/${name}/error.txt"

# app-specific variables
prog_dir="$(dirname $(readlink -fn ${0}))"
mountpoint="/sys/fs/fuse/connections"

# _is_running
# returns: 0 if pid is running, 1 if not running or if pidfile does not exist.
_is_running() {
  if [[ -z "$(grep ^fusectl /proc/mounts)" ]]; then return 1; fi
  if [[ -z "$(lsmod | grep ^fuse)" ]]; then return 1; fi
}

start() {
  set -u # exit on unset variable
  set -e # exit on uncaught error code
  set -x # enable script trace
  /bin/chmod 4755 "${prog_dir}/bin/fusermount"
  if [[ ! -c /dev/fuse ]]; then /bin/mknod -m 666 /dev/fuse c 10 229; fi
  if [[ -z "$(lsmod | grep ^fuse)" ]]; then /sbin/insmod "${prog_dir}/modules/$(uname -r)/fuse.ko"; fi
  if [[ -z "$(grep ^fusectl /proc/mounts)" ]]; then /bin/mount -t fusectl fusectl "${mountpoint}"; fi
}

### common section

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe

# ensure log folder exists
if ! grep -q ^tmpfs /proc/mounts; then mount -t tmpfs tmpfs /tmp; fi
logfolder="$(dirname ${logfile})"
if [[ ! -d "${logfolder}" ]]; then mkdir -p "${logfolder}"; fi

# redirect all output to logfile
exec 3>&1 1>> "${logfile}" 2>&1

# log current date, time, and invocation parameters
echo $(date +"%Y-%m-%d %H-%M-%S"): ${0} ${@}

_service_start() {
  if _is_running; then
    echo ${name} is already running >&3
    return 1
  fi
  set +x # disable script trace
  set +e # disable error code check
  set +u # disable unset variable check
  start_service
}

_service_stop() {
  if [[ -n "$(grep ^fusectl /proc/mounts)" ]]; then /bin/umount "${mountpoint}"; fi
  if [[ -n "$(lsmod | grep ^fuse)" ]]; then /sbin/rmmod "${prog_dir}/modules/$(uname -r)/fuse.ko"; fi
}

_service_restart() {
  _service_stop
  sleep 3
  _service_start
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|restart|status]" >&3
  set +e # disable error code check
  exit 1
}

# enable script tracing
set -o xtrace

case "${1:-}" in
  start|stop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
