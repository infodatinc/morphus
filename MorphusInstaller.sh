#!/bin/bash

##########################################
#          CONFIGURATION VARIABLES       #
##########################################

SERVICE_NAME="morphus"
CLI_SCRIPT="morphus"
USER_HOME=$(eval echo ~$SUDO_USER)
INSTALL_DIR="$USER_HOME/.${SERVICE_NAME}"
CLI_TARGET="/usr/local/bin/$CLI_SCRIPT"
APP_DIR="/var/$CLI_SCRIPT"
AIRFLOW_DIR="/var/airflow"
SCRIPT_NAME="Morphus.sh"
REPO="Lynette-Pinto/Advanced-File-Transfer-and-Data-Processing-System" 
ENV_FILE="$APP_DIR/.env"
GREEN='\033[0;32m'
NC='\033[0m' # No Color
CHECK_MARK="\xE2\x9C\x94"
GREEN_TICK=${GREEN}${CHECK_MARK}${NC}
INSTALL_MARKER="$APP_DIR/.morphus_installed"


# Docker Image Tags
DOCKER_HUB_REPO="infodatinc/morphus"
DOCKER_CONTAINER_NAME="morphus"
DOCKER_CONTAINER_NAME_BE="morphus-back-end"
DOCKER_CONTAINER_NAME_UI="morphus-ui"
DOCKER_CONTAINER_NAME_AF="morphus-airflow"
DOCKER_IMAGE_TAG_BE="1.0"
DOCKER_IMAGE_TAG_UI="1.1"
DOCKER_IMAGE_TAG_AIRFLOW="1.0"
AIRFLOW_IMG_NAME="apache/airflow:2.9.2"

# Database Variables
MYSQL_DB_USER="root"
MYSQL_DB_PASSWORD="password"
MYSQL_DB_NAME="morphus"
MYSQL_DB_PORT=3306
MYSQL_DB_HOSTNAME="morphus-mysql"

# Airflow Variables
AIRFLOW_DB_DIALECT="postgresql"
AIRFLOW_DB_CONNECTOR="psycopg2"
AIRFLOW_DB_USER="postgres"
AIRFLOW_DB_PASSWORD="password123"
AIRFLOW_DB_SERVER="morphus-airflow-postgres"
AIRFLOW_DB_PORT=5432
AIRFLOW_DB_NAME="postgres"
REDIS_PORT=6379
AIRFLOW_UID=5000
AIRFLOW_WEB_SECRET="your_secret_key_here"
PIP_ADDITIONAL_REQ="pandas numpy"   
AIRFLOW_USER_USERNAME="airflow"
AIRFLOW_USER_PASSWORD="airflow"
AIRFLOW_DAG_JSON_DATA_DIR="./dag_json_data"
UI_PORT=80



