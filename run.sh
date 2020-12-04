#!/bin/bash

set -o errexit
set -o pipefail
#set -o nounset  ;handling unset environment variables manually


YELLOW=
CYAN=
RED=
NC=
K3D_URL=https://raw.githubusercontent.com/rancher/k3d/main/install.sh
DEFAULT_NETWORK=k3d-action-bridge-network
DEFAULT_CIDR=172.16.0.0/24

#######################
#
#     FUNCTIONS
#
#######################
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
                        K3D_NETWORK (Optional) If not set than default k3d-action-bridge-network is created
                                               and all clusters share that network.
      clean
                        K3D_NAME (Required) k3d cluster name
EOF
}

panic() {
  # shellcheck disable=SC2145
  (>&2 echo -e " - ${RED}$@${NC}")
  usage
  exit 1
}

deploy(){
    local name=${K3D_NAME}
    local arguments=${K3D_ARGS:-}
    local network=${K3D_NETWORK:$DEFAULT_NETWORK}
    local cidr=${K3D_CIDR:$DEFAULT_CIDR}

    echo -e "${YELLOW}name ${CYAN}$name ${NC}"
    echo -e "${YELLOW}arguments ${CYAN}$arguments ${NC}"
    echo -e "${YELLOW}network ${CYAN}$network ${NC}"
    echo -e "${YELLOW}cidr ${CYAN}$cidr ${NC}"

    docker network create --driver=bridge --cidr=$cidr $network

    echo -e "${YELLOW}Downloading ${CYAN}k3d ${NC}see: ${K3D_URL}"
    curl --silent --fail ${K3D_URL} | bash

    echo -e "\n${YELLOW}Deploy cluster ${CYAN}$name ${NC}"
    eval "k3d cluster create $name --wait $arguments --network $network"
}

clean(){
    if [[ -z "${K3D_NAME}" ]]; then
      panic "K3D_NAME must be set"
    fi
    local name="${K3D_NAME}"
    echo -e "\n${YELLOW}Destroy cluster ${CYAN}$name ${NC}"
    eval "k3d cluster delete ${name}"
}


hello(){
   echo -e "\n${YELLOW}Hello ${CYAN} World ${NC}"
}

#######################
#
#     GUARDS SECTION
#
#######################
if [[ "$#" -lt 1 ]]; then
  usage
  exit 1
fi
if [[ -z "${NO_COLOR}" ]]; then
      YELLOW="\033[0;33m"
      CYAN="\033[1;36m"
      NC="\033[0m"
      RED="\033[0;91m"
fi
if [[ -z "${K3D_NAME}" ]]; then
  panic "K3D_NAME must be set"
fi


#######################
#
#     COMMANDS
#
#######################
case "$1" in
    "deploy")
       deploy
    ;;
    "clean")
       clean
    ;;
    "hello")
       hello
    ;;
      *)
  usage
  exit 0
  ;;
esac

