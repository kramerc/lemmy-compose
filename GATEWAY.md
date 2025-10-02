# Gateway Server Setup

This document describes how to set up the gateway server that acts as a reverse proxy for the Lemmy deployment running on a remote server connected via WireGuard.

## Overview

The gateway server runs:
- **Caddy** - Reverse proxy and TLS termination
- **WireGuard Server** - VPN server for secure tunneling to remote deployments

## Architecture

```
Internet → Gateway Server (Caddy + WireGuard Server) → WireGuard Tunnel → Remote Server (Lemmy)
```

## Prerequisites

- Server with public IP address
- Domain name pointing to the server
- WireGuard installed
- Caddy installed

## WireGuard Server Configuration

### 1. Install WireGuard

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install wireguard

# Generate server keys
cd /etc/wireguard
sudo wg genkey | sudo tee privatekey | wg pubkey | sudo tee publickey
```

### 2. Server Configuration

Create `/etc/wireguard/wg0.conf`:

```ini
[Interface]
# Server configuration
Address = 10.0.3.1/24
ListenPort = 51820
PrivateKey = <server_private_key>

# IP forwarding and NAT rules
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client peer (Lemmy server)
[Peer]
# Replace with client's public key
PublicKey = <client_public_key>
AllowedIPs = 10.0.3.6/32
```

### 3. Enable and Start WireGuard

```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Start WireGuard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Check status
sudo wg show
```

## Caddy Configuration

### 1. Install Caddy

```bash
# Ubuntu/Debian
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

### 2. Deploy Caddyfile

Copy the `Caddyfile` from this repository to `/etc/caddy/Caddyfile`:

```bash
# From the lemmy-compose repository
sudo cp Caddyfile /etc/caddy/Caddyfile
```

The Caddyfile uses sophisticated routing to properly handle Lemmy's architecture:

```caddyfile
slevin.horse {
    encode gzip

    header {
        -Server
        Strict-Transport-Security "max-age=31536000; include-subdomains;"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "DENY"
        X-Content-Type-Options nosniff
        Referrer-Policy no-referrer-when-downgrade
        X-Robots-Tag "none"
    }

    log {
        output file /var/log/caddy/slevin.horse/access.log {
            roll_size 1gb
            roll_keep 5
            roll_keep_for 720h
        }
    }

    # Path-based matcher → Lemmy backend
    @lemmy {
        path /api/* /pictrs/* /feeds/* /nodeinfo/* /.well-known/*
    }

    # Header-based matcher
    @lemmy-hdr {
        header Accept application/*
    }

    # Method-based matcher
    @lemmy-post {
        method POST
    }

    # Send API, header, and POST traffic to backend
    handle @lemmy {
        reverse_proxy 10.0.3.6:8536
    }
    handle @lemmy-hdr {
        reverse_proxy 10.0.3.6:8536
    }
    handle @lemmy-post {
        reverse_proxy 10.0.3.6:8536
    }

    # Everything else → UI
    handle {
        reverse_proxy 10.0.3.6:1234
    }
}
```

This configuration intelligently routes traffic:
- **API requests** (`/api/*`, `/pictrs/*`, etc.) → Lemmy Backend (port 8536)
- **Application requests** (Accept: application/*) → Lemmy Backend (port 8536) 
- **POST requests** → Lemmy Backend (port 8536)
- **Everything else** → Lemmy UI (port 1234)

### 3. Start Caddy

```bash
# Test configuration
sudo caddy validate --config /etc/caddy/Caddyfile

# Start and enable Caddy
sudo systemctl enable caddy
sudo systemctl start caddy

# Check status
sudo systemctl status caddy
```

## Firewall Configuration

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow WireGuard
sudo ufw allow 51820/udp

# Enable firewall
sudo ufw --force enable
```

## Monitoring and Troubleshooting

### Check WireGuard Status
```bash
sudo wg show
sudo systemctl status wg-quick@wg0
```

### Check Caddy Status
```bash
sudo systemctl status caddy
sudo journalctl -u caddy -f
```

### View Logs
```bash
# Caddy logs
sudo tail -f /var/log/caddy/lemmy.log

# System logs
sudo journalctl -u wg-quick@wg0 -f
sudo journalctl -u caddy -f
```

### Test Connectivity
```bash
# Ping remote server through WireGuard
ping 10.0.3.6

# Test HTTP connectivity
curl -H "Host: your.domain.com" http://10.0.3.6:1234
```

## Client Certificate Generation

For new clients connecting to the WireGuard server:

```bash
# Generate client keys
wg genkey | tee client_private.key | wg pubkey > client_public.key

# Add to server config and restart
sudo systemctl restart wg-quick@wg0
```

## Security Considerations

1. **Regular Updates**: Keep both Caddy and WireGuard updated
2. **Key Rotation**: Regularly rotate WireGuard keys
3. **Access Logs**: Monitor access logs for suspicious activity
4. **Fail2ban**: Consider implementing fail2ban for additional protection
5. **Backup Keys**: Securely backup WireGuard private keys

## Maintenance

### Update Caddy
```bash
sudo apt update && sudo apt upgrade caddy
sudo systemctl restart caddy
```

### Rotate WireGuard Keys
```bash
# Generate new server keys
cd /etc/wireguard
sudo wg genkey | sudo tee privatekey_new | wg pubkey | sudo tee publickey_new

# Update configuration and restart
sudo systemctl restart wg-quick@wg0
```