##########################################
#              HELPER FUNCTIONS          #
##########################################
# Function to write environment variables to the .env file
write_env_file() {
    cat <<EOF | sudo tee "$ENV_FILE" > /dev/null
SERVICE_NAME=$SERVICE_NAME
AIRFLOW_DB_DIALECT=$AIRFLOW_DB_DIALECT
AIRFLOW_DB_CONNECTOR=$AIRFLOW_DB_CONNECTOR
AIRFLOW_DB_USER=$AIRFLOW_DB_USER
AIRFLOW_DB_PASSWORD=$AIRFLOW_DB_PASSWORD
AIRFLOW_DB_SERVER=$AIRFLOW_DB_SERVER
AIRFLOW_DB_PORT=$AIRFLOW_DB_PORT
AIRFLOW_DB_NAME=$AIRFLOW_DB_NAME
AIRFLOW_IMG_NAME=$AIRFLOW_IMG_NAME
AIRFLOW_PROJ_DIR=$AIRFLOW_DIR
REDIS_PORT=$REDIS_PORT
REDIS_PASSWORD=
AIRFLOW__WEBSERVER__SECRET_KEY=$AIRFLOW_WEB_SECRET
AIRFLOW_PIP_ADDITIONAL_REQUIREMENTS="$PIP_ADDITIONAL_REQ"
AIRFLOW_UID=$AIRFLOW_UID
AIRFLOW_USER_USERNAME=$AIRFLOW_USER_USERNAME
AIRFLOW_USER_PASSWORD=$AIRFLOW_USER_PASSWORD
AIRFLOW_DAG_JSON_DATA_DIR=$AIRFLOW_DAG_JSON_DATA_DIR
MYSQL_DB_NAME=$MYSQL_DB_NAME
MYSQL_DB_HOSTNAME=$MYSQL_DB_HOSTNAME
MYSQL_DB_PORT=$MYSQL_DB_PORT
MYSQL_DB_USER=$MYSQL_DB_USER
MYSQL_DB_PASSWORD=$MYSQL_DB_PASSWORD
DOCKER_HUB_REPO_UI=$DOCKER_HUB_REPO-ui
DOCKER_HUB_REPO_BE=$DOCKER_HUB_REPO-back-end
DOCKER_HUB_REPO_AIRFLOW=$DOCKER_HUB_REPO-airflow
DOCKER_IMAGE_TAG_UI=$DOCKER_IMAGE_TAG_UI
DOCKER_IMAGE_TAG_BE=$DOCKER_IMAGE_TAG_BE
DOCKER_IMAGE_TAG_AIRFLOW=$DOCKER_IMAGE_TAG_AIRFLOW
DOCKER_CONTAINER_NAME=$DOCKER_CONTAINER_NAME
DOCKER_CONTAINER_NAME_BE=$DOCKER_CONTAINER_NAME_BE
DOCKER_CONTAINER_NAME_UI=$DOCKER_CONTAINER_NAME_UI
DOCKER_CONTAINER_NAME_AF=$DOCKER_CONTAINER_NAME_AF
UI_PORT=$UI_PORT
SPRING_PROFILES_ACTIVE=default
AIRFLOW_IMAGE_NAME=$AIRFLOW_IMG_NAME
ENABLE_MYSQL=$ENABLE_MYSQL
EOF
}

#Check OS version
check_os() {
    case "$(uname -s)" in
        Linux*) OSTYPE="linux-gnu"; echo "Linux OS detected";;
        Darwin*) OSTYPE="darwin"; echo "macOS detected";;
        *) echo "Unsupported OS"; exit 1;;
    esac
}


#Cleanup on failure
cleanup_on_failure() {
    echo "Installation failed. Cleaning up..."
    sudo rm -rf "$INSTALL_DIR" "$APP_DIR" "$AIRFLOW_DIR"
    exit 1
}


# Fetch available versions from GitHub
fetch_latest_release_info() {
    # Fetch full releases list and filter stable ones
    local release=$(curl -s "https://api.github.com/repos/$REPO/releases" \
        | jq -r 'map(select(.prerelease == false)) | sort_by(.tag_name) | last')

    # Validate release
    if [[ -z "$release" || "$release" == "null" ]]; then
        echo " Failed to fetch latest stable release info from GitHub."
        cleanup_on_failure
        exit 1
    fi

    # Extract asset URL
    local url=$(echo "$release" | jq -r '.assets[] | select(.name=="version-mapping.json") | .browser_download_url')
    if [[ -z "$url" ]]; then
        echo "version-mapping.json not found in latest release."
        cleanup_on_failure
        exit 1
    fi

    # Extract version and component tags
    VERSION_CHOICE=$(echo "$release" | jq -r '.tag_name')
    DOCKER_IMAGE_TAG_UI=$(curl -sSL "$url" | jq -r '.ui')
    DOCKER_IMAGE_TAG_BE=$(curl -sSL "$url" | jq -r '.backend')
    DOCKER_IMAGE_TAG_AIRFLOW=$(curl -sSL "$url" | jq -r '.airflow')

    # Update .env file
    {
        echo "VERSION=$VERSION_CHOICE"
        echo "DOCKER_IMAGE_TAG_UI=$DOCKER_IMAGE_TAG_UI"
        echo "DOCKER_IMAGE_TAG_BE=$DOCKER_IMAGE_TAG_BE"
        echo "DOCKER_IMAGE_TAG_AIRFLOW=$DOCKER_IMAGE_TAG_AIRFLOW"
    } | sudo tee -a "$ENV_FILE" > /dev/null
}


prompt_db_details() {
    read -rp "Database Hostname: " MYSQL_DB_HOSTNAME
    read -rp "Database Port: " MYSQL_DB_PORT
    read -rp "Database Username: " MYSQL_DB_USER
    read -rsp "Database Password: " MYSQL_DB_PASSWORD; echo
}


