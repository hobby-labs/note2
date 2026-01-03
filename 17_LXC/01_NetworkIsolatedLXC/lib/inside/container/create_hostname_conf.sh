#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local lxc_base_dir ns_name lxc_name hostname

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getoptses

    local options
    options=$(getoptses -o "h" --longoptions "lxc-base-dir:,ns-name:,lxc-name:,hostname:,help" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        logger_error "Failed to parse options" >&2
        return 1
    fi
    eval "set -- $options"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --lxc-base-dir)
                lxc_base_dir="$2"
                shift 2
                ;;
            --ns-name)
                ns_name="$2"
                shift 2
                ;;
            --lxc-name)
                lxc_name="$2"
                shift 2
                ;;
            --hostname)
                hostname="$2"
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
                logger_error "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # --lxc-name and --hostname are required
    if [[ -z "${lxc_name}" ]]; then
        logger_error "--lxc-name is required"
        return 1
    fi
    if [[ -z "${hostname}" ]]; then
        logger_error "--hostname is required"
        return 1
    fi

    # Declare LXCPATH if not set
    setup_lxcpath_environment_variable "${lxc_base_dir}" "${ns_name}" || return 1

    # Create hostname configuration file of container
    do_create_hostname_conf_of_container "${lxc_name}" "${hostname}" || return 1

    return 0
}

do_create_hostname_conf_of_container() {
    local lxc_name="$1"
    local hostname="$2"
    local hostname_conf_file="${LXCPATH}/${lxc_name}/rootfs/etc/hostname"

    echo "${hostname}" > "${hostname_conf_file}" || {
        logger_error "Failed to create hostname configuration file: ${hostname_conf_file}" >&2
        return 1
    }
    logger_info "Created hostname configuration file: ${hostname_conf_file}"

    return 0
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
  --lxc-base-dir LXC_BASE_DIR     Specify the base directory for LXC containers
  --ns-name NS_NAME               Specify the namespace name
  --lxc-name LXC_NAME             Specify the name of the LXC container
  --hostname HOSTNAME             Specify the hostname to set in the container
  -h, --help                      Show this help message
Example:
  $(basename "$0") --lxc-base-dir /var/lib/lxc-ns --ns-name ns01 --lxc-name mycontainer --hostname mycontainer.local
EOF
    return 0
}

main "$@"