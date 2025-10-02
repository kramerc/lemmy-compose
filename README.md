# Lemmy Docker Compose Setup

This repository contains a Docker Compose configuration for running a Lemmy instance with WireGuard networking for secure remote deployment.

## Architecture Overview

```
[Gateway Server] ←→ [WireGuard Tunnel] ←→ [Remote Server (this deployment)]
     │                                           │
 Caddyfile                                   Docker Compose
 (Reverse Proxy)                            - Lemmy Backend
                                           - Lemmy UI  
                                           - PictRS
                                           - WireGuard Client
```

### Components

- **Lemmy Backend** (`dessalines/lemmy:0.19.13`) - Main Lemmy server
- **Lemmy UI** (`dessalines/lemmy-ui:0.19.13`) - Web interface
- **PictRS** (`asonix/pictrs:0.5.19`) - Image hosting service
- **WireGuard** (`lscr.io/linuxserver/wireguard`) - VPN client for secure networking

## Network Architecture

The deployment uses WireGuard to create a secure tunnel between the remote server and a gateway server:

1. **Gateway Server**: Runs Caddy reverse proxy with the `Caddyfile` configuration
2. **Remote Server**: Runs this Docker Compose stack connected via WireGuard
3. **WireGuard Network**: `10.0.3.0/24` subnet with the remote server at `10.0.3.6`

## Prerequisites

- Docker and Docker Compose installed
- Access to a gateway server for the Caddyfile deployment
- WireGuard configuration files

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

### 3. Configure WireGuard

Place your WireGuard configuration in `volumes/wireguard/wg_confs/`. The container expects:

- Client configuration files in `volumes/wireguard/wg_confs/`
- Private/public keys in `volumes/wireguard/`

Example client config (`volumes/wireguard/wg_confs/nexus.conf`):
```ini
[Interface]
Address = 10.0.3.6/24
PrivateKey = your_private_key_here
PostUp = # routing rules for split tunneling
PreDown = # cleanup routing rules

[Peer]
PublicKey = gateway_server_public_key
Endpoint = gateway.server.address:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 15
```

### 4. Gateway Server Setup

Deploy the `Caddyfile` to your gateway server. The Caddyfile should be configured to reverse proxy to the WireGuard IP of this deployment (`10.0.3.6`).

Example Caddyfile entry:
```caddyfile
your.domain.com {
    reverse_proxy 10.0.3.6:1234
    encode gzip
}
```

### 5. Start Services

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
├── Caddyfile             # Reverse proxy config (deploy to gateway)
├── lemmy.hjson           # Lemmy configuration (git-ignored)
├── .env.production       # Environment variables (git-ignored)
├── nginx_internal.conf   # Internal nginx configuration
├── proxy_params          # Proxy parameters
├── init.sh              # Setup script
├── update.sh            # Update script
└── volumes/             # Persistent data (git-ignored)
    ├── lemmy-ui/
    ├── pictrs/
    └── wireguard/
```

## Security Notes

- All sensitive configuration files are git-ignored
- Credentials are stored in separate files (`.env.production`, `lemmy.hjson`)
- WireGuard provides encrypted tunnel for all traffic
- Services are isolated within Docker containers

## Networking Details

- **Lemmy Backend**: Accessible via WireGuard at `10.0.3.6:8536`
- **Lemmy UI**: Accessible via WireGuard at `10.0.3.6:1234`
- **PictRS**: Internal to Docker network
- **External Access**: Through gateway server reverse proxy

## Troubleshooting

### Check WireGuard Connection
```bash
docker compose exec wireguard wg show
```

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
- `volumes/wireguard/` - WireGuard configuration