# Ensure Docker is running
ensure_docker_running() {
    attempt=0
    while ! sudo docker info &>/dev/null; do
        ((attempt++))
        echo "Docker not running. Attempt $attempt to start docker..."
        if [[ "$OSTYPE" == "linux-gnu" ]]; then
            sudo systemctl start docker
        else
            open --background -a Docker
        fi
        sleep 10
        ((attempt == 3)) && { echo "Docker daemon could not be started"; exit 1; }
    done
}


##########################################
#                 MAIN                   #
##########################################
echo ""
echo "Installing Morphus"
echo "Checking prerequisites..."
echo ""
check_os
echo ""


# Check for existing installation
if [ -f "$INSTALL_MARKER" ]; then
    echo "Detected existing installation: Morphus is already installed at $INSTALL_DIR"
    exit 1
fi

# Check if Docker is installed
echo "Checking for Docker..."
if ! command -v docker &>/dev/null; then
    echo "Docker is not installed. Install it from https://docs.docker.com/get-docker/ and rerun this script."
    exit 1
fi

printf "${GREEN_TICK} Docker is available\n"


ensure_docker_running
echo ""
#Check for UI port 
read -rp "Enter port to use for UI (Default 80): " UI_PORT
UI_PORT=${UI_PORT:-80}

while lsof -i TCP:"$UI_PORT" -sTCP:LISTEN >/dev/null 2>&1; do
    echo "Port $UI_PORT is in use"
    read -rp "Enter a different port for UI (Default 80): " new_port
    UI_PORT=${new_port:-80}
done


printf "${GREEN_TICK} Port $UI_PORT is available\n"


# Create installation and logs directories
mkdir -p "$INSTALL_DIR"
sudo mkdir -p \
  "$APP_DIR/logs/ui" \
  "$APP_DIR/logs/backend/api-gateway" \
  "$APP_DIR/logs/backend/auth" \
  "$APP_DIR/logs/backend/user-access-management" \
  "$APP_DIR/logs/backend/metadata" \
  "$APP_DIR/logs/backend/email-notification" \
  "$APP_DIR/database/mysql"
sudo chmod -R 777 "$APP_DIR"

# Create Airflow directories
sudo mkdir -p \
  "$AIRFLOW_DIR/dags" \
  "$AIRFLOW_DIR/logs" \
  "$AIRFLOW_DIR/config" \
  "$AIRFLOW_DIR/plugins" \
  "$AIRFLOW_DIR/test" \
  "$AIRFLOW_DIR/scripts" \
  "$AIRFLOW_DIR/api" \
  "$AIRFLOW_DIR/dag_json_data"
sudo chmod -R 777 "$AIRFLOW_DIR"

# Initialize env file
sudo sh -c "> \"$ENV_FILE\""


# Collect Version Info
fetch_latest_release_info
VERSION_FILE="$APP_DIR/.ver"


if [ ! -f "$VERSION_FILE" ]; then
    sudo tee "$VERSION_FILE" >/dev/null <<EOF
CURRENT_VERSION=$VERSION_CHOICE
PREVIOUS_VERSION=
EOF
elif ! grep -q "CURRENT_VERSION=" "$VERSION_FILE"; then
    echo "CURRENT_VERSION=$VERSION_CHOICE" | sudo tee -a "$VERSION_FILE" > /dev/null
fi

DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/$REPO/main/docker-compose.yaml"
TARGET_FILE="$APP_DIR/docker-compose.yaml"

echo "Downloading and setting up the required files..."
if ! curl -fsSL "$DOCKER_COMPOSE_URL" -o "$TARGET_FILE"; then
    echo "Failed to download required files. Please check the network connection."
    cleanup_on_failure
    exit 1
fi

# Collect database configuration for Airflow Setup

echo "1. Create New MySQL Database"
echo "2. Use Existing MySQL Database"
echo "Please choose one of the option:"
read -r db_option

MAX_RETRIES=3
for attempt in $(seq 1 $MAX_RETRIES); do
    if [[ "$db_option" == "1" ]]; then
        echo
        echo "New databases will be created with:"
        echo "Host: $MYSQL_DB_HOSTNAME  Port: $MYSQL_DB_PORT"
        echo "User: $MYSQL_DB_USER"
        echo "Password can be changed later."
        echo ""
        ENABLE_MYSQL=true
        write_env_file
        break

    elif [[ "$db_option" == "2" ]]; then
        echo
        prompt_db_details
        echo "Attempt $attempt/$MAX_RETRIES: Checking database connection..."
       if mysql -h"$MYSQL_DB_HOSTNAME" -P"$MYSQL_DB_PORT" -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" \
        -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB_NAME\`;" 2>/dev/null; then

            echo "Connection successful to database host."
            ENABLE_MYSQL=false
            write_env_file
            break
        else
            echo "Connection failed. Retrying..."
            if [[ $attempt -eq $MAX_RETRIES ]]; then
                echo "Failed to connect after $MAX_RETRIES attempts."
                cleanup_on_failure
                exit 1
            fi
        fi

    else
        echo "Invalid choice. Select 1 or 2."
        read -r db_option
    fi
