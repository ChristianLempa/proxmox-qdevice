#!/bin/bash
set -e

INIT_FLAG="/data/.initialized"
CONFIG_DIR="/etc/corosync/qnetd"
DATA_CONFIG_DIR="/data/qnetd"
NSSDB_DIR="$CONFIG_DIR/nssdb"

# Restore persistent data if it exists
if [ -d "$DATA_CONFIG_DIR" ]; then
    echo "Restoring qnetd configuration from persistent storage..."
    mkdir -p "$CONFIG_DIR"
    cp -a "$DATA_CONFIG_DIR"/* "$CONFIG_DIR/" 2>/dev/null || true
fi

# Only run initialization on first start
if [ ! -f "$INIT_FLAG" ]; then
    echo "First time initialization..."
    
    # Initialize corosync-qnetd only if nssdb doesn't exist
    if [ ! -d "$NSSDB_DIR" ]; then
        echo "Initializing corosync-qnetd..."
        corosync-qnetd-certutil -i
    else
        echo "Certificate database already exists, skipping initialization..."
    fi
    
    # Check if PROXMOX_NODES is set
    if [ -n "$PROXMOX_NODES" ]; then
        echo "Connecting to Proxmox nodes..."
        
        # Split nodes by comma
        IFS=',' read -ra NODES <<< "$PROXMOX_NODES"
        
        for NODE in "${NODES[@]}"; do
            NODE=$(echo "$NODE" | xargs) # Trim whitespace
            echo "Processing node: $NODE"
            
            if [ -z "$PROXMOX_USER" ] || [ -z "$PROXMOX_PASSWORD" ]; then
                echo "WARNING: PROXMOX_USER and PROXMOX_PASSWORD must be set to auto-configure nodes"
                echo "Skipping automatic node configuration..."
                break
            fi
            
            # Extract hostname if format is user@host
            if [[ "$NODE" == *"@"* ]]; then
                HOST="${NODE##*@}"
            else
                HOST="$NODE"
            fi
            
            echo "Connecting to $HOST..."
            
            # Use the provided credentials to connect
            CONNECT_USER="${PROXMOX_USER}@${HOST}"
            
            # Get the container's IP address or hostname
            QDEVICE_ADDRESS="${QDEVICE_IP:-$(hostname -I | awk '{print $1}')}"
            if [ -z "$QDEVICE_ADDRESS" ]; then
                QDEVICE_ADDRESS="$(hostname -f)"
            fi
            
            echo "Using QDevice address: $QDEVICE_ADDRESS"
            
            # Remove existing qdevice if present
            echo "Removing any existing qdevice configuration from $HOST..."
            timeout 10 sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                "$CONNECT_USER" "pvecm qdevice remove" 2>&1 | grep -v "No QDevice configured" || echo "No existing qdevice found (this is normal)"
            
            # Try to configure the node
            if sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                "$CONNECT_USER" "pvecm qdevice setup $QDEVICE_ADDRESS" 2>&1; then
                echo "Successfully configured node: $HOST"
            else
                echo "WARNING: Failed to configure node: $HOST"
            fi
        done
    else
        echo "PROXMOX_NODES not set. Manual configuration required."
        echo "Run on each Proxmox node: pvecm qdevice setup <qdevice-ip>"
    fi
    
    # Save configuration to persistent storage
    echo "Saving configuration to persistent storage..."
    mkdir -p "$DATA_CONFIG_DIR"
    cp -a "$CONFIG_DIR"/* "$DATA_CONFIG_DIR/"
    
    # Mark as initialized
    touch "$INIT_FLAG"
    echo "Initialization complete!"
else
    echo "Already initialized. Skipping initialization..."
fi

# Ensure configuration is up to date in persistent storage
mkdir -p "$DATA_CONFIG_DIR"
cp -a "$CONFIG_DIR"/* "$DATA_CONFIG_DIR/" 2>/dev/null || true

echo "Starting corosync-qnetd..."
exec "$@"
