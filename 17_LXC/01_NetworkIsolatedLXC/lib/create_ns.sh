#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local name default_gateway
    declare -a links=()

    . ${SCRIPTDIR%/}/functions/all

    local options
    options=$(getoptses -o "hd:l:n:" --longoptions "help,default-gateway:,link:,name:" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        echo "Invalid option were specified" >&2
        return 1
    fi
    eval set -- "$options"

    while true; do
        case "$1" in
        -n | --name )
            name="$2"
            shift 2
            ;;
        --default-gateway )
            default_gateway="$2"
            shift 2
            ;;
        --link )
            local link_param="$2"
            links+=("$link_param")
            shift 2
            ;;
        -h | --help )
            usage
            return 0
            ;;
        -- )
            shift
            break
            ;;
        * )
            logger.error "Internal error has occured" >&2
            return 1
            ;;
        esac    
    done

    # -n|---name is required
    if [[ -z "${name}" ]]; then
        logger.error "-n|--name is required" >&2
        return 1
    fi

    # -d|---default-gateway is required
    if [[ -z "${default_gateway}" ]]; then
        logger.error "-d|--default-gateway is required" >&2
        return 1
    fi

    create_ns "${name}" "${default_gateway}" "${links[@]}" || {
        logger.error "Failed to create network namespace: ${name}" >&2
        return 1
    }
}

create_ns() {
    local name=$1
    local default_gateway=$2
    shift 2
    local links=("$@")


    logger.info "Creating network namespace: ${name}: ip netns add ${name}"
    ip netns add ${name} || {
        logger.error "Failed to create network namespace: ${name}. (ip netns add ${name})" >&2
        return 1
    }

    # Create interfaces in namespace
    create_interfaces_in_ns "${name}" "${links[@]}" || {
        logger.error "Failed to create interfaces in network namespace: ${name}" >&2
        return 1
    }

    # Create NAT rule on host
    logger.info "Enabling IP forwarding in namespace ${name}: ip netns exec ${name} sysctl -w net.ipv4.ip_forward=1"
    ip netns exec ${name} sysctl -w net.ipv4.ip_forward=1 || {
        logger.error "Failed to enable IP forwarding in namespace ${name}" >&2
        return 1
    }
    # Set default route
    logger.info "Setting default route via ${default_gateway} in namespace ${name}: ip netns exec ${name} ip route add default via ${default_gateway}"
    ip netns exec ${name} ip route add default via ${default_gateway} || {
        logger.error "Failed to set default route via ${default_gateway} in namespace ${name}" >&2
        return 1
    }

    return 0
}

create_interface_in_ns() {
    local ns_name="$1"
    shift
    local links=("$@")

    # Parse link in links array. Format of each element is like "name=eth-ns01-vb0,interface=veth-ns01-vb0,peer-bridge=virbr0,ip=192.168.122.254/24"
    local link params param
    local p_name p_interface p_peer_bridge p_ip
    for link in "${links[@]}"; do
        IFS=',' read -r -a params <<< "${link}"
        for param in "${params[@]}"; do
            IFS='=' read -r key value <<< "${param}"
            case "${key}" in
                name)
                    p_name="${value}"
                    ;;
                interface)
                    p_interface="${value}"
                    ;;
                peer-bridge)
                    p_peer_bridge="${value}"
                    ;;
                ip)
                    p_ip="${value}"
                    ;;
                *)
                    logger.error "Unknown link parameter: ${key}" >&2
                    return 1
                    ;;
            esac
        done

        # p_name(name of namespace) is required
        if [[ -z "${p_name}" ]]; then
            logger.error "Link parameter 'name(name of namespace)' is required. (-l|--link=\"${link}\")"
            return 1
        fi
        # p_name should start with a letter
        if [[ ! "${p_name:0:1}" =~ [a-zA-Z] ]]; then
            logger.error "Link parameter 'name(name of namespace)' must start with a letter. You specified \"${p_name}\". (-l|--link=\"${link}\")"
            return 1
        fi
        # p_name must be 15 characters or less
        if [[ "${#p_name}" -gt 15 ]]; then
            logger.error "Link parameter 'name(name of namespace)' must be 15 characters or less. You specified \"${p_name}\". (-l|--link=\"${link}\")"
            return 1
        fi

        # p_interface(interface in namespace) is required
        if [[ -z "${p_interface}" ]]; then
            logger.error "Link parameter 'interface(interface in host)' is required. (-l|--link=\"${link}\")"
            return 1
        fi
        # p_interface(interface in namespace) should start with a letter
        if [[ ! "${p_interface:0:1}" =~ [a-zA-Z] ]]; then
            logger.error "Link parameter 'interface(interface in host)' must start with a letter. You specified \"${p_interface}\". (-l|--link=\"${link}\")"
            return 1
        fi
        # p_interface(interface in namespace) must be 15 characters or less
        if [[ "${#p_interface}" -gt 15 ]]; then
            logger.error "Link parameter 'interface(interface in host)' must be 15 characters or less. You specified \"${p_interface}\". (-l|--link=\"${link}\")"
            return 1
        fi

        # p_peer_bridge(peer bridge of the interface) is required
        if [[ -z "${p_peer_bridge}" ]]; then
            logger.error "Link parameter 'peer-bridge(peer bridge of the interface)' is required. (-l|--link=\"${link}\")"
            return 1
        fi

        # p_ip(IP address with CIDR) is required
        if [[ -z "${p_ip}" ]]; then
            logger.error "Link parameter 'ip(IP address with CIDR)' is required. (-l|--link=\"${link}\")"
            return 1
        fi
        # p_ip must be a IP with CIDR format
        if ! echo "${p_ip}" | grep -E -q '^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$'; then
            logger.error "Link parameter 'ip(IP address with CIDR)' must be in IP/CIDR format. You specified \"${p_ip}\". (-l|--link=\"${link}\")"
            return 1
        fi

        do_create_interfaces_in_ns "${name}" "${p_name}" "${p_interface}" "${p_peer_bridge}" "${p_ip}" || {
            logger.error "Failed to create interface ${p_name} in namespace ${name}" >&2
            return 1
        }

        logger_info "Successfully created interface ${p_name}(interface=${p_interface}, peer-bridge=${p_peer_bridge}, ip=${p_ip}) in namespace ${name}"
    done

    return 0
}

