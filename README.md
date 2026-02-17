# Proxmox QDevice Docker Container

A Docker container that provides a Corosync QDevice (quorum device) for Proxmox VE clusters. This external quorum device helps maintain cluster quorum in two-node clusters or provides an additional vote in larger clusters.

[![Build and Push Docker Image](https://github.com/ChristianLempa/proxmox-qdevice/actions/workflows/docker-build.yml/badge.svg)](https://github.com/ChristianLempa/proxmox-qdevice/actions/workflows/docker-build.yml)

## What is a QDevice?

A QDevice is an external arbiter that provides an additional vote to your Proxmox cluster. It's especially useful for:
- **Two-node clusters**: Prevents split-brain scenarios by providing a third vote
- **Even-numbered clusters**: Adds an extra vote to break ties
- **Disaster recovery**: Maintains quorum when half your nodes are unavailable

## Quick Start

> **Note**: Pre-built images are automatically published to GitHub Container Registry with every code change.

### Using Docker Compose (Recommended)

Create a `compose.yaml` file:

```yaml
---
services:
  proxmox-qdevice:
    image: ghcr.io/christianlempa/proxmox-qdevice:latest
    container_name: proxmox-qdevice
    restart: unless-stopped
    network_mode: host
    volumes:
      - qdevice-data:/data
    environment:
      - PROXMOX_NODES=192.168.1.10,192.168.1.11
      - PROXMOX_USER=root
      - PROXMOX_PASSWORD=your-password
      - QDEVICE_IP=192.168.1.100

volumes:
  qdevice-data:
```

Start the container:
```bash
docker compose up -d
```

### Using Docker CLI

```bash
docker run -d \
  --name proxmox-qdevice \
  --restart unless-stopped \
  --network host \
  -v qdevice-data:/data \
  -e PROXMOX_NODES=192.168.1.10,192.168.1.11 \
  -e PROXMOX_USER=root \
  -e PROXMOX_PASSWORD=your-password \
  -e QDEVICE_IP=192.168.1.100 \
  ghcr.io/christianlempa/proxmox-qdevice:latest
```

## Configuration

### Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `PROXMOX_NODES` | No* | Comma-separated list of Proxmox node IPs or hostnames | `192.168.1.10,192.168.1.11` |
| `PROXMOX_USER` | No* | SSH username for Proxmox nodes | `root` |
| `PROXMOX_PASSWORD` | No* | SSH password for Proxmox nodes | `your-password` |
| `QDEVICE_IP` | No | IP address to use for QDevice (auto-detected if not set). **Recommended to set explicitly** if your host has multiple network interfaces. | `192.168.1.100` |

**Note**: If you don't provide these variables, you'll need to manually configure each Proxmox node (see Manual Setup below).

**Important**: When running on a host with multiple network interfaces (e.g., NAS), always set `QDEVICE_IP` to the IP address on the same network as your Proxmox cluster.

### Volumes

- `/data` - Persistent storage for QDevice certificates and configuration. **Important**: This must be preserved across container updates!

### Ports

- `5403/tcp` - Corosync QDevice communication port (uses host network)

## Manual Setup

If you prefer not to provide credentials via environment variables, you can manually configure each Proxmox node:

1. Start the container without PROXMOX_* variables
2. On each Proxmox node, run:
```bash
pvecm qdevice setup <qdevice-container-ip>
```

## Updating the Container

The container preserves its configuration in the `/data` volume, so you can safely update:

```bash
docker compose pull
docker compose up -d
```

The QDevice will not re-initialize itself as long as the volume data is preserved.

## Verification

Check QDevice status on your Proxmox nodes:
```bash
pvecm status
```

You should see the QDevice listed with "Qdevice" information.

## Troubleshooting

### Check container logs
```bash
docker logs proxmox-qdevice
```

### Verify QDevice is running
```bash
docker exec proxmox-qdevice corosync-qnetd-tool -s
```

### Reset and re-initialize
If you need to start fresh, remove the volume data:
```bash
docker compose down -v
docker compose up -d
```

## Building from Source

If you want to build the image yourself instead of using the pre-built one:

```bash
git clone https://github.com/ChristianLempa/proxmox-qdevice.git
cd proxmox-qdevice
docker build -t proxmox-qdevice:latest .
```

Then update your compose.yaml to use `image: proxmox-qdevice:latest` or use `build: .` for local builds.

## Security Notes

- Store credentials securely (consider using Docker secrets in production)
- The container needs network host mode to communicate with Proxmox nodes
- Ensure port 5403 is accessible from your Proxmox nodes
- Use strong passwords for SSH authentication
- Pre-built images are scanned and built automatically via GitHub Actions
- Images are available for both amd64 and arm64 architectures

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file for details
