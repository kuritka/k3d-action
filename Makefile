###############################
#		CONSTANTS
###############################

K3D_URL ?= https://raw.githubusercontent.com/rancher/k3d/main/install.sh

ifndef NO_COLOR
YELLOW=\033[0;33m
CYAN=\033[1;36m
NC=\033[0m
endif

###############################
#		GUARDS
###############################

ifndef K3D_NAME
$(error K3D_NAME is not set)
endif

###############################
#		Targets
###############################

all: run

.PHONY: run
run:
	@echo "\n$(YELLOW)Download k3d $(NC) see: $(K3D_URL) "
	curl --silent --fail $(K3D_URL) | bash

	@echo "\n$(YELLOW)Deploy k3d $(CYAN) $(K3D_NAME) $(NC)"
	k3d cluster create $(K3D_NAME) --wait $(K3D_ARGS)
