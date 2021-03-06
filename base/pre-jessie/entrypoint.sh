#!/usr/bin/env bash

DB=/solvers/solvers.json

set -e

if [ -z "${SOLVER}" ]; then
    echo "Oops, no SOLVER defined."
    exit 1
fi

get_param() {
    jq -r ".\"${SOLVER}\".$1" "${DB}"
}

SOLVER_CALL=$(get_param call)
SOLVER_NAME=$(get_param name)
SOLVER_PATH=$(get_param path)
if [[ "${SOLVER_PATH}" == "null" ]]; then
    SOLVER_PATH="${SOLVER_NAME}"
fi

usage() {
    echo "Usage:"
    echo "  FILECNF [FILEPROOF]"
    echo "  --mode MODE FILECNF [FILEPROOF]"
    echo "  --raw <$SOLVER arguments>"
    echo "  -h"
    exit 1
}

call_solver() {
    export PATH=.:$PATH
    set -x
    cd "/solvers/${SOLVER_PATH}"
    set +x
    if [ ${TIMEOUT} -eq 0 ]; then
        set -x
        "${SOLVER_CALL}" "${@}"
    else
        set -x
        timeout ${TIMEOUT} "${SOLVER_CALL}" "${@}"
    fi
}

mycall() {
    if [ $# -eq 0 ]; then usage; fi
    k=$1; shift
    args=()
    while read -r value; do
        args+=("$value")
    done < <(get_param $k|jq -r '.[]')
    if [ -z ${args} ]; then
        echo "WARNING, this solver has no $k, falling back to defaults.">&2
        mycall args "${@}"
        return
    fi

    FILECNF="`readlink -f -- "${1}"`"
    FILEPROOF=""
    if [ $# -eq 2 ]; then
        FILEPROOF="`readlink -f -- "${2}"`"
    fi
    RANDOMSEED=${RANDOMSEED:-1234567}
    MAXNBTHREAD=${MAXNBTHREAD:-1}
    MEMLIMIT=${MEMLIMIT:-1024}
    export TIMEOUT=${TIMEOUT:-3600}

    if [[ "${FILECNF##*.}" == "gz" ]]; then
        if [[ "$(get_param gz)" == "false" ]]; then
            echo "# gunzip ${FILECNF}..."
            gunzip -c "${FILECNF}" > /tmp/gunzipped.cnf
            echo "# ...done"
            FILECNF=/tmp/gunzipped.cnf
        fi
    fi
    for (( i=0; i<${#args[@]}; ++i )); do
        a="${args[$i]/FILECNF/$FILECNF}"
        a="${a/RANDOMSEED/$RANDOMSEED}"
        a="${a/MAXNBTHREAD/$MAXNBTHREAD}"
        a="${a/MEMLIMIT/$MEMLIMIT}"
        a="${a/TIMEOUT/$TIMEOUT}"
        args[$i]="${a/FILEPROOF/$FILEPROOF}"
    done
    call_solver "${args[@]}"
}

echo "#### $DOCKER_IMAGE ####"

if [ -z $1 ]; then
    usage
fi

case "${1:-}" in
    -h|--help) usage;;
    --raw) shift; call_solver "${@}";;
    --mode) shift
        mode=$1; shift
        mycall args$mode "${@}";;
    *)
        case $# in
            1) mode=args;;
            2) mode=argsproof;;
            *) usage
        esac
        mycall $mode "${@}"
esac