done

#Validating docker-compose file
if ! output=$(docker compose -f "$APP_DIR/docker-compose.yaml" config 2>&1); then
    errors=$(echo "$output" | grep -v '^\[WARN\]')
    if [[ -n "$errors" ]]; then
        echo "Docker Compose configuration errors detected:"
        echo "$errors"
        cleanup_on_failure
        exit 1
    fi
else
    echo "Docker Compose config is valid."
fi


echo "Installing CLI command: morphus"
cat <<'EOF' | sudo tee "$CLI_TARGET" > /dev/null
#!/bin/bash

SERVICE_NAME="morphus"
CLI_SCRIPT="morphus"
USER_HOME=$(eval echo ~$SUDO_USER)
INSTALL_DIR="$USER_HOME/.${SERVICE_NAME}"
APP_DIR="/var/$CLI_SCRIPT"
REPO="Lynette-Pinto/Advanced-File-Transfer-and-Data-Processing-System"
ENV_FILE="$APP_DIR/.env"
ORG_MARKER="$APP_DIR/.org_created"
USER_MARKER="$APP_DIR/.user_created"
BACKUP_BASE="/var/morphus_backup"
VERSION_FILE="$APP_DIR/.ver"
TARGET_FILE="$APP_DIR/docker-compose.yaml"
AIRFLOW_DIR="/var/airflow"
BASE_URL="http://${SERVICE_NAME}-back-end"

check_service_status(){

services=(
    "${BASE_URL}-metadata:8084/metadata/actuator/health"
    "${BASE_URL}-user-access-management:8085/actuator/health"
    "${BASE_URL}-email-notification:8082/emailnotification/actuator/health"
    "${BASE_URL}-auth:8081/actuator/health"
    "${BASE_URL}-api-gateway:8083/actuator/health"
)
UI_CONTAINER="morphus-ui"

echo "Checking backend service status..."

service_max_attempts=60
service_attempt=1

while true; do
all_up=true
for url in "${services[@]}"; do
response=$(docker exec "$UI_CONTAINER" curl -s "$url")
status=$(echo "$response" | jq -r '.status' 2>/dev/null)

if [[ "$status" != "UP" ]]; then
all_up=false
break
fi
done

if $all_up; then
echo "All services are UP"
break
fi

if (( service_attempt >= service_max_attempts )); then
echo "ERROR: Not all services became healthy in time."
exit 1
fi

((service_attempt++))
sleep 5
done

}
[[ -f "$ENV_FILE" ]] || { echo "ERROR: Environment file $ENV_FILE not found"; exit 1; }
set -a; source "$ENV_FILE"; set +a

# Detect OS
case "$(uname -s)" in
    Linux*)  OSTYPE="linux-gnu" ;;
    Darwin*) OSTYPE="darwin" ;;
    *) echo "Unsupported OS. Supported: Linux, macOS." && exit 1 ;;
esac

#Sed command for OS Compatibility 
sed_replace() {
  local pattern=$1
  local file=$2
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$pattern" "$file"
  else
    sed -i "$pattern" "$file"
  fi
}


case "$1" in

################################
##### Version Information #####
################################
version)
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(sudo awk -F'=' '/CURRENT_VERSION/{print $2}' "$VERSION_FILE")
    echo "Morphus Version: ${CURRENT_VERSION:-Not Set}"
else
    echo "Version file not found. No version information available."
fi
;;


################################
####### Start Containers #######
################################

start)
echo "Starting Morphus..."
cd "$APP_DIR" || exit 1

if [ "$ENABLE_MYSQL" = true ]; then
    docker compose --profile with-mysql up -d mysql liquibase 2>/dev/null
else
    docker compose up -d liquibase 2>/dev/null
fi

echo " Waiting for Liquibase to finish..."
if [ "$ENABLE_MYSQL" = true ]; then
    docker wait morphus-liquibase
