#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local bridge_name force

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getoptses

    local options
    options=$(getoptses -o "b:fh" --longoptions "bridge-name:,force,help" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        logger_error "Failed to parse options" >&2
        return 1
    fi
    eval "set -- $options"
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -b|--bridge-name)
                bridge_name="$2"
                shift 2
                ;;
            -f|--force)
                force=1
                shift
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *)
                logger_error "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # --bridge-name is required
    if [[ -z "${bridge_name}" ]]; then
        logger_error "--bridge-name is required" >&2
        return 1
    fi
    # Create bridge
    do_create_bridge "${bridge_name}" "${force}" || return 1
    ifup_bridge      "${bridge_name}" "${force}" || return 1

    return 0
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
  -b, --bridge-name BRIDGE_NAME   Specify the name of the bridge to create
  -f, --force                     Force creation even if bridge or config exists
  -h, --help                      Show this help message
Example:
  $(basename "$0") --bridge-name br0
EOF
}

do_create_bridge() {
    local bridge_name="$1"
    local force="$2"

    # Check if bridge already exists and force is not set
    if [[ "${force}" != "1" ]] && ip link show "${bridge_name}" &>/dev/null; then
        logger_info "Bridge ${bridge_name} already exists"
        return 0
    fi

    # Create the configuretion file of the bridge
    # /etc/sysconfig/network-scripts/ifcfg-<bridge_name>
    local config_file="/etc/sysconfig/network-scripts/ifcfg-${bridge_name}"

    # Skip if the configuration file already exists
    if [[ "${force}" != "1" ]] && [[ -f "${config_file}" ]]; then
        logger_info "Configuration file ${config_file} already exists"
    else
        cat <<EOF >"${config_file}"
DEVICE=${bridge_name}
TYPE=Bridge
BOOTPROTO=none
ONBOOT=yes
DELAY=0
NM_CONTROLLED=no
IPV6INIT=no
EOF
        logger_info "Configuration file ${config_file} created"
    fi

    logger_info "Bridge ${bridge_name} created and brought up successfully"
    return 0
}

ifup_bridge() {
    local bridge_name="$1"
    local force="$2"

    # If the bridge is already up and force is not set, skip
    if [[ "${force}" != "1" ]]; then
        local state
        state=$(cat /sys/class/net/"${bridge_name}"/operstate 2>/dev/null)
        if [[ "${state}" == "up" ]]; then
            logger_info "Bridge ${bridge_name} is already up"
            return 0
        fi
    fi

    # Down the bridge first
    ip link set "${bridge_name}" down 2>/dev/null || true

    # Bring up the bridge
    ip link set "${bridge_name}" up
    if [[ "$?" -ne 0 ]]; then
        logger_error "Failed to bring up bridge ${bridge_name}" >&2
        return 1
    fi

    logger_info "Bridge ${bridge_name} is up"
    return 0
}

main "$@"