#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local lxc_base_dir ns_name lxc_name

    . ${SCRIPTDIR%/}/../../functions/all

    local options
    options=$(getoptses -o "h" --longoptions "lxc-base-dir:,ns-name:,lxc-name:,help" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        logger.error "Failed to parse options" >&2
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

    # --lxc-name is required
    if [[ -z "${lxc_name}" ]]; then
        logger.error "--lxc-name is required"
        return 1
    fi

    # Declare LXC_PATH if not set
    setup_lxc_environment_variables "${lxc_base_dir}" "${ns_name}" || return 1

    do_create_fstab_conf_container "${lxc_name}" || return 1

    return 0
}

do_create_fstab_conf_container() {
    local lxc_name="$1"

    local fstab_file="${LXC_PATH%/}/${lxc_name}/rootfs/etc/fstab"

    logger.info "Creating fstab file for LXC container: ${lxc_name}"

    cat > "${fstab_file}" << 'EOF'
# LXC container - minimal fstab
# Root filesystem is managed by LXC
tmpfs   /dev/shm   tmpfs   defaults   0 0
devpts  /dev/pts   devpts  gid=5,mode=620  0 0
sysfs   /sys       sysfs   defaults   0 0
proc    /proc      proc    defaults   0 0
EOF

    if [[ "$?" -ne 0 ]]; then
        logger.error "Failed to create fstab file: ${fstab_file}"
        return 1
    fi

    return 0
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
Options:
  --lxc-base-dir PATH   Base directory of LXC containers (default: /var/lib/lxc-ns)
  --ns-name NAME        Namespace name where LXC containers are located (default: default)
  --lxc-name NAME       Name of the LXC container (required)
  -h, --help            Show this help message and exit
Example:
  $(basename "$0") --lxc-name mycontainer
EOF

    return 0
}

main "$@"