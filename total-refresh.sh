#!/usr/bin/env bash
# title:       total-refresh.sh
# 
# Description:
# This script automates the process of either creating a new PGNC environment
# or renewing an existing one. It uses submodules, containers, and a set of
# helper functions to manage the environment.
#
# The script accepts command-line arguments to control its behavior, which are
# parsed by the `parse_arguments` function.
# 
# If the `new` flag is set to true, the script initializes submodules, and
# starts the containers, effectively creating a new environment.
# 
# If the `new` flag is false (or not set), the script renews the environment by
# stopping and removing existing containers, refreshing the container code, and
# then starting the containers again.

# Function name: parse_arguments
# 
# Description:
# This function parses command-line arguments to configure the script's behavior.
# It supports options for creating a new environment, specifying the container tool, and displaying help information.
#
# Options:
#   --new: If specified, indicates that a new environment should be created.
#   --container-tool <tool>: Specifies the container tool to use (either 'docker' or 'podman'). This option is required.
#   --help: Displays a help message and exits.
#
# The function sets the global variables 'new' and 'container_tool' based on the provided arguments.
# It validates that the container tool is specified and is either 'docker' or 'podman'.
#
# Globals:
#   new: A boolean indicating whether a new environment should be created.
#   container_tool: The container tool to use (either 'docker' or 'podman').
#
# Exit codes:
#   0: Successful parsing of arguments.
#   1: An unknown parameter was passed, the container-tool was not specified, or the container-tool was invalid.
parse_arguments() {
    # Global variable
    new=false
    container_tool=""
    # Local variable
    local help=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --new)
                new=true
                shift
                ;;
            --container-tool)
                container_tool=$2
                shift
                shift
                ;;
            --help)
                help=true
                echo "Either sets up or renews the PGNC environment"
                echo ""
                echo "Usage: $(basename "$0") [--new] [--renew]"
                echo "  --new:            Clones and sets up the PGNC environment"
                echo "  --container-tool: (REQUIRED) Specify the container tool to use"
                echo "                    (Must be podman or docker)"
                exit 0
                ;;
            *)
                echo "Unknown parameter passed: $1"
                exit 1
        esac
    done
    if [[ -z "$container_tool" ]]; then
        echo "container-tool must be specified"
        exit 1
    elif [[ "$container_tool" != "docker" && "$container_tool" != "podman" ]]; then
        echo "container-tool must be either docker or podman"
        exit 1
    fi
    return 0
}

# Function name: stop_containers
#
# Description:
# Stops all running containers using docker-compose or podman-compose.
#
# This function executes the 'compose down' command using the specified container tool
# (either 'docker' or 'podman') to stop and remove all containers defined in the docker-compose.yml file.
#
# Globals:
#   container_tool: The container tool to use (e.g., docker).
#
# Exit codes:
#   0: Successfully stopped all containers.
#   1: Failed to stop containers.
stop_containers(){
    $container_tool compose down
    if [ $? -eq 0 ]; then
        echo "Successfully stopped containers"
    else
        echo "Failed to stop containers"
        exit 1
    fi
}

# Function name: remove_containers
#
# Description:
# Removes all unused Docker images, volumes, and networks.
#
# This function uses the `docker image prune`, `docker volume prune`, and `docker network prune` commands
# to remove unused resources. The `--all` flag is used to remove all unused images, and the `--force`
# flag is used to bypass any prompts.
#
# If any of the prune commands fail, the function will print an error message and exit with a status code of 1.
#
# Globals:
#   container_tool: The container tool to use (e.g., docker).
#
# Exit codes:
#   0: Successfully removed all unused containers.
#   1: Failed to remove containers.
remove_containers(){
    $container_tool image prune --all --force
    if [ $? -eq 0 ]; then
        echo "Successfully removed images"
    else
        echo "Failed to remove images"
        exit 1
    fi
    $container_tool volume prune --force
    if [ $? -eq 0 ]; then
        echo "Successfully removed volumes"
    else
        echo "Failed to remove volumes"
        exit 1
    fi
    $container_tool network prune --force
    if [ $? -eq 0 ]; then
        echo "Successfully removed networks"
    else
        echo "Failed to remove networks"
        exit 1
    fi
}

# Function name: refresh_container_code
#
# Description:
# This function executes `git pull --recurse-submodules` to update the local repository with the latest changes from the remote.
# It checks the exit status of the git command and prints a success or failure message accordingly.
# If the git pull command fails, the script will exit with a status code of 1.
#
# Exit codes:
#   0: Successfully refreshed container code.
#   1: Failed to refresh container code.
refresh_container_code(){
    git pull --recurse-submodules
    if [ $? -eq 0 ]; then
        echo "Successfully refreshed container code"
    else
        echo "Failed to refresh container code"
        exit 1
    fi
}

# Function name: start_containers
# 
# Description:
# This function uses the container tool (e.g., docker) to start the containers defined in the compose file.
# It checks the return code of the command and prints a success or failure message accordingly.
# If the containers fail to start, the script will exit with an error code of 1.
#
# Globals:
#   container_tool: The container tool to use (e.g., docker.
#
# Exit codes:
#   0: Successfully started containers.
#   1: Failed to start containers.
start_containers(){
    $container_tool compose --env-file .env up -d
    if [ $? -eq 0 ]; then
        echo "Successfully started containers"
    else
        echo "Failed to start containers"
        exit 1
    fi
}

# Function name: init_submodules
#
# Description:
# This function recursively initializes and updates all git submodules defined in the project.
# It checks the return code of the `git submodule update` command and prints a success or failure message accordingly.
# If the submodule initialization fails, the script exits with an error code of 1.
#
# Exit codes:
#   0: Successfully initialized submodules.
#   1: Failed to initialize submodules.
init_submodules(){
    git submodule update --init --recursive
    if [ $? -eq 0 ]; then
        echo "Successfully initialized submodules"
    else
        echo "Failed to initialize submodules"
        exit 1
    fi
}

# Function name: check_env_file
#
# Description:
# This function checks if the .env file exists and does not contain '<' or '>'.
# If the file does not exist or contains the specified characters, the function prints an error message and exits with a status code of 1.
#
# Exit codes:
#   0: .env file exists and does not contain '<' or '>'.
#   1: .env file does not exist or contains '<' or '>'.
check_env_file() {
    if [[ ! -f ".env" ]]; then
        echo ".env file not found"
        exit 1
    fi

    if grep -q '[<>]' ".env"; then
        echo ".env file contains '<' or '>'"
        exit 1
    fi
}

# Main - see start of file for description
check_env_file
parse_arguments "$@"
if [[ "$new" == true ]]; then
    echo "Create PGNC environment"
    init_submodules
    start_containers
else
    echo "Renew PGNC environment"
    stop_containers
    remove_containers
    refresh_container_code
    start_containers
fi
