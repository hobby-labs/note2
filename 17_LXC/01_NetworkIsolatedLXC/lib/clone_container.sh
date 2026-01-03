#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local clone_from clone_to hostname lxc_base_dir nx_name

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getoptses

    local options
    options=$(getoptses --longoptions "clone-from:,clone-to:,hostname:,list,lxc-base-dir:,ns-name:" -- "$@")
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

    # if hostname is not specified, use clone_to as hostname
    if [[ -z "$hostname" ]]; then
        hostname="$clone_to"
    fi

    # Declare LXC_PATH if not set
    setup_lxc_environment_variables "${lxc_base_dir}" "${ns_name}" || return 1


    do_clone "$hostname" "$clone_from" "$clone_to" || return 1

    return 0
}

do_list_base_images() {
    ls -1 "$BASE_TEMPLATE_DIR"
    return 0
}

do_clone() {
    local hostname="$1"
    local clone_from="$2"
    local clone_to="$3"
    local custom_template="$4"

    logger_info "Cloning and extracting LXC image from \"$clone_from\" to \"$clone_to\" with template \"$custom_template\""



    return 0
}

clone_and_extract_image() {
    local clone_from="$1"
    local clone_to="$2"
    local file_name

    mkdir -p "${BASE_LXC_DIR%/}/${clone_to}" || {
        echo "Failed to create directory for the new LXC: ${BASE_LXC_DIR%/}/${clone_to}" >&2
        return 1
    }

    file_name=$(ls "${BASE_TEMPLATE_DIR%/}/${clone_from}."*)

    # If file name end with .tar.gz, extract it as tar.gz.
    # If file name end with .tar.xz, extract it as tar.xz.
    # Otherwise return error.
    if [[ "$file_name" == *.tar.gz ]]; then
        tar -xzf "$file_name" -C "${BASE_LXC_DIR%/}/${clone_to}/"
    elif [[ "$file_name" == *.tar.xz ]]; then
        tar -xJf "$file_name" -C "${BASE_LXC_DIR%/}${clone_to}/"
    else
        echo "Unknown file format: $file_name" >&2
        return 1
    fi

    return 0
}

main "$@"