do_create_interfaces_in_ns() {
    local ns_name="$1"
    local link_name="$2"
    local interface="$3"
    local peer_bridge="$4"
    local ip="$5"

    # Create outer veth pair if it was not existing.
    if ! check_veth_pair_exists "${link_name}" "${interface}" > /dev/null 2>&1; then
        logger.info "Creating veth pair: ip link add ${link_name} type veth peer name ${interface}"
        ip link add ${link_name} type veth peer name ${interface} || {
            logger.error "Failed to create veth pair: ${link_name} and ${interface}" >&2
            return 1
        }
    else
        logger.info "Veth pair ${link_name}  already exists in . Skipping creation."
    fi

    # Add interface to peer bridge if not already added.
    if [[ ! -e "/sys/class/net/${peer_bridge}/brif/${interface}" ]]; then
        logger.info "Adding ${interface} to bridge ${peer_bridge}: brctl addif ${peer_bridge} ${interface}"
        brctl addif ${peer_bridge} ${interface} || {
            logger.error "Failed to add ${interface} to bridge ${peer_bridge}" >&2
            return 1
        }
    else
        logger.info "${interface} is already added to bridge ${peer_bridge}. Skipping adding."
    fi



    logger.info "Setting ${interface} up: ip link set ${interface} up"
    ip link set ${interface} up || {
        logger.error "Failed to set ${interface} up" >&2
        return 1
    }
    logger.info "Moving ${link_name} to namespace ${ns_name}: ip link set ${link_name} netns ${ns_name}"
    ip link set ${link_name} netns ${ns_name} || {
        logger.error "Failed to move ${link_name} to namespace ${ns_name}" >&2
        return 1
    }
    logger.info "Assigning IP ${ip} to ${link_name} in namespace ${ns_name}: ip netns exec ${ns_name} ip addr add ${ip} dev ${link_name}"
    ip netns exec ${ns_name} ip addr add ${ip} dev ${link_name} || {
        logger.error "Failed to assign IP ${ip} to ${link_name} in namespace ${ns_name}" >&2
        return 1
    }
    logger.info "Setting ${link_name} up in namespace ${ns_name}: ip netns exec ${ns_name} ip link set ${link_name} up"
    ip netns exec ${ns_name} ip link set ${link_name} up || {
        logger.error "Failed to set ${link_name} up in namespace ${ns_name}" >&2
        return 1
    }

    return 0
}

check_veth_pair_exists() {
    local link_name="$1"
    local peer_name="$2"
    
    # Check both interfaces exist
    [[ ! -e "/sys/class/net/${link_name}" ]] && return 1
    [[ ! -e "/sys/class/net/${peer_name}" ]] && return 1
    
    # Check if they are actually peers
    local link_peer_ifindex=$(cat "/sys/class/net/${link_name}/iflink")
    local peer_ifindex=$(cat "/sys/class/net/${peer_name}/ifindex")
    
    [[ "$link_peer_ifindex" == "$peer_ifindex" ]]
}

usage() {
    cat << EOF
Usage: create_ns.sh [OPTIONS]
Options:
  -n, --name NAME
        Name of the network namespace to create (required)
  --outer-link-name NAME
        Name of the outer veth link inside the namespace (required)
  --outer-interface NAME
        Name of the outer veth interface on the host side (required)
  --outer-peer-bridge NAME
        Name of the bridge to attach the outer interface (required)
  --outer-ip-with-cidr IP/CIDR
        IP address with CIDR for the outer interface (required)
  --inner-link-name NAME
        Name of the inner veth link inside the namespace (required)
  --inner-interface NAME
        Name of the inner veth interface on the host side (required)
  --inner-peer-bridge NAME
        Name of the bridge to attach the inner interface (required)
  --inner-ip-with-cidr IP/CIDR
        IP address with CIDR for the inner interface (required)
  --default-gateway IP
        Default gateway IP address inside the namespace (required)
  -h, --help
        Show this help message and exit
Example:
  create_ns.sh \\
    --name ns01 \\
    --outer-link-name link-ns01-vb0 \\
    --outer-interface veth-ns01-vb0 \\
    --outer-peer-bridge virbr0 \\
    --outer-ip-with-cidr 192.168.122.11/24 \\
    --inner-link-name link-ns01-br0 \\
    --inner-interface veth-ns01-br0 \\
    --inner-peer-bridge brint01 \\
    --inner-ip-with-cidr 172.31.0.11/16 \\
    --default-gateway 192.168.122.1
EOF
}

main "$@"
