# DataMorph


 **DataMorph** is a secure, scalable application designed to automate and manage data transfers between various sources and destinations using configurable pipelines. The `MorphusInstaller.sh`  simplifies deployment and management of DataMorph application using Docker and Docker Compose. It offers guided setup and CLI-based lifecycle control.

---

##  Tech Stack

- **Frontend:** Angular
- **Backend:** Java-Springboot 
- **Workflow Orchestration:** Apache Airflow
- **Databases:** MySQL (backend) & PostgreSQL (Airflow)
- **Containerization:** Docker + Docker Compose

---

##  Prerequisites

- **Operating System:** Linux
- **RAM:** 8 GB
- **Storage:** 30 GB  

### Required Tools

| Tool             | Install Commands (Ubuntu/Debian)                                    | Confirm Installation         |
|------------------|---------------------------------------------------------------------|------------------------------|
| Docker           | `sudo apt install docker.io`                                        | `docker --version`           |
| Docker Compose V2| `sudo apt install docker-compose-plugin`                            | `docker compose version`     |
| lsof             | `sudo apt install lsof`                                             |                              |
| jq               | `sudo apt install jq`                                               |                              |
| mysql-client     | `sudo apt install mysql-client`                                     |                              |

**Note:** Script execution may prompt for password to run certain commands with `sudo` priveleges when necessary.

---

##  Installation

### 1. Clone the repository

```bash
curl -o MorphusInstaller.sh https://raw.githubusercontent.com/Lynette-Pinto/Advanced-File-Transfer-and-Data-Processing-System/main/MorphusInstaller.sh
cd <script_location>
chmod +x MorphusInstaller.sh
```

### 2. Run the Installer

```bash
Mac OS:
sh MorphusInstaller.sh

Linux OS:
./MorphusInstaller.sh
```

You will be prompted for:

- Confirmation of Docker availability 
- Port number (UI), Default port: 80
- MySQL database setup (New or Existing)
    - Existing Database (Hostname, Port, Username, Password)
- Docker Compose validation
  
Note: If you choose to use an existing database, the application will attempt to connect using the provided details. It will automatically create a database named morphus if it does not already exist.

### 4. Version

```bash
morphus version
```

You can check the current version of Morphus Data that is installed on the system using this command.

---

### 3. Start the Service

```bash
morphus start
```

During the first launch, you'll be asked to:

1. Enter your organization’s domain name
2. Confirm it using 'y' for yes or 'n' for no
3. Provide your first name, last name, and company email
4. A user account is created with the above details and a default password: `Welcome@123`

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
│   └── mysql/                   # MySQL data storage
├── docker-compose.yaml           # Main docker-compose file
├── .env                          # Environment variables
├── .ver                          # Version tracking file
├── .org_created                   # Marker for org creation
├── .user_created                  # Marker for user creation

```

```
/var/airflow/
├── dags/                         # DAGs for workflows
├── logs/                         # Airflow logs
├── config/                       # Configuration files
├── plugins/                       # Custom plugins
├── test/                          # Test files
├── scripts/                       # Custom scripts
├── api/                           # API-related files
├── dag_json_data/                  # JSON data for DAGs


```

```
/var/morphus_backup/
├── v1.0/                           # Backup for version v1.0 (Previous version) before moving to v2.0(Next version)
│   ├── morphus/                    # Backup of /var/morphus
│   └── airflow/                    # Backup of /var/airflow
                                    # Additional version backups

```

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

##  Updating to a Newer Version

```bash
morphus update
```

- Fetches laatest version from GitHub
- Updates `.env`
- Restarts containers with new version

---
##  Rollback to a Previous Version

```bash
morphus rollback
```

- Rolls back the application to the most recent previously installed version.
- Rollback is limited to only one version back (cannot revert to older versions beyond the immediate last one).
- Automatically restarts all containers using the rolled-back version.
** Note: Any changes made before rollback will be lost after rollback

---

##  Troubleshooting

| Issue                         | Solution                                                                 |
|------------------------------|--------------------------------------------------------------------------|
| Docker Not Installed          | [Install Docker](https://docs.docker.com/get-docker/)                    |
| Docker Not Running            | `sudo systemctl start docker`                                           |
| Port Conflicts                | Script prompts for alternate ports if in use                            |
| DB Connection Fails           | Ensure MySQL credentials and host/port are correct                      |
| Permissions Issues            | Run with sudo where prompted                                            |
| Docker Compose Validation     | YAML errors block deployment—check `docker-compose.yaml` structure      |

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

For questions or access to the repository, contact: `< maintainer contact>`
