#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local name \
          outer_link_name outer_interface outer_peer_bridge outer_ip_with_cidr \
          inner_link_name inner_interface inner_peer_bridge inner_ip_with_cidr \
          default_gateway

    . ${SCRIPTDIR%/}/functions/all

    local options
    options=$(getoptses -o "n:h" --longoptions "name:,outer-link-name:,outer-interface:,outer-peer-bridge:,outer-ip-with-cidr:,inner-link-name:,inner-interface:,inner-peer-bridge:,inner-ip-with-cidr:,default-gateway:,help" -- "$@")
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
        --outer-link-name )
            outer_link_name="$2"
            shift 2
            ;;
        --outer-interface )
            outer_interface="$2"
            shift 2
            ;;
        --outer-ip-with-cidr )
            outer_ip_with_cidr="$2"
            shift 2
            ;;
        --outer-peer-bridge )
            outer_peer_bridge="$2"
            shift 2
            ;;
        --outer-ip-with-cidr )
            outer_ip_with_cidr="$2"
            shift 2
            ;;
        --inner-link-name )
            inner_link_name="$2"
            shift 2
            ;;
        --inner-interface )
            inner_interface="$2"
            shift 2
            ;;
        --inner-peer-bridge )
            inner_peer_bridge="$2"
            shift 2
            ;;
        --inner-ip-with-cidr )
            inner_ip_with_cidr="$2"
            shift 2
            ;;
        --default-gateway )
            default_gateway="$2"
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

    # --name is required
    if [[ -z "${name}" ]]; then
        logger.error "--name is required" >&2
        return 1
    fi
    # ---outer-link-name is required
    if [[ -z "${outer_link_name}" ]]; then
        logger.error "--outer-link-name is required" >&2
        return 1
    fi
    # ---outer-interface is required
    if [[ -z "${outer_interface}" ]]; then
        logger.error "--outer-interface is required" >&2
        return 1
    fi
    # ---outer-peer-bridge is required
    if [[ -z "${outer_peer_bridge}" ]]; then
        logger.error "--outer-peer-bridge is required" >&2
        return 1
    fi
    # ---outer-ip-with-cidr is required
    if [[ -z "${outer_ip_with_cidr}" ]]; then
        logger.error "--outer-ip-with-cidr is required" >&2
        return 1
    fi
    # ---inner-link-name is required
    if [[ -z "${inner_link_name}" ]]; then
        logger.error "--inner-link-name is required" >&2
        return 1
    fi
    # ---inner-interface is required
    if [[ -z "${inner_interface}" ]]; then
        logger.error "--inner-interface is required" >&2
        return 1
    fi
    # ---inner-peer-bridge is required
    if [[ -z "${inner_peer_bridge}" ]]; then
        logger.error "--inner-peer-bridge is required" >&2
        return 1
    fi
    # ---inner-ip-with-cidr is required
    if [[ -z "${inner_ip_with_cidr}" ]]; then
        logger.error "--inner-ip-with-cidr is required" >&2
        return 1
    fi
    # ---default-gateway is required
    if [[ -z "${default_gateway}" ]]; then
        logger.error "--default-gateway is required" >&2
        return 1
    fi

    do_create_ns "${name}" \
                    "${outer_link_name}" "${outer_interface}" "${outer_peer_bridge}" "${outer_ip_with_cidr}" \
                    "${inner_link_name}" "${inner_interface}" "${inner_peer_bridge}" "${inner_ip_with_cidr}" \
                    "${default_gateway}" || {
        logger.error "Failed to create network namespace: ${name}" >&2
        return 1
    }
}

