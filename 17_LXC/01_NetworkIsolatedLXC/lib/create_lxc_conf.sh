#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local lxc_base_dir lxc_name ns_name interface_list=()

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getoptses

    local options
    options=$(getoptses -o "h" --longoptions "lxc-base-dir:,lxc-name:,ns-name:,interface:,help" -- "$@")
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
            --lxc-name)
                lxc_name="$2"
                shift 2
                ;;
            --ns-name)
                ns_name="$2"
                shift 2
                ;;
            --interface)
                interface_list+=("$2")
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

    # Validate required options
    if [[ -z "${lxc_name}" ]]; then
        logger_error "--lxc-name is required" >&2
        return 1
    fi

    setup_lxc_environment_variables "${lxc_base_dir}" "${ns_name}" || return 1

    do_create_lxc_config "${lxc_base_dir}" "${lxc_name}" "${ns_name}" "${interface_list[@]}" || return 1

    return 0
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
  --lxc-base-dir LXC_BASE_DIR       Specify the base directory for LXC containers
  --lxc-name LXC_NAME               Specify the name of the LXC container
  --ns-name NS_NAME                 Specify the namespace name
  --interface INTERFACE             Specify network interface in the format "bind_bridge=BRIDGE_NAME,interface_name=IF_NAME". Can be specified multiple times for multiple interfaces.
  -h, --help                        Show this help message
Example:
  $(basename "$0") --lxc-base-dir /var/lib/lxc --lxc-name mycontainer --ns-name mynamespace --interface "bind_bridge=br0,interface_name=eth0" --interface "bind_bridge=br1,interface_name=eth1"
EOF
    return 0
}

do_create_lxc_config() {
    local lxc_base_dir="$1"
    local lxc_name="$2"
    local ns_name="$3"
    shift 3
    local interface
    local interface_list=("$@")

    local config_path="${LXC_PATH}/${lxc_name}/config"

    logger_info "Creating LXC config file at ${config_path}"

    echo "lxc.utsname = ${lxc_name}"                                    > "${config_path}"
    echo "lxc.rootfs = ${LXC_PATH}/${lxc_name}/rootfs"                  >> "${config_path}"

    for interface in "${interface_list[@]}"; do
        # Convert value of interface like "bind_bridge=br0,interface_name=eth0", "bind_bridge=br1,interface_name=eth1" into LXC config format.
        # User may specify unusual order like "bind_bridge=br0,interface_name=eth0", "interface_name=eth1,bind_bridge=br1" but both are acceptable.
        local bind_bridge interface_name
        IFS=',' read -ra parts <<< "${interface}"
        for part in "${parts[@]}"; do
            IFS='=' read -ra kv <<< "${part}"
            case "${kv[0]}" in
                bind_bridge)
                    bind_bridge="${kv[1]}"
                    ;;
                interface_name)
                    interface_name="${kv[1]}"
                    ;;
                *)
                    logger_error "Unknown interface part: ${kv[0]}"
                    return 1
                    ;;
            esac
        done
        if [[ -z "${bind_bridge}" || -z "${interface_name}" ]]; then
            logger_error "Both bind_bridge and interface_name must be specified in interface: ${interface}"
            return 1
        fi

        echo ""                                                         >> "${config_path}"
        echo "lxc.network.type = veth"                                  >> "${config_path}"
        echo "lxc.network.flags = up"                                   >> "${config_path}"
        echo "lxc.network.link = ${bind_bridge}"                        >> "${config_path}"
        echo "lxc.network.name = ${interface_name}"                     >> "${config_path}"
    done

    echo ""                                                             >> "${config_path}"
    echo "lxc.aa_profile = unconfined"                                  >> "${config_path}"
    echo "lxc.cgroup.devices.allow = a"                                 >> "${config_path}"
    echo "lxc.cap.drop ="                                               >> "${config_path}"

    logger_info "LXC config file created successfully at ${config_path}"

    return 0
}

main "$@"