#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local clone_from clone_to lxc_base_dir ns_name interface_list=()

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getoptses

    local options
    options=$(getoptses --longoptions "clone-from:,clone-to:,list,interface:,lxc-base-dir:,ns-name:" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        echo "Invalid option were specified" >&2
        return 1
    fi
    eval set -- "$options"

    while true; do
        case "$1" in
        --clone-to )
            clone_to="$2"
            shift
            ;;
        --clone-from )
            clone_from="$2"
            shift 2
            ;;
        --list )
            do_list_base_images
            return 0
            ;;
        --lxc-base-dir )
            lxc_base_dir="$2"
            shift 2
            ;;
        --ns-name )
            ns_name="$2"
            shift 2
            ;;
        --interface)
            # An expected format of interface is like
            # "bind_bridge=${bridge_name_to_bind},interface_name=${interface_name},ip=${ip_addr},netmask=${netmask},gateway=${gateway},dns=${dns}"
            #     ${bridge_name_to_bind}: Name of the bridge to which the interface is connected
            #     ${interface_name}: Name of the interface inside the container
            #     ${ip_addr}: IP address assigned to the interface
            #     ${netmask}: Netmask for the interface
            #     ${gateway}: (Optional) Default gateway for the interface
            #     ${dns}: (Optional) DNS server for the interface
            interface_list+=("$2")
            shift 2
            ;;
        -- )
            shift
            break
            ;;
        * )
            echo "Internal error has occured" >&2
            return 1
            ;;
        esac
    done

    # --clone-from and --clone-to are required
    if [[ -z "$clone_from" ]]; then
        echo "--clone-from must be specified" >&2
        return 1
    fi
    if [[ -z "$clone_to" ]]; then
        echo "--clone-to must be specified" >&2
        return 1
    fi

    # Validate interface syntax
    validate_all_interfaces "${interface_list[@]}" || return 1

    # Declare LXC_BASE_DIR, LXC_PATH, LXC_BASE_IMAGE_DIR if not set
    setup_lxc_environment_variables "${lxc_base_dir}" "${ns_name}" || return 1

    do_clone "$clone_from" "$clone_to" "${interface_list[@]}" || return 1

    return 0
}

do_list_base_images() {
    ls -1 "${LXC_BASE_IMAGE_DIR%/}/" || {
        logger_error "Failed to list base images in \"${LXC_BASE_IMAGE_DIR%/}/\"" >&2
        return 1
    }
    return 0
}

do_clone() {
    local clone_from="$1"
    local clone_to="$2"
    shift 2
    local interface_list=("$@")

    logger_info "Cloning and extracting LXC image from \"$clone_from\" to \"$clone_to\"."

    # Check if the base image exists
    if [[ ! -d "${LXC_BASE_IMAGE_DIR%/}/${clone_from}" ]]; then
        logger_error "Base image \"$clone_from\" does not exist in \"${LXC_BASE_IMAGE_DIR%/}/\"." >&2
        return 1
    fi

    # Mount as overlayfs and create the new container.
    # * Create a directory ${LXC_PATH%/}/${clone_to}/rootfs if not exists.
    # * Mount overlayfs to ${LXC_PATH%/}/${clone_to}/rootfs
    #   with lowerdir=${LXC_BASE_IMAGE_DIR%/}/${clone_from}/rootfs
    #        upperdir=${LXC_PATH%/}/${clone_to}/overlay/upper
    #        workdir=${LXC_PATH%/}/${clone_to}/overlay/work
    setup_overlayfs_container "${LXC_BASE_IMAGE_DIR%/}/${clone_from}" "${clone_to}" || {
        logger_error "Failed to setup overlayfs for container \"$clone_to\"." >&2
        return 1
    }

    post_setup "${clone_to}" "${interface_list[@]}" || {
        logger_error "Failed to perform post setup for container \"$clone_to\"." >&2
        return 1
    }


    logger_info "Cloned LXC container \"$clone_to\" from base image \"$clone_from\"."

    return 0
}

