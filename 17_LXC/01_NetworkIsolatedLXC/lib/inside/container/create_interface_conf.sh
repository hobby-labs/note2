#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local lxc_base_dir ns_name interface_name lxc_name ip_addr netmask gateway dns

    . ${SCRIPTDIR%/}/../../functions/all

    local options
    options=$(getoptses -o "h" --longoptions "lxc-base-dir:,ns-name:,interface-name:,lxc-name:,ip:,netmask:,gateway:,dns:,help" -- "$@")
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
            --interface-name)
                interface_name="$2"
                shift 2
                ;;
            --lxc-name)
                lxc_name="$2"
                shift 2
                ;;
            --ip)
                ip_addr="$2"
                shift 2
                ;;
            --netmask)
                netmask="$2"
                shift 2
                ;;
            --gateway)
                gateway="$2"
                shift 2
                ;;
            --dns)
                dns="$2"
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

    # --interface-name is required
    if [[ -z "${interface_name}" ]]; then
        logger.error "--interface-name is required" >&2
        return 1
    fi
    # --lxc-name is required
    if [[ -z "${lxc_name}" ]]; then
        logger.error "--lxc-name is required" >&2
        return 1
    fi
    # --netmask is required if --ip is specified
    if [[ -n "${ip_addr}" && -z "${netmask}" ]]; then
        logger.error "--netmask is required when --ip is specified" >&2
        return 1
    fi

    # Declare LXC_PATH if not set
    setup_lxc_environment_variables "${lxc_base_dir}" "${ns_name}" || return 1

    do_create_interface_of_container "${interface_name}" "${lxc_name}" "${ip_addr}" "${netmask}" "${gateway}" "${dns}" || return 1

    return 0
}

do_create_interface_of_container() {
    local interface_name="$1"
    local lxc_name="$2"
    local ip_addr="$3"
    local netmask="$4"
    local gateway="$5"
    local dns="$6"

    local file_path

    # This instruction assumes that the LXC_PATH environment variable has already set
    file_path="${LXC_PATH%/}/${lxc_name}/rootfs/etc/sysconfig/network-scripts/ifcfg-${interface_name}"

    logger.info "Creating interface configuration file for container. FILE_PATH: ${file_path}, IP: ${ip_addr}, NETMASK: ${netmask}, GATEWAY: ${gateway}, DNS: ${dns}"

    cat > "${file_path}" << EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
NAME=${interface_name}
DEVICE=${interface_name}
ONBOOT=yes
EOF

    if [[ -n "${ip_addr}" ]]; then
        cat >> "${file_path}" << EOF
IPADDR=${ip_addr}
NETMASK=${netmask}
EOF
    fi
    if [[ -n "${gateway}" ]]; then
        echo "GATEWAY=${gateway}" >> "${file_path}"
    fi
    if [[ -n "${dns}" ]]; then
        echo "DNS1=${dns}" >> "${file_path}"
    fi

    return 0
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
  --lxc-base-dir LXC_BASE_DIR       Specify the base directory for LXC containers
  --ns-name NS_NAME                 Specify the namespace name
  --interface-name INTERFACE_NAME   Specify the name of the network interface
  --lxc-name LXC_NAME               Specify the name of the LXC container
  --ip IP_ADDRESS                   Specify the IP address to assign to the interface
  --netmask NETMASK                 Specify the netmask for the interface
  --gateway GATEWAY                 Specify the gateway for the interface
  --dns DNS                         Specify the DNS server for the interface
  -h, --help                        Show this help message
Example:
  $(basename "$0") --lxc-name mycontainer --interface-name eth0 --ip 192.168.1.100 --netmask 255.255.255.0 --gateway 192.168.1.1 --dns 8.8.8.8
EOF
    return 0
}

main "$@"
