#!/usr/bin/env bash

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR"

main() {
    local ns_name

    . ${SCRIPTDIR%/}/functions
    . ${SCRIPTDIR%/}/getoptses

    local options
    options=$(getoptses -o "n:h" --longoptions "ns-name:,help" -- "$@")
    if [[ "$?" -ne 0 ]]; then
        echo "Invalid option were specified" >&2
        return 1
    fi
    eval set -- "$options"

    while true; do
        case "$1" in
        -n | --ns-name )
            ns_name="$2"
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

    if [[ -z "$ns_name" ]]; then
        logger_error "--ns_name must be specified" >&2
        return 1
    fi

    do_enter_ns "$ns_name" || return 1
    return 0
}

usage() {
    cat << EOF
Usage: $0 --ns_name <namespace-name>
Options:
  -n, --ns_name       Name of the network namespace to enter
  -h, --help          Show this help message
EOF

    return 0
}

do_enter_ns() {
    local ns_name="$1"

    # Create temporary rcfile
    TMPRC=$(mktemp)
    trap "rm -f $TMPRC" EXIT

    cat > $TMPRC << EOF
# Source system bashrc first
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Set namespace-specific variables
export NSNAME=${ns_name}
export PS1="(\${NSNAME})[\u@\h \W]\$ "
export LXC_BASE_DIR=/var/lib/lxc-ns
export LXCPATH=\${LXC_BASE_DIR}/\${NSNAME}

# Create directory if not exists
mkdir -p \${LXCPATH}

# Create aliases for lxc commands
alias lxc-ls="lxc-ls -P \${LXCPATH}"
alias lxc-start="lxc-start -P \${LXCPATH}"
alias lxc-stop="lxc-stop -P \${LXCPATH}"
alias lxc-info="lxc-info -P \${LXCPATH}"
alias lxc-attach="lxc-attach -P \${LXCPATH}"
alias lxc-console="lxc-console -P \${LXCPATH}"
alias lxc-destroy="lxc-destroy -P \${LXCPATH}"
EOF

    ip netns exec ${ns_name} bash --rcfile $TMPRC

    return $?
}

main "$@"