post_setup() {
    local lxc_name="$1"
    shift
    local interface_list=("$@")

    # Create options of create_lxc_conf.sh for interfaces
    local interface interface_options_for_create_lxc_conf=()
    for interface in "${interface_list[@]}"; do
        # Append --interface option only with keys "bind_bridge=" and "interface_name=".
        local bind_bridge interface_name
        bind_bridge=$(parse_interface_value "$interface" "bind_bridge") || {
            logger_error "Failed to parse bind_bridge from interface: ${interface} in ${FUNCNAME[0]}" >&2
            return 1
        }
        interface_name=$(parse_interface_value "$interface" "interface_name") || {
            logger_error "Failed to parse interface_name from interface: ${interface} in ${FUNCNAME[0]}" >&2
            return 1
        }
        interface_options_for_create_lxc_conf+=("--interface" "bind_bridge=${bind_bridge},interface_name=${interface_name}")
    done

    . ${SCRIPTDIR%/}/create_lxc_conf.sh --lxc-name "${lxc_name}" "${interface_options_for_create_lxc_conf[@]}" || return 1
    . ${SCRIPTDIR%/}/inside/container/create_hostname_conf.sh --lxc-name "${lxc_name}" --hostname "${lxc_name}" || return 1
    . ${SCRIPTDIR%/}/inside/container/create_fstab_conf.sh --lxc-name "${lxc_name}" || return 1

    for interface in "${interface_list[@]}"; do
        local interface_name ip_addr netmask gateway dns
        interface_name=$(parse_interface_value "$interface" "interface_name") || {
            logger_error "Failed to parse interface_name from interface: ${interface} in ${FUNCNAME[0]}" >&2
            return 1
        }
        ip_addr=$(parse_interface_value "$interface" "ip") || {
            logger_error "Failed to parse ip from interface: ${interface} in ${FUNCNAME[0]}" >&2
            return 1
        }
        netmask=$(parse_interface_value "$interface" "netmask") || {
            logger_error "Failed to parse netmask from interface: ${interface} in ${FUNCNAME[0]}" >&2
            return 1
        }
        gateway=$(parse_interface_value "$interface" "gateway") || {
            # gateway is optional
            gateway=""
        }
        dns=$(parse_interface_value "$interface" "dns") || {
            # dns is optional
            dns=""
        }

        . ${SCRIPTDIR%/}/inside/container/create_interface_conf.sh --lxc-name "${lxc_name}" --interface-name "${interface_name}" \
                --ip "${ip_addr}" --netmask "${netmask}" \
                $( [[ -n "${gateway}" ]] && echo "--gateway ${gateway}" ) \
                $( [[ -n "${dns}" ]] && echo "--dns ${dns}" ) \
                || return 1
    done

    return 0
}

setup_overlayfs_container() {
    local base_image_dir="$1"
    local lxc_name="$2"

    local container_dir="${LXC_PATH%/}/${lxc_name}"
    local rootfs_dir="${container_dir}/rootfs"
    local overlay_upper_dir="${container_dir}/overlay/upper"
    local overlay_work_dir="${container_dir}/overlay/work"

    # Create necessary directories
    mkdir -p "${rootfs_dir}"                             || return 1
    mkdir -p "${overlay_upper_dir}"                      || return 1
    mkdir -p "${overlay_work_dir}"                       || return 1

    # Mount overlayfs
    mount -t overlay overlay -o "lowerdir=${base_image_dir%/}/rootfs,upperdir=${overlay_upper_dir},workdir=${overlay_work_dir}" "${rootfs_dir}" || {
        logger_error "Failed to mount overlayfs for container \"$lxc_name\"." >&2
        return 1
    }
    logger_info "Mounted overlayfs for container \"$lxc_name\": LOWERDIR=${base_image_dir%/}/rootfs, UPPERDIR=${overlay_upper_dir}, WORKDIR=${overlay_work_dir}, MOUNTPOINT=${rootfs_dir}"

    return 0
}

# Validation functions from here ------------------------------------------------

