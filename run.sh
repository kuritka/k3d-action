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
DEFAULT_SUBNET=172.16.0.0/24
NOT_FOUND=k3d-not-found-network
REGISTRY_LOCAL=registry.local
DEFAULT_REGISTRY_CONFIG_PATH="$(pwd)/registries.yaml"

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

  Environment variables:
      deploy
                        K3D_NAME (Required) k3d cluster name.

                        K3D_ARGS (Optional) k3d arguments.

                        K3D_NETWORK (Optional) If not set than default k3d-action-bridge-network is created
                                               and all clusters share that network.

                        K3D_SUBNET (Optional) If not set than default 172.16.0.0/24 is used. Variable requires
                                              K3D_NETWORK to be set.

                        K3D_REGISTRY (Optional) If not set than default false. If true provides local docker registry
                                              registry.localhost:5000 without TLS and authentication.

                        K3D_REGISTRY_CONFIG_PATH (Optional) Path to custom registry configuration file.
                                              see: https://rancher.com/docs/k3s/latest/en/installation/private-registry/#mirrors
                                              Variable requires K3D_REGISTRY to be true.


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
    local subnet=${K3D_SUBNET:-$DEFAULT_SUBNET}
    local registry=${K3D_REGISTRY:-$NOT_FOUND}
    local registry_path=${$(pwd)K3D_REGISTRY_CONFIG_PATH:-DEFAULT_REGISTRY_CONFIG_PATH}
    local registryArg

    echo registry_path
    existing_network=$(docker network list | awk '   {print $2 }' | grep -w "^$network$" || echo $NOT_FOUND)

    if [[ ($network == "$DEFAULT_NETWORK") && ($subnet != "$DEFAULT_SUBNET") ]]
    then
      panic "You can't specify custom subnet for default network."
    fi

    if [[ ($network != "$DEFAULT_NETWORK") && ($subnet == "$DEFAULT_SUBNET") ]]
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
      registry "$network" "$registry_path"
      registryArg="--volume \"$registry_path:/etc/rancher/k3s/registries.yaml\""
    fi

    # Setup GitHub Actions outputs
    echo "::set-output name=k3d-network::$network"
    echo "::set-output name=k3d-subnet::$subnet"
    echo "::set-output name=k3d-registry-config-path::$registry_path"

    echo -e "${YELLOW}Downloading ${CYAN}k3d ${NC}see: ${K3D_URL}"
    curl --silent --fail ${K3D_URL} | bash

    echo -e "\existing_network${YELLOW}Deploy cluster ${CYAN}$name ${NC}"
    eval "k3d cluster create $name --wait $arguments --network $network $registryArg"
}

registry(){
    local network=$1
    local registry_path=$2
    # create registry if not exists
    if [ ! "$(docker ps -q -f name=${REGISTRY_LOCAL})" ];
    then
      # no custom path is provided
      if [ "$registry_path" == "${DEFAULT_REGISTRY_CONFIG_PATH}" ]
      then
        inject_configuration
      fi
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

# see: https://rancher.com/docs/k3s/latest/en/installation/private-registry/#mirrors
inject_configuration(){
   cat > "${DEFAULT_REGISTRY_CONFIG_PATH}" <<EOF
mirrors:
  "registry.localhost:5000":
    endpoint:
      - "http://registry.local:5000"
EOF
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
#    "<put new command here>")
#       command_handler
#    ;;
      *)
  usage
  exit 0
  ;;
esac