else
    docker compose ps -q liquibase | xargs docker wait
fi

echo "Starting Morphus services..."
if ! docker compose up -d \
    api-gateway auth user-access-management metadata email-notification \
    redis postgres \
    airflow-init airflow-webserver airflow-scheduler airflow-worker airflow-triggerer \
    web morphus-ui-angular; then
    echo "Failed to start Morphus."
    exit 1
fi


if [ ! -f "$ORG_MARKER" ]; then
echo "Checking if organization '$org_name' exists..."
echo -e "\nFirst time start detected. Creating organization in the database..."

if [[ "$ENABLE_MYSQL" == "true" ]]; then
for i in {1..30}; do
if docker exec morphus-mysql mysqladmin ping -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" --silent 2>/dev/null; then
    break
else
    sleep 2
fi
if [ "$i" -eq 30 ]; then
    echo "MySQL did not become ready in time."
    exit 1
fi
done
fi

while true; do
read -rp "Enter your organization name (domain name): " org_name
read -rp "Confirm organization name is '$org_name'? (y/n): " confirm_org_name
[[ "$confirm_org_name" == "y" ]] && break
echo "Please re-enter the details."
done
org_exists_query="SELECT COUNT(*) FROM morphus.organizations WHERE name='$org_name';"
if [[ "$ENABLE_MYSQL" == "true" ]]; then
org_exists=$(docker exec "$MYSQL_DB_HOSTNAME" mysql -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" -N -e "$org_exists_query" 2>/dev/null)
else
org_exists=$(mysql -h"$MYSQL_DB_HOSTNAME" -P"$MYSQL_DB_PORT" -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" -N -e "$org_exists_query" 2>/dev/null)
fi

if [[ "$org_exists" -eq 0 ]]; then
echo "Registering organization in the database..."
register_org_query="INSERT INTO morphus.organizations (id, name, active) VALUES ('$org_name', '$org_name', b'1');"

if [[ "$ENABLE_MYSQL" == "true" ]]; then
docker exec "$MYSQL_DB_HOSTNAME" mysql -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" -e "$register_org_query" 2>/dev/null
else
mysql -h"$MYSQL_DB_HOSTNAME" -P"$MYSQL_DB_PORT" -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" -e "$register_org_query" 2>/dev/null
fi
if [[ $? -eq 0 ]]; then
echo "Organization registered successfully."
echo "$org_name" | sudo tee "$ORG_MARKER" >/dev/null
else
echo "Failed to register organization '$org_name'. Please check your database connection details."
exit 1
fi
else
echo "Organization '$org_name' already exists. Skipping registration."
fi
else
echo "Organization already created. Skipping organization creation."
org_name=$(cat "$ORG_MARKER")
fi
if [[ ! -f "$USER_MARKER" ]]; then
echo "Please enter the below details for the admin"
read -rp "First Name: " first_name
read -rp "Last Name: " last_name
org_name_clean=$(echo "$org_name" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
while true; do
read -rp "Company Email Address: " email_address
email_domain=$(echo "$email_address" | awk -F'@' '{print $2}' | awk -F'.' '{print $1}' | tr '[:upper:]' '[:lower:]')
if [[ "$email_domain" == "$org_name_clean" ]]; then
break
else
echo "Warning: Email domain ($email_domain) does not match organization name ($org_name_clean)."
echo "Please try again."
fi
done
echo "Registering admin user in the database.."
register_user_query="INSERT INTO morphus.users (id, first_name, last_name, username, email, organization_id, password, active, deleted, is_new_user, is_owner) VALUES ('demo-id-1', '$first_name', '$last_name', '$email_address', '$email_address', '$org_name', '\$2a\$12\$GTDgS7SlX1j6v8cC6q/o7uUAZqhrNb1i5wKKXDFCkTEwJTTZscoTu', b'1', b'0', b'1', b'1');"

if [ "$ENABLE_MYSQL" = "true" ]; then
  echo "Registering user using Docker MySQL container..."

  if docker exec "${MYSQL_DB_HOSTNAME}" mysql -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" -e "$register_user_query" 2>/dev/null; then
    echo "Admin user '$email_address' registered successfully with default password 'Welcome@123'."
    echo "You can reset the password from the UI using the 'Forgot password' option."
    echo "$email_address" | sudo tee "$USER_MARKER" >/dev/null
  else
    echo " Failed to register user '$email_address' using Docker container. Check DB connection and permissions."
    exit 1
  fi

else
  echo "Registering user using native MySQL..."

  if mysql -h"$MYSQL_DB_HOSTNAME" -P"$MYSQL_DB_PORT" -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" -e "$register_user_query" 2>/dev/null; then
    echo "Admin user '$email_address' registered successfully with default password 'Welcome@123'."
    echo "You can reset the password from the UI using the 'Forgot password' option."
    echo "$email_address" | sudo tee "$USER_MARKER" >/dev/null
  else
    echo " Failed to register user '$email_address' using native MySQL. Check DB connection and permissions."
    exit 1
  fi
fi

else
echo "Admin User exists. Skipping user creation."
fi
check_service_status
echo "Morphus started and running on port ${UI_PORT}"
;;

################################
####### Stop Containers #######
################################
stop)
echo "Stopping Morphus..."
cd "$APP_DIR" || exit 1
if docker compose down >/dev/null 2>&1; then
    echo "Morphus stopped successfully."
else
    echo "Failed to stop Morphus"
    exit 1
fi
;;

################################
###### Update Containers #######
################################
update)

sudo touch "$ENV_FILE"

if [ ! -f "$ORG_MARKER" ] || [ ! -f "$USER_MARKER" ]; then
    echo "Morphus is not installed or not initialized. Please run 'morphus start' first to initialize the application."
    exit 1
fi

# --- Get current installed version ---
CURRENT_VERSION=$(sudo awk -F'=' '/CURRENT_VERSION/{print $2}' "$VERSION_FILE" 2>/dev/null)
[[ -z "$CURRENT_VERSION" ]] && echo "No version file found (.ver). Assuming fresh install."

# --- Fetch latest release info ---
echo "Fetching latest release info..."

release=$(curl -s "https://api.github.com/repos/$REPO/releases" \
  | jq -r 'map(select(.prerelease == false)) | sort_by(.tag_name) | last')

asset_url=$(echo "$release" \
  | jq -r '.assets[] | select(.name=="version-mapping.json") | .browser_download_url')

LATEST_VERSION=$(echo "$release" | jq -r '.tag_name')
DOCKER_IMAGE_TAG_UI=$(curl -sSL "$asset_url" | jq -r '.ui')
DOCKER_IMAGE_TAG_BE=$(curl -sSL "$asset_url" | jq -r '.backend')
DOCKER_IMAGE_TAG_AIRFLOW=$(curl -sSL "$asset_url" | jq -r '.airflow')

# --- Check if up-to-date ---
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    printf "${GREEN_TICK} Morphus is up-to-date."
    exit 0
fi


echo "Updating to $LATEST_VERSION..."
BACKUP_DIR="$BACKUP_BASE/$CURRENT_VERSION"
sudo mkdir -p "$BACKUP_DIR"

# Backup MySQL DB
sudo sh -c "docker exec $MYSQL_DB_HOSTNAME mysqldump -u "MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" $MYSQL_DB_NAME > '$BACKUP_DIR/morphus_db.sql'" 2>/dev/null

# --- Stop containers ---
echo "Stopping Morphus..."
cd "$APP_DIR" || exit 1
if ! docker compose down >/dev/null 2>&1; then
    echo "Failed to stop Morphus."
    exit 1
fi

# --- Backup current version ---
BACKUP_DIR="$BACKUP_BASE/$CURRENT_VERSION"
sudo mkdir -p "$BACKUP_BASE"
sudo rm -rf "$BACKUP_DIR"
sudo mkdir -p "$BACKUP_DIR"

TAR_EXTRA_OPTS=""
if [[ "$(uname)" == "Darwin" ]]; then
    TAR_EXTRA_OPTS="--no-xattrs --no-mac-metadata"
else
    TAR_EXTRA_OPTS="--no-xattrs"
fi

sudo tar -czpf "$BACKUP_BASE/$CURRENT_VERSION/morphus.tar.gz" \
    $TAR_EXTRA_OPTS -C /var morphus

sudo tar -czpf "$BACKUP_BASE/$CURRENT_VERSION/airflow.tar.gz" \
    $TAR_EXTRA_OPTS -C /var airflow


# --- Update .env file ---
sed_replace "s/^VERSION=.*/VERSION=$LATEST_VERSION/" "$ENV_FILE" || echo "VERSION=$LATEST_VERSION" | sudo tee -a "$ENV_FILE" > /dev/null
sed_replace "s/^DOCKER_IMAGE_TAG_UI=.*/DOCKER_IMAGE_TAG_UI=$DOCKER_IMAGE_TAG_UI/" "$ENV_FILE" || echo "DOCKER_IMAGE_TAG_UI=$DOCKER_IMAGE_TAG_UI" | sudo tee -a "$ENV_FILE" > /dev/null
sed_replace "s/^DOCKER_IMAGE_TAG_BE=.*/DOCKER_IMAGE_TAG_BE=$DOCKER_IMAGE_TAG_BE/" "$ENV_FILE" || echo "DOCKER_IMAGE_TAG_BE=$DOCKER_IMAGE_TAG_BE" | sudo tee -a "$ENV_FILE" > /dev/null
sed_replace "s/^DOCKER_IMAGE_TAG_AIRFLOW=.*/DOCKER_IMAGE_TAG_AIRFLOW=$DOCKER_IMAGE_TAG_AIRFLOW/" "$ENV_FILE" || echo "DOCKER_IMAGE_TAG_AIRFLOW=$DOCKER_IMAGE_TAG_AIRFLOW" | sudo tee -a "$ENV_FILE" > /dev/null

set -a; source "$ENV_FILE"; set +a

# --- Update version tracking file ---
sudo tee "$VERSION_FILE" > /dev/null <<EOL
PREVIOUS_VERSION=$CURRENT_VERSION
CURRENT_VERSION=$LATEST_VERSION
EOL

# --- Download updated docker-compose ---
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/$REPO/main/docker-compose.yaml"
echo "Downloading updates..."
if ! curl -fsSL "$DOCKER_COMPOSE_URL" -o "$TARGET_FILE"; then
    echo "Failed to download updates. Please check the network connection."
    exit 1
fi

# --- Validate docker-compose config ---
echo " Validating the latest update..."
if ! output=$(docker compose -f "$APP_DIR/docker-compose.yaml" config 2>&1); then
    errors=$(echo "$output" | grep -v '^\[WARN\]' || true)
    if [[ -n "$errors" ]]; then
        echo "Morphus configuration errors:"
        echo "$errors"
        exit 1
    fi
fi
# --- Restart containers ---
echo "Starting Morphus..."
cd "$APP_DIR" || exit 1
if [ "$ENABLE_MYSQL" = true ]; then
    if docker compose --profile with-mysql up -d mysql liquibase 2>/dev/null; then
        :
    else
        echo "Failed to start Morphus"
        exit 1
    fi
else
    if docker compose up -d liquibase 2>/dev/null; then
        echo "Liquibase started successfully"
    else
        echo "Failed to start Morphus"
        exit 1
    fi
fi
docker wait morphus-liquibase >/dev/null 2>&1
if docker compose up -d \
    api-gateway auth user-access-management metadata email-notification \
    redis postgres \
    airflow-init airflow-webserver airflow-scheduler airflow-worker airflow-triggerer \
    web morphus-ui-angular >/dev/null 2>&1; then
    echo "Update completed. Morphus $LATEST_VERSION is up and running."
    check_service_status
else
    echo "Failed to start Morphus"
    exit 1
fi

;;



################################
##### Rollback Containers ######
################################



rollback)

