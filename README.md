# DataMorph


**DataMorph** is a secure, scalable application designed to automate and manage data transfers between various sources and destinations using configurable pipelines. The `MorphusInstaller.sh`  simplifies deployment and management of DataMorph application using Docker and Docker Compose. It offers guided setup and CLI-based lifecycle control.

---

##  Tech Stack

- **Frontend:** Angular
- **Backend:** Java-Springboot
- **Workflow Orchestration:** Apache Airflow
- **Databases:** PostgreSQL
- **Containerization:** Docker + Docker Compose

---

##  Prerequisites

- **Operating System:** Linux
- **RAM:** 8 GB
- **Storage:** 30 GB

### Required Tools

| Tool              | Install Commands (macOs)                                                              | Confirm Installation     |
|-------------------|---------------------------------------------------------------------------------------|--------------------------|
| Docker            | Download & install from Docker website:https://www.docker.com/products/docker-desktop | `docker --version`       |
| Docker Compose V2 | (Included automatically with Docker Desktop on macOS — no install needed)             | `docker compose version` |
| jq                | `brew install jq`                                                                     | `jq --version`           |
| postgressql       | `brew install libpq` <br/> `brew link --force libpq`                                  | `psql --version`         |

---

| Tool              | Install Commands (Ubuntu/Debian)                                    | Confirm Installation         |
|-------------------|---------------------------------------------------------------------|------------------------------|
| Docker            | `sudo apt install docker.io`                                        | `docker --version`           |
| Docker Compose V2 | `sudo apt install docker-compose-plugin`                            | `docker compose version`     |
| lsof              | `sudo apt install lsof`                                             |                              |
| jq                | `sudo apt install jq`                                               |                              |
| postgressql       | `sudo apt-get install postgresql-client -y`                         |                              |

**Note:** Script execution may prompt for password to run certain commands with `sudo` privileges when necessary.

---

##  Installation

### 1. Clone the repository
Now, let’s download the script that will install DataMorph for you. In your terminal, run:
```bash
curl -o MorphusInstaller.sh https://raw.githubusercontent.com/infodatinc/morphus/compose_updates/MorphusInstaller.sh
```
This saves the installer script as MorphusInstaller.sh.

Next, make the script “executable” (so you can run it like a program):
```bash
chmod +x MorphusInstaller.sh 
```


### 2. Run the Installer

On macOS run:
```bash
sh MorphusInstaller.sh
```

On Linux run:
```bash
./MorphusInstaller.sh
```
During installation, the script will ask you a few questions:
- Check Docker → It will confirm Docker is available.
- Pick a Port for the Web UI → Default is 80 (just press Enter if you’re not sure).
- Database Setup →
    - If you don’t already have a Postgres database, let the installer set up a new one.
    - If you already have a Postgres database, you’ll need to enter details like hostname, port, username, and password.

Note: The installer will create a database called morphus if it doesn’t already exist.
Currently, it does not support SSL database connections (coming in a future version).

---

##  CLI Utility

After installation, a global CLI command `morphus` is registered with the following subcommands:

```bash
morphus version     # Dislays the current version
morphus start       # Launch containers
morphus stop        # Stop containers
morphus update      # Upgrade to another version
morphus rollback    # Rollsback to the previous version
morphus uninstall   # Remove all containers and files
```

---
### Version

To see what version of DataMorph you have installed, run
```bash
morphus version
```

---

### Start DataMorph

Once installed you can start DataMorph by running:

```bash
morphus start
```

During the first launch, you'll be asked to:

- Enter your organization’s domain name
- Confirm it using 'y' for yes or 'n' for no
- Provide your first name, last name, and company email
- A user account is created for you automatically with default password: `Welcome@123`

---

###  Stop DataMorph

```bash
morphus stop
```

- Stops all the containers
---

###  Updating to a Newer Version

```bash
morphus update
```

- Fetches laatest version from GitHub
- Updates `.env`
- Restarts containers with new version

---
###  Rollback to a Previous Version

```bash
morphus rollback
```

- Rolls back the application to the most recent previously installed version.
- Rollback is limited to only one version back (cannot revert to older versions beyond the immediate last one).
- Automatically restarts all containers using the rolled-back version.
  ** Note: Any changes made before rollback will be lost after rollback

---



##  Directory Structure

```
/var/morphus/
├── logs/
│   ├── ui/
│   └── backend/
│       ├── api-gateway/
│       ├── auth/
│       ├── user-access-management/
│       ├── metadata/
│       └── email-notification/
├── database/
│   └── postgres/                  # Postgres data storage
├── docker-compose.yaml            # Main docker-compose file
├── .env                           # Environment variables
├── .ver                           # Version tracking file
├── .org_created                   # Marker for org creation
├── .user_created                  # Marker for user creation

```

```
/var/airflow/
├── dags/                          # DAGs for workflows
├── logs/                          # Airflow logs
├── config/                        # Configuration files
├── plugins/                       # Custom plugins
├── test/                          # Test files
├── scripts/                       # Custom scripts
├── api/                           # API-related files
├── dag_json_data/                 # JSON data for DAGs


```

```
/var/morphus_backup/
├── v1.0/                # Backup for version v1.0 (Previous version) before moving to v2.0(Next version)
│   ├── morphus/         # Backup of /var/morphus
│   └── airflow/         # Backup of /var/airflow
                         # Additional version backups

```
---
##  Troubleshooting

| Issue                                                 | Solution / Cause                                                   |
|-------------------------------------------------------|--------------------------------------------------------------------|
| Docker Not Installed                                  | [Install Docker](https://docs.docker.com/get-docker/)              |
| Docker Not Running                                    | `sudo systemctl start docker`                                      |
| Port Conflicts                                        | Script prompts for alternate ports if in use                       |
| DB Connection Fails                                   | Ensure Postgres credentials and host/port are correct              |
| Permissions Issues                                    | Run with sudo where prompted                                       |
| Docker Compose Validation                             | YAML errors block deployment—check `docker-compose.yaml` structure |
| Containers keep restarting without any error messages | Check if there is enough space on the server                       |

---

## Uninstall

```bash
morphus uninstall
```

- Stops all containers
- Removes volumes, networks, and logs
- Deletes all installed files and CLI shortcut

---

##  Log Files

Log files are stored in:

- `/var/morphus/logs/ui/`
- `/var/morphus/logs/backend/`
- `/var/airflow/logs`

---

##  Notes

- Supports Linux and macOS
- Docker images must be compatible with version mappings set in `.env`
- First-time start performs DB insertions for organization and user creation

---

##  Contact

For questions or access to the repository, contact `Saloni Shah: saloni.shah@infodatinc.com`
