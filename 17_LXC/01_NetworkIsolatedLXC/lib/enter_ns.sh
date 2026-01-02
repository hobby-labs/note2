#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local namespace

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getopses

    local options
    options=$(getoptses -o "n:h" --longoptions "name:,help" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        echo "Invalid option were specified" >&2
        return 1
    fi
    eval set -- "$options"

    while true; do
        case "$1" in
        -n | --name )
            namespace="$2"
            shift 2
            ;;
        -h | --help )
            usage
            shift
            ;;
        -- )
            shift
            break
            ;;
        * )
            logger_error "Internal error has occured" >&2
            return 1
            ;;
        esac
    done

    if [[ -z "$namespace" ]]; then
        logger_error "Namespace name must be specified" >&2
        return 1
    fi

    do_enter_ns "$namespace" || return 1

    return 0
}

usage() {

}

do_enter_ns() {
    local namespace="$1"

    ip netns exec "$namespace" bash -c "
    echo \"================================================\"
    echo \"  You are now in the $namespace namespace\"
    echo \"  To verify: ip netns identify \$\$\"
    echo \"================================================\"
    export PS1=\"($namespace) [\u@\h \W]\$ \"
    exec bash
    "

    return $?
}

main "$@"
