#!/usr/bin/env sh
# profile based rsync-time-backup
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

# define config
config_dir="${RTB_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/rsync_tmbackup}"

# define profile dir
profile_dir="${config_dir}/conf.d"

fn_color_print_error(){   printf "\x1B[0;1;4;48;5;196;38;5;15m[ERROR]\x1B[0m:\t\x1B[0;1;38;5;196m%s\x1B[0m\n" "${@}" > /dev/stderr; }
fn_color_print_warning(){ printf "\x1B[0;1;4;48;5;190;38;5;0m[WARNING]\x1B[0m:\t\x1B[0;38;5;190m%s\x1B[0m\n"  "${@}" > /dev/stderr; }
fn_color_print_success(){ printf "\x1B[0;1;4;48;5;46;38;5;15m[SUCCESS]\x1B[0m\t\x1B[0;38;5;46m%s\x1B[0m\n"    "${@}"; }
fn_color_print_verbose(){ printf "\x1B[0;38;5;87m%s\x1B[0m\n"    "${@}"; }


# Print CLI usage help
fn_display_usage () {
  printf "Usage:\t%s <action> <profile>\n\n" "$(basename "$0")"
	printf "\taction:\t\tbackup|restore\n"
	printf "\tprofile:\tname of the profile file\n\n"
  printf "Profile dir:\t%s\n\n\n" "${profile_dir}"
	printf "For more detailed help, please see the README file:\n"
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
  printf "%s\n" "${cmd}"
}

# create restore cli command
fn_create_restore_cmd () {
  cmd="rsync -aP"
  if [ "${WIPE_SOURCE_ON_RESTORE:-'false'}" = "true" ]; then
    cmd="${cmd} --delete"
  fi

  cmd="${cmd} '${TARGET}/latest/' '${SOURCE}/'"
  printf "%s\n" "${cmd}"
}

fn_abort_if_crlf () {
  if ! awk '/\r$/ { exit(1) }' "${1}"; then
    fn_color_print_error "[!] The profile has at least one Windows-style line ending"
    fn_color_print_error "failed to read the profile file:  ${profile_file}"
    exit 1
  fi
}

## show help when invoked without parameters
if [ $# -eq 0 ]; then
  fn_color_print_error "action and profile required"
  fn_display_usage
  exit 0
fi

action=${1:-'ERROR'}
profile=${2:-'ERROR'}

# check action and profile
if [ "${action}" = "ERROR" ]; then
  fn_color_print_error "action required"
  fn_display_usage
  exit 1
elif [ "${profile}" = "ERROR" ]; then
  fn_color_print_error "profile required"
  fn_display_usage
  exit 1
fi

# Check action
if [ "${action}" = "restore" ]; then
  printf ""
elif [ "${action}" = "backup" ]; then
  printf ""
else
  fn_color_print_error "Unknown action"
  fn_display_usage
  exit 1
fi

# load profile
profile_file="${profile_dir}/${profile}.inc"
exclude_file_convention="${profile_dir}/${profile}.excludes.lst"

if [ -r "${profile_file}" ]; then
  # preset exclude file path before reading the profile
  if [ -r "${exclude_file_convention}" ]; then
    EXCLUDE_FILE="${exclude_file_convention}"
  fi

  # sanity check, crlf can break variable substitution
  fn_abort_if_crlf "${profile_file}"
  #shellcheck disable=SC1090,SC1091
  . "${profile_file}"

  # Check if command is found
  rsync_tmbackup_cmd="rsync_tmbackup.sh"
  rsync_tmbackup_path=$(command -v "${rsync_tmbackup_cmd}" 2>/dev/null)
  if [ -z "${rsync_tmbackup_path}" ]; then
    fn_color_print_warning "Cannot find command:  ${rsync_tmbackup_cmd}"
    exit 1
  fi

  rsync_cmd="rsync"
  rsync_path=$(command -v "${rsync_cmd}" 2>/dev/null)
  if [ -z "${rsync_tmbackup_path}" ]; then
    fn_color_print_error "Cannot find command:  ${rsync_cmd}"
    exit 1
  fi

  # create cli command
  if [ "${action}" = "restore" ]; then
    cmd=$(fn_create_restore_cmd)
  elif [ "${action}" = "backup" ]; then
    cmd=$(fn_create_backup_cmd)
  else
    fn_color_print_error "Unknown action"
    fn_display_usage
    exit 1
  fi

  echo "# ${cmd}"
  eval "${cmd}"
else
  fn_color_print_error "Failed to read the profile file:  ${profile_file}"
  exit 1
fi