do_create_ns() {
    local name=$1
    local outer_link_name=$2
    local outer_interface=$3
    local outer_peer_bridge=$4
    local outer_ip_with_cidr=$5
    local inner_link_name=$6
    local inner_interface=$7
    local inner_peer_bridge=$8
    local inner_ip_with_cidr=$9
    local default_gateway=${10}

    logger.info "Creating network namespace: ${name}: ip netns add ${name}"
    ip netns add ${name}

    # Create outer veth pair
    logger.info "Creating outer veth pair: ip link add ${outer_link_name} type veth peer name ${outer_interface}"
    ip link add ${outer_link_name} type veth peer name ${outer_interface} || {
        logger.error "Failed to create veth pair: ${outer_link_name} and ${outer_interface}" >&2
        return 1
    }

    logger.info "Adding ${outer_interface} to bridge ${outer_peer_bridge}: brctl addif ${outer_peer_bridge} ${outer_interface}"
    brctl addif ${outer_peer_bridge} ${outer_interface} || {
        logger.error "Failed to add ${outer_interface} to bridge ${outer_peer_bridge}" >&2
        return 1
    }
    logger.info "Setting ${outer_interface} up: ip link set ${outer_interface} up"
    ip link set ${outer_interface} up || {
        logger.error "Failed to set ${outer_interface} up" >&2
        return 1
    }
    logger.info "Moving ${outer_link_name} to namespace ${name}: ip link set ${outer_link_name} netns ${name}"
    ip link set ${outer_link_name} netns ${name} || {
        logger.error "Failed to move ${outer_link_name} to namespace ${name}" >&2
        return 1
    }
    logger.info "Assigning IP ${outer_ip_with_cidr} to ${outer_link_name} in namespace ${name}: ip netns exec ${name} ip addr add ${outer_ip_with_cidr} dev ${outer_link_name}"
    ip netns exec ${name} ip addr add ${outer_ip_with_cidr} dev ${outer_link_name} || {
        logger.error "Failed to assign IP ${outer_ip_with_cidr} to ${outer_link_name} in namespace ${name}" >&2
        return 1
    }
    logger.info "Setting ${outer_link_name} up in namespace ${name}: ip netns exec ${name} ip link set ${outer_link_name} up"
    ip netns exec ${name} ip link set ${outer_link_name} up || {
        logger.error "Failed to set ${outer_link_name} up in namespace ${name}" >&2
        return 1
    }

    # Create inner veth pair
    logger.info "Creating inner veth pair: ip link add ${inner_link_name} type veth peer name ${inner_interface}"
    ip link add ${inner_link_name} type veth peer name ${inner_interface} || {
        logger.error "Failed to create veth pair: ${inner_link_name} and ${inner_interface}" >&2
        return 1
    }
    logger.info "Adding ${inner_interface} to bridge ${inner_peer_bridge}: brctl addif ${inner_peer_bridge} ${inner_interface}"
    brctl addif ${inner_peer_bridge} ${inner_interface} || {
        logger.error "Failed to add ${inner_interface} to bridge ${inner_peer_bridge}" >&2
        return 1
    }
    logger.info "Setting ${inner_interface} up: ip link set ${inner_interface} up"
    ip link set ${inner_interface} up || {
        logger.error "Failed to set ${inner_interface} up" >&2
        return 1
    }
    logger.info "Moving ${inner_link_name} to namespace ${name}: ip link set ${inner_link_name} netns ${name}"
    ip link set ${inner_link_name} netns ${name} || {
        logger.error "Failed to move ${inner_link_name} to namespace ${name}" >&2
        return 1
    }
    logger.info "Assigning IP ${inner_ip_with_cidr} to ${inner_link_name} in namespace ${name}: ip netns exec ${name} ip addr add ${inner_ip_with_cidr} dev ${inner_link_name}"
    ip netns exec ${name} ip addr add ${inner_ip_with_cidr} dev ${inner_link_name} || {
        logger.error "Failed to assign IP ${inner_ip_with_cidr} to ${inner_link_name} in namespace ${name}" >&2
        return 1
    }
    logger.info "Setting ${inner_link_name} up in namespace ${name}: ip netns exec ${name} ip link set ${inner_link_name} up"
    ip netns exec ${name} ip link set ${inner_link_name} up || {
        logger.error "Failed to set ${inner_link_name} up in namespace ${name}" >&2
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