validate_name() {
    local name="$1"
    # Must start with letter, contain only letters, numbers, hyphens, underscores
    [[ "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]
}

validate_ipv4() {
    local ip="$1"
    # Check basic IPv4 pattern: four numbers separated by dots
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # Validate each octet is 0-255
    local IFS='.'
    local -a octets=($ip)
    for octet in "${octets[@]}"; do
        if ((octet > 255)); then
            return 1
        fi
    done
    
    return 0
}

validate_netmask() {
    local mask="$1"
    # Check basic pattern first
    if ! validate_ipv4 "$mask"; then
        return 1
    fi
    
    # Valid netmask octets: 0, 128, 192, 224, 240, 248, 252, 254, 255
    local valid_masks="^(255|254|252|248|240|224|192|128|0)$"
    local IFS='.'
    local -a octets=($mask)
    
    local seen_non_255=0
    for octet in "${octets[@]}"; do
        if [[ ! "$octet" =~ $valid_masks ]]; then
            return 1
        fi
        
        # After seeing a non-255 octet, all following must be 0
        if ((seen_non_255)); then
            if ((octet != 0)); then
                return 1
            fi
        elif ((octet != 255)); then
            seen_non_255=1
        fi
    done
    
    return 0
}

parse_interface_value() {
    local interface="$1"
    local key="$2"
    
    # Extract value for the given key
    if [[ "$interface" =~ (^|,)${key}=([^,]+) ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    fi
    return 1
}

validate_interface_syntax() {
    local interface="$1"
    
    # Check if required fields exist
    if [[ ! "$interface" =~ (^|,)bind_bridge= ]] || \
       [[ ! "$interface" =~ (^|,)interface_name= ]] || \
       [[ ! "$interface" =~ (^|,)ip= ]] || \
       [[ ! "$interface" =~ (^|,)netmask= ]]; then
        logger_error "Invalid interface syntax: $interface" >&2
        logger_error "Required format: bind_bridge=<bridge>,interface_name=<name>,ip=<ip>,netmask=<mask>[,gateway=<gw>][,dns=<dns>]" >&2
        return 1
    fi
    
    # Validate bind_bridge
    local bind_bridge
    bind_bridge=$(parse_interface_value "$interface" "bind_bridge") || {
        logger_error "Failed to parse bind_bridge from: $interface" >&2
        return 1
    }
    if ! validate_name "$bind_bridge"; then
        logger_error "Invalid bind_bridge name: $bind_bridge (must start with letter and contain only letters, numbers, -, _)" >&2
        return 1
    fi
    
    # Validate interface_name
    local interface_name
    interface_name=$(parse_interface_value "$interface" "interface_name") || {
        logger_error "Failed to parse interface_name from: $interface" >&2
        return 1
    }
    if ! validate_name "$interface_name"; then
        logger_error "Invalid interface_name: $interface_name (must start with letter and contain only letters, numbers, -, _)" >&2
        return 1
    fi
    
    # Validate ip
    local ip
    ip=$(parse_interface_value "$interface" "ip") || {
        logger_error "Failed to parse ip from: $interface" >&2
        return 1
    }
    if ! validate_ipv4 "$ip"; then
        logger_error "Invalid IP address: $ip" >&2
        return 1
    fi
    
    # Validate netmask
    local netmask
    netmask=$(parse_interface_value "$interface" "netmask") || {
        logger_error "Failed to parse netmask from: $interface" >&2
        return 1
    }
    if ! validate_netmask "$netmask"; then
        logger_error "Invalid netmask: $netmask" >&2
        return 1
    fi
    
    # Validate optional gateway
    local gateway
    if gateway=$(parse_interface_value "$interface" "gateway"); then
        if ! validate_ipv4 "$gateway"; then
            logger_error "Invalid gateway IP address: $gateway" >&2
            return 1
        fi
    fi
    
    # Validate optional dns
    local dns
    if dns=$(parse_interface_value "$interface" "dns"); then
        if ! validate_ipv4 "$dns"; then
            logger_error "Invalid DNS IP address: $dns" >&2
            return 1
        fi
    fi
    
    return 0
}

validate_all_interfaces() {
    local interface_list=("$@")
    
    for interface in "${interface_list[@]}"; do
        validate_interface_syntax "$interface" || return 1
    done
    
    return 0
}

main "$@"