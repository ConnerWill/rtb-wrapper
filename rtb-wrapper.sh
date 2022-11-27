#!/usr/bin/env sh
# profile based rsync-time-backup
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

fn_color_print_error(){   printf "\x1B[0;1;38;5;196m%s\x1B[0m\n" "${@}"; }
fn_color_print_warning(){ printf "\x1B[0;38;5;190m%s\x1B[0m\n"   "${@}"; }
fn_color_print_success(){ printf "\x1B[0;38;5;46m%s\x1B[0m\n"    "${@}"; }
fn_color_print_verbose(){ printf "\x1B[0;38;5;87m%s\x1B[0m\n"    "${@}"; }


# Print CLI usage help
fn_display_usage () {
	printf "Usage: rtb-wrapper.sh <action> <profile>\n\n"
	printf "action: backup, restore\n"
	printf "profile: name of the profile file\n\n"
	printf "For more detailed help, please see the README file:\n\n"
	printf "https://github.com/thomas-mc-work/rtb-wrapper/blob/master/README.md\n"
}

# create backup cli command
fn_create_backup_cmd () {
  #shellcheck disable=2154
  cmd="${rsync_tmbackup_path} '${SOURCE}' '${TARGET}'"

  exclude_file_check=${EXCLUDE_FILE:-}

  if [ -n "${exclude_file_check}" ]; then
    cmd="${cmd} '${EXCLUDE_FILE}'"
  fi

  echo "${cmd}"
}

# create restore cli command
fn_create_restore_cmd () {
    cmd="rsync -aP"

    if [ "${WIPE_SOURCE_ON_RESTORE:-'false'}" = "true" ]; then
      cmd="${cmd} --delete"
    fi

    cmd="${cmd} '${TARGET}/latest/' '${SOURCE}/'"

    echo "${cmd}"
}

fn_abort_if_crlf () {
  if ! awk '/\r$/ { exit(1) }' "${1}"; then
    echo " [!] The profile has at least one Windows-style line ending"
    echo "     ERROR: failed to read the profile file: ${profile_file}" > /dev/stderr
    exit 1
  fi
}

# show help when invoked without parameters
if [ $# -eq 0 ]; then
  fn_display_usage
  exit 0
fi

action=${1?"param 1: action: backup, restore"}
profile=${2?"param 2: name of the profile"}

# load config
config_dir="${RTB_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/rsync_tmbackup}"

# load profile
profile_dir="${config_dir}/conf.d"
profile_file="${profile_dir}/${profile}.inc"
exclude_file_convention="${profile_dir}/${profile}.excludes.lst"

if [ -r "${profile_file}" ]; then
  # preset exclude file path before reading the profile
  if [ -r "${exclude_file_convention}" ]; then
    EXCLUDE_FILE="${exclude_file_convention}"
  fi

  # sanity check, crlf can break variable substitution
  fn_abort_if_crlf "${profile_file}"
  # ellcheck disable=SC1090,SC1091
  . "${profile_file}"

  # Check if command is found
  rsync_tmbackup_cmd="rsync_tmbackup.sh"
  rsync_tmbackup_path=$(command -v "${rsync_tmbackup_cmd}" 2>/dev/null)
  if [ -z "${rsync_tmbackup_path}" ]; then
    printf "Cannot find command:\t%s" "${rsync_tmbackup_cmd}"
    exit 1
  fi

  # create cli command
  if [ "${action}" = "restore" ]; then
    cmd=$(fn_create_restore_cmd)
  else
    cmd=$(fn_create_backup_cmd)
  fi

  echo "# ${cmd}"
  eval "${cmd}"
else
  echo "Failed to read the profile file: ${profile_file}" > /dev/stderr
  exit 1
fi
