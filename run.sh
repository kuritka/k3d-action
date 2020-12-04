#!/bin/bash

set -o errexit
set -o pipefail
#set -o nounset  ;handling unset environment variables manually


YELLOW=
CYAN=
RED=
NC=
if [[ -z "${NO_COLOR}" ]]; then
      YELLOW="\033[0;33m"
      CYAN="\033[1;36m"
      NC="\033[0m"
      RED="\033[0;91m"
fi
K3D_URL=https://raw.githubusercontent.com/rancher/k3d/main/install.sh

usage(){
  cat <<EOF

  Usage: $(basename "$0") <COMMAND>
  Commands:
      deploy            deploy custom k3d cluster
      clean             destroy k3d cluster

  Environment variables:
      deploy
                        K3D_NAME (Required) k3d cluster name
                        K3D_ARGS (Optional) k3d arguments
      clean
                        K3D_NAME (Required) k3d cluster name
EOF
}

panic() {
  (>&2 echo -e " - ${RED}$@${NC}")
  usage
  exit 1
}

deploy(){
    if [[ -z "${INPUT_K3D_NAME}" ]]; then
      panic "K3D_NAME must be set"
    fi
    local k3dName=${INPUT_K3D_NAME}
    local k3dArgs="${INPUT_K3D_ARGS:-}"

    echo -e "${YELLOW}Downloading ${CYAN}k3d ${NC}see: ${K3D_URL}"
    curl --silent --fail ${K3D_URL} | bash

    echo -e "\n${YELLOW}Deploy cluster ${CYAN}$k3dName ${NC}"
    eval "k3d cluster create ${k3dName} --wait ${k3dArgs:-}"
}

clean(){
    if [[ -z "${INPUT_K3D_NAME}" ]]; then
      panic "K3D_NAME must be set"
    fi
    local k3dName="${INPUT_K3D_NAME}"
    echo -e "\n${YELLOW}Destroy cluster ${CYAN}$k3dName ${NC}"
    eval "k3d cluster delete ${k3dName}"
}


if [[ "$#" -lt 1 ]]; then
  usage
  exit 1
fi

case "$1" in
    "deploy")
       deploy
    ;;
    "clean")
       clean
    ;;
      *)
  usage
  exit 0
  ;;
esac