sudo touch "$ENV_FILE"
if [ ! -f "$ORG_MARKER" ] || [ ! -f "$USER_MARKER" ]; then
echo "Morphus is not installed or not initialized. Please run 'morphus start' first to initialize the application."
exit 1
fi


echo "Starting rollback..."
if [ ! -f "$VERSION_FILE" ]; then
echo "No version file found. Cannot determine backup."
exit 1
fi

PREVIOUS_VERSION=$(sudo awk -F'=' '/PREVIOUS_VERSION/{print $2}' "$VERSION_FILE")
if [ -z "$PREVIOUS_VERSION" ]; then
echo "No previous version found."
exit 1
fi

BACKUP_PATH="$BACKUP_BASE/$PREVIOUS_VERSION"
if [ ! -d "$BACKUP_PATH" ]; then
echo "No backup found for $PREVIOUS_VERSION"
exit 1
fi

echo "Rolling back to $PREVIOUS_VERSION"

# Stop containers
cd "$APP_DIR" || exit 1
docker compose down >/dev/null 2>&1 || { echo "Failed to stop Morphus."; exit 1; }

# Remove current directories
sudo rm -rf /var/morphus /var/airflow

# Restore Morphus and Airflow (no leading '/' warnings)
sudo tar -xzpf "$BACKUP_BASE/$PREVIOUS_VERSION/morphus.tar.gz" -C /var
sudo tar -xzpf "$BACKUP_BASE/$PREVIOUS_VERSION/airflow.tar.gz" -C /var

