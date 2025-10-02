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
Address = 10.0.3.6/24, 2001:db8:1234:5678::fed2/64
PrivateKey = your_private_key_here
# Split tunneling: Allow home network access while routing everything else through VPN
PostUp = DROUTE=$(ip route | grep default | awk '{print $3}'); HOMENET=192.168.0.0/16; HOMENET2=10.0.0.0/8; HOMENET3=172.16.0.0/12; ip route add $HOMENET3 via $DROUTE; ip route add $HOMENET2 via $DROUTE; ip route add $HOMENET via $DROUTE; iptables -I OUTPUT -d $HOMENET -j ACCEPT; iptables -A OUTPUT -d $HOMENET2 -j ACCEPT; iptables -A OUTPUT -d $HOMENET3 -j ACCEPT;  iptables -A OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = HOMENET=192.168.0.0/16; HOMENET2=10.0.0.0/8; HOMENET3=172.16.0.0/12; ip route delete $HOMENET; ip route delete $HOMENET2; ip route delete $HOMENET3; iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT; iptables -D OUTPUT -d $HOMENET -j ACCEPT; iptables -D OUTPUT -d $HOMENET2 -j ACCEPT; iptables -D OUTPUT -d $HOMENET3 -j ACCEPT

[Peer]
PublicKey = gateway_server_public_key
Endpoint = gateway.server.address:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 15
```

#### Split Tunneling Explanation

The PostUp/PreDown rules implement split tunneling to allow local network access:

- **HOMENET variables**: Define common home network ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
- **Route preservation**: Saves the default gateway and adds routes for home networks
- **iptables rules**: Allows traffic to home networks while forcing everything else through VPN
- **Cleanup**: PreDown removes all routes and iptables rules when disconnecting

This allows the server to maintain local network connectivity (for SSH, local services) while routing all Lemmy traffic through the secure WireGuard tunnel.

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
