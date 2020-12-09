#!/bin/bash

set -o errexit
set -o pipefail
#set -o nounset     ;handling unset environment variables manually
#set -x             ;debugging

YELLOW=
CYAN=
RED=
NC=
K3D_URL=https://raw.githubusercontent.com/rancher/k3d/main/install.sh
DEFAULT_NETWORK=k3d-action-bridge-network
DEFAULT_CIDR=172.16.0.0/24
NOT_FOUND=k3d-not-found-network
REGISTRY_LOCAL=registry.local
REGISTRY_CONFIG_PATH="$(pwd)/registries.yaml"

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
    local network=${K3D_NETWORK:-$DEFAULT_NETWORK}
    local subnet=${K3D_CIDR:-$DEFAULT_CIDR}
    local registry=${K3D_REGISTRY:-}
    local registryArg

   existing_network=$(docker network list | awk '   {print $2 }' | grep -w "^$network$" || echo $NOT_FOUND)

    if [[ ($network == "$DEFAULT_NETWORK") && ($subnet != "$DEFAULT_CIDR") ]]
    then
      panic "You can't specify custom subnet for default network."
    fi

    if [[ ($network != "$DEFAULT_NETWORK") && ($subnet == "$DEFAULT_CIDR") ]]
    then
      if [[ "$existing_network" == "$NOT_FOUND" ]]
      then
        panic "Subnet CIDR must be specified for custom network"
      fi
    fi

    echo

    # create network if doesn't exists
    if [[ "$existing_network" == "$NOT_FOUND" ]]
    then
      echo -e "${YELLOW}create new network ${CYAN}$network $subnet ${NC}"
      docker network create --driver=bridge --subnet="$subnet" "$network"
    else
      echo -e "${YELLOW}attaching nodes to existing ${CYAN}$network ${NC}"
      subnet=$(docker network inspect "$network" -f '{{(index .IPAM.Config 0).Subnet}}')
    fi

    if [[ "$registry" == "true" ]]
    then
      echo -e "${YELLOW}attaching registry to ${CYAN}$network ${NC}"
      registry "$network"
      registryArg="--volume \"${REGISTRY_CONFIG_PATH}:/etc/rancher/k3s/registries.yaml\""
    fi

    # Setup GitHub Actions outputs
    echo "::set-output name=k3d-network::$network"
    echo "::set-output name=k3d-cidr::$subnet"

    echo -e "${YELLOW}Downloading ${CYAN}k3d ${NC}see: ${K3D_URL}"
    curl --silent --fail ${K3D_URL} | bash

    echo -e "\existing_network${YELLOW}Deploy cluster ${CYAN}$name ${NC}"
    eval "k3d cluster create $name --wait $arguments --network $network $registryArg"
}

registry(){
    local network=$1
    # create registry if not exists
    if [ ! "$(docker ps -q -f name=${REGISTRY_LOCAL})" ];
    then
      registries
      docker volume create local_registry
      docker container run -d --name ${REGISTRY_LOCAL} -v local_registry:/var/lib/registry --restart always -p 5000:5000 registry:2
    fi
    # connect registry to network if not connected yet
    containsRegistry=$(docker network inspect "$network" | grep ${REGISTRY_LOCAL} || echo $NOT_FOUND)
    if [[ "$containsRegistry" == "$NOT_FOUND" ]]
    then
      docker network connect "$network" ${REGISTRY_LOCAL}
    fi
}

registries(){
   cat > "${REGISTRY_CONFIG_PATH}" <<EOF
mirrors:
  "registry.localhost:5000":
    endpoint:
      - "http://registry.local:5000"
EOF
}


clean(){
    if [[ -z "${K3D_NAME}" ]]; then
      panic "K3D_NAME must be set"
    fi
    local name="${K3D_NAME}"
    echo -e "\existing_network${YELLOW}Destroy cluster ${CYAN}$name ${NC}"
    eval "k3d cluster delete ${name}"
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
      *)
  usage
  exit 0
  ;;
esac