sudo chmod -R 777 /var/morphus /var/airflow

# Restore permissions
sudo chmod -R 777 /var/morphus /var/airflow

set -a; source "$ENV_FILE"; set +a


BACKUP_DIR="$BACKUP_BASE/$CURRENT_VERSION"
# Restart containers
echo "Restarting Morphus..."
cd "$APP_DIR" || exit 1
if [ "$ENABLE_MYSQL" = true ]; then
    if docker compose --profile with-mysql up -d mysql liquibase 2>/dev/null; then
        :
    else
        echo "Failed to start Morphus"
        exit 1
    fi
else
    if docker compose up -d liquibase 2>/dev/null; then
        echo "Liquibase started successfully"
    else
        echo "Failed to start Morphus"
        exit 1
    fi
fi
docker wait morphus-liquibase >/dev/null 2>&1
if docker compose up -d \
api-gateway auth user-access-management metadata email-notification \
redis postgres \
airflow-init airflow-webserver airflow-scheduler airflow-worker airflow-triggerer \
web morphus-ui-angular >/dev/null 2>&1; then
check_service_status
sudo docker exec $MYSQL_DB_HOSTNAME mysqldump -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" $MYSQL_DB_NAME | sudo tee "$BACKUP_DIR/morphus_db.sql" >/dev/null 2>&1
echo "Rollback completed. Morphus $PREVIOUS_VERSION is up and running"
else
echo "Rollback failed."
exit 1
fi
;;

