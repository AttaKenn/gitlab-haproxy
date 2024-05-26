#!/bin/bash

# Function to prompt user with options
prompt_user() {
  echo "$1"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) return 0;;
      No ) return 1;;
    esac
  done
}

# Check Docker version
echo "Checking Docker version..."
if command -v docker &> /dev/null; then
  docker_version=$(docker --version | awk -F '[ ,.]' '{print $3}')
  if (( docker_version >= 25 )); then
    echo "Docker version 25 or later is installed."
  else
    echo "Docker version is less than 25."
  fi
else
  echo "Docker is not installed."
  docker_version=0
fi

# Check Docker Compose version
echo "Checking Docker Compose version..."
if command -v docker-compose &> /dev/null; then
  compose_version=$(docker-compose --version | awk -F '[ ,.]' '{print $4}')
  if (( compose_version == V2 )); then
    echo "Docker Compose version 2 is installed."
  else
    echo "Docker Compose version is not version 2."
  fi
else
  echo "Docker Compose is not installed."
  compose_version=0
fi

# Prompt user for action if versions are not sufficient
if (( docker_version < 25 || compose_version != V2 )); then
  echo "Docker or Docker Compose versions are not sufficient."
  echo "Choose an option:"
  select opt in "Install newer versions" "Move on with current versions" "Abort program"; do
    case $opt in
      "Install newer versions" )
        echo "Installing the newest stable versions of Docker and Docker Compose..."
        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')" /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        break;;
      "Move on with current versions" )
        echo "Proceeding with current versions..."
        break;;
      "Abort program" )
        echo "Aborting the program."
        exit 1;;
    esac
  done
fi

# Check/Create GitLab-HAProxy directory
GITLAB_HAPROXY_DIR=~/GitLab-HAProxy
if [ -d "$GITLAB_HAPROXY_DIR" ]; then
  echo "GitLab-HAProxy already exists."
else
  mkdir "$GITLAB_HAPROXY_DIR"
  echo "Created GitLab-HAProxy directory."
fi

# Check for docker-compose.yml
cd "$GITLAB_HAPROXY_DIR"
echo "Checking to see if docker-compose.yml is in GitLab-HAProxy..."
if [ -f "docker-compose.yml" ]; then
  echo "docker-compose.yml exists."
  if prompt_user "Would you like to proceed by creating a new directory called GitLab-HAProxy[n]?"; then
    n=1
    while [ -d "${GITLAB_HAPROXY_DIR}${n}" ]; do
      n=$(( n + 1 ))
    done
    GITLAB_HAPROXY_DIR="${GITLAB_HAPROXY_DIR}${n}"
    mkdir "$GITLAB_HAPROXY_DIR"
    echo "Created directory ${GITLAB_HAPROXY_DIR}."
  else
    echo "Aborting the program."
    exit 1
  fi
fi

# Download docker-compose.yml
cd "$GITLAB_HAPROXY_DIR"
echo "Downloading docker-compose.yml..."
curl -o docker-compose.yml https://raw.githubusercontent.com/AttaKenn/gitlab-haproxy/main/docker-compose.yml

# Create haproxy directory and download haproxy.cfg
mkdir -p haproxy
echo "Downloading haproxy.cfg..."
curl -o haproxy/haproxy.cfg https://raw.githubusercontent.com/AttaKenn/gitlab-haproxy/main/haproxy/haproxy.cfg

# Prompt to start containers
if prompt_user "Would you like to start the containers?"; then
  echo "Starting the containers..."
  docker-compose up -d

  # Wait for GitLab container to be fully up and running
  echo "Waiting for GitLab container to initialize..."
  sleep 60 

  # Retrieve the initial password from the GitLab container
  echo "Retrieving the initial GitLab password..."
  gitlab_password=$(docker exec $(docker ps -q -f "name=gitlab") grep 'Password:' /etc/gitlab/initial_root_password | awk '{print $2}')

  # Save the password to a text file
  echo "Saving the initial GitLab password to initial_password.txt..."
  echo "Initial GitLab Password: $gitlab_password" > initial_password.txt

  echo "Initial GitLab password has been saved to initial_password.txt"
else
  echo "Containers not started."
fi
