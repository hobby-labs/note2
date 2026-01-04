#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local bridge_name force

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getoptses

    local options
    options=$(getoptses -o "b:h" --longoptions "bridge-name:,help" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        logger.error "Failed to parse options" >&2
        return 1
    fi
    eval "set -- $options"
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -b|--bridge-name)
                bridge_name="$2"
                shift 2
                ;;
            -h|--help)
                usage
                return 0
                ;;
            -- )
                shift
                break
                ;;
            *)
                logger.error "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # --bridge-name is required
    if [[ -z "${bridge_name}" ]]; then
        logger.error "--bridge-name is required" >&2
        return 1
    fi
    # Create bridge
    do_create_bridge "${bridge_name}" || return 1

    return 0
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
  -b, --bridge-name BRIDGE_NAME   Specify the name of the bridge to create
  -h, --help                      Show this help message
Example:
  $(basename "$0") --bridge-name br0
EOF
}

do_create_bridge() {
    local bridge_name="$1"
    local force="$2"

    # Create the bridge device first (if it doesn't exist)
    if ! ip link show "${bridge_name}" &>/dev/null; then
        ip link add name "${bridge_name}" type bridge
        logger.info "Bridge device ${bridge_name} created"
    elif [[ "${force}" == "1" ]]; then
        logger.info "Bridge ${bridge_name} already exists (force mode)"
    else
        logger.info "Bridge ${bridge_name} already exists"
    fi

    logger.info "Bridge ${bridge_name} created successfully"
    return 0
}

main "$@"