################################
##### Uninstall Containers #####
################################

uninstall)
echo "Uninstalling $SERVICE_NAME..."
echo "Stopping and Removing Morphus."

# Stop containers (no exit if cd fails)
if [ -d "$APP_DIR" ]; then
    (cd "$APP_DIR" && docker compose down >/dev/null 2>&1 || true)
fi




docker ps -a --format "{{.Names}}" | grep '^morphus-' | xargs -r docker stop >/dev/null 2>&1
docker ps -a --format "{{.Names}}" | grep '^morphus-' | xargs -r docker rm >/dev/null 2>&1

# Remove volumes, networks, images
docker volume rm $(docker volume ls -q | grep "^morphus") >/dev/null 2>&1
docker network ls --format "{{.Name}}" | grep '^morphus' | xargs -r docker network rm >/dev/null 2>&1
docker system prune -af --volumes >/dev/null 2>&1
docker rmi $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E '^(morphus-|mysql|redis|postgres|apache/airflow)') >/dev/null 2>&1 || true

# Remove directories
sudo chown -R $(whoami):$(whoami) "$APP_DIR" "$INSTALL_DIR" "$AIRFLOW_DIR" 2>/dev/null || true
sudo rm -rf "$APP_DIR" "$INSTALL_DIR" "$AIRFLOW_DIR" "$BACKUP_BASE" /usr/local/bin/morphus || true

if [[ "$ENABLE_MYSQL" != "true" ]]; then
mysql -h"$MYSQL_DB_HOSTNAME" -P"$MYSQL_DB_PORT" -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" \
    -e "DROP DATABASE IF EXISTS \`$MYSQL_DB_NAME\`;" 2>/dev/null && echo "Database dropped."
LOCAL_MYSQL_DATA_DIR="/var/lib/mysql/$MYSQL_DB_NAME"
sudo rm -rf "$LOCAL_MYSQL_DATA_DIR"
fi
echo "$SERVICE_NAME has been uninstalled."
;;


#################################z
###  Show Usage Information #####
#################################

help|*)
echo "Usage: morphus {version|start|stop|update|rollback|uninstall}"
exit 1
;;
esac
EOF
 
sudo chmod +x "$CLI_TARGET"
echo "$SERVICE_NAME installed successfully."
echo "'$SERVICE_NAME' command is now available globally."


cat <<EOF 

Usage:          morphus {version|start|stop|update|rollback|uninstall}

Commands:
    version     Show the current version of the application
    start       Start the docker containers
    stop        Stop the docker containers
    update      Update docker containers to other versions 
    rollback    Rollback to the previous version of the application
    uninstall   Stop and remove the service and associated files

EOF
touch "$INSTALL_MARKER"
