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
    echo "  --raw <$SOLVER arguments>"
    echo "  -h"
    exit 1
}

call_solver() {
    set -x
    "/solvers/${SOLVER_PATH}/${SOLVER_CALL}" "${@}"
}

mycall() {
    case $# in
        1) k=args ;;
        2) k=argsproof ;;
        *) usage
    esac
    readarray -t args <<<$(get_param $k|jq -r ".[]")

    FILECNF="${1}"
    if [[ "${FILECNF##*.}" == "gz" ]]; then
        if [[ "$(get_param gz)" == "false" ]]; then
            echo "# gunzip ${FILECNF}..."
            gunzip -c "${FILECNF}" > /tmp/cnf
            echo "# ...done"
            FILECNF=/tmp/cnf
        fi
    fi

    FILEPROOF="${2}"
    for (( i=0; i<${#args[@]}; ++i )); do
        a="${args[$i]/FILECNF/$FILECNF}"
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
    *) mycall "${@}"
esac