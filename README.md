# Lemmy Docker Compose Setup

This repository contains a Docker Compose configuration for running a Lemmy instance with nginx as a reverse proxy.

## Architecture Overview

```
[External Traffic]
     │
     ↓
[Nginx Reverse Proxy]
     │
     ├─→ Lemmy Backend
     ├─→ Lemmy UI
     └─→ PictRS
```

### Components

- **Nginx** - Reverse proxy fronting the Lemmy instance
- **Lemmy Backend** (`dessalines/lemmy:0.19.13`) - Main Lemmy server
- **Lemmy UI** (`dessalines/lemmy-ui:0.19.13`) - Web interface
- **PictRS** (`asonix/pictrs:0.5.19`) - Image hosting service

## Network Architecture

The deployment uses nginx as a reverse proxy to handle incoming traffic and route it to the appropriate services (Lemmy Backend, Lemmy UI, or PictRS).

## Prerequisites

- Docker and Docker Compose installed

## Setup Instructions

### 1. Clone and Configure

```bash
git clone <this-repo>
cd lemmy-compose
```

### 2. Create Configuration Files

Create the following files (they are git-ignored for security):

#### `.env.production`
```bash
PICTRS__SERVER__API_KEY=your_pictrs_api_key_here
```

#### `lemmy.hjson`
```hjson
{
  database: {
    host: your.database.host
    password: "your_database_password"
  }
  hostname: "your.domain.com"
  pictrs: {
    url: "http://pictrs:8080/"
    api_key: "your_pictrs_api_key_here"
  }
  email: {
    smtp_server: "your.smtp.server:587"
    smtp_login: "your_smtp_login"
    smtp_password: "your_smtp_password"
    smtp_from_address: "noreply@your.domain.com"
    tls_type: "starttls"
  }
}
```

### 3. Start Services

```bash
# Make scripts executable
chmod +x init.sh update.sh

# Initialize and start
./init.sh
```

## Management Scripts

- **`init.sh`** - Initial setup and start services
- **`update.sh`** - Update container images and restart

## File Structure

```
.
├── compose.yaml           # Docker Compose configuration
├── Caddyfile             # Legacy Caddy configuration
├── lemmy.hjson           # Lemmy configuration (git-ignored)
├── .env.production       # Environment variables (git-ignored)
├── nginx_internal.conf   # Internal nginx configuration
├── nginx.conf            # Nginx reverse proxy configuration
├── proxy_params          # Proxy parameters
├── init.sh              # Setup script
├── update.sh            # Update script
└── volumes/             # Persistent data (git-ignored)
    ├── lemmy-ui/
    └── pictrs/
```

## Security Notes

- All sensitive configuration files are git-ignored
- Credentials are stored in separate files (`.env.production`, `lemmy.hjson`)
- Nginx handles SSL/TLS termination and reverse proxy functionality
- Services are isolated within Docker containers

## Networking Details

- **Nginx**: Exposes port 80/443 for external access
- **Lemmy Backend**: Internal to Docker network (port 8536)
- **Lemmy UI**: Internal to Docker network (port 1234)
- **PictRS**: Internal to Docker network (port 8080)
- **External Access**: Through nginx reverse proxy

## Troubleshooting

### View Logs
```bash
docker compose logs -f lemmy
docker compose logs -f lemmy-ui
docker compose logs -f pictrs
```

### Check Service Status
```bash
docker compose ps
```

## Updates

Run the update script to pull latest images and restart services:
```bash
./update.sh
```

## Backup

Important directories to backup:
- `volumes/pictrs/` - Image storage
- `lemmy.hjson` - Configuration
- `.env.production` - Environment variables
- `nginx.conf` - Nginx configuration
