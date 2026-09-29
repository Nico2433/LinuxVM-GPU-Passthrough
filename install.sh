#!/bin/bash
set -e

# Ensure execution with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run the installer with sudo:"
  echo "sudo ./install.sh"
  exit 1
fi

SUDO_USER_NAME="${SUDO_USER:-$USER}"
USER_UID=$(id -u "$SUDO_USER_NAME")

echo "=== VFIO Single-dGPU Passthrough Installer ==="
echo "Target User: $SUDO_USER_NAME (UID: $USER_UID)"

# --- 1. User & Hardware Configuration Variables ---
VM_NAME="test"

# GPU Hardware Configuration
PASSTHROUGH_GPU_PCI="0000:03:00"   # PCI Address (domain:bus:slot) of the GPU for the VM
HOST_GPU_DRIVER="amdgpu"          # Host kernel driver for dGPU (e.g., amdgpu, nvidia)
HOST_AUDIO_DRIVER="snd_hda_intel" # Host audio driver for GPU audio device

# DRM Card Priority for KWin Wayland
PRIMARY_DISPLAY_CARD="card1"      # Host desktop DRM card (e.g., iGPU / primary card)
PASSTHROUGH_DISPLAY_CARD="card0"  # Passthrough dGPU DRM card

# Virtual Machine Resources
VM_RAM_KIB="16777216"             # 16 GB RAM in KiB
VM_VCPUS="4"                      # Number of allocated CPU cores
VM_DISK_PATH="/mnt/extra/images/test.qcow2"
VM_ISO_PATH="/mnt/extra/images/win11_ltsc.iso"

# Extract PCI bus and slot values for XML template
GPU_BUS=$(echo "$PASSTHROUGH_GPU_PCI" | cut -d':' -f2)
GPU_SLOT=$(echo "$PASSTHROUGH_GPU_PCI" | cut -d':' -f3)

# Export variables for envsubst template expansion
export VM_NAME PASSTHROUGH_GPU_PCI HOST_GPU_DRIVER HOST_AUDIO_DRIVER \
       VM_RAM_KIB VM_VCPUS VM_DISK_PATH VM_ISO_PATH USER_UID GPU_BUS GPU_SLOT

# --- 2. Copy and Configure Libvirt Hooks ---
echo "[+] Configuring Libvirt hooks..."
mkdir -p "/etc/libvirt/hooks/qemu.d/${VM_NAME}/prepare/begin"
mkdir -p "/etc/libvirt/hooks/qemu.d/${VM_NAME}/release/end"

# Copy main qemu hook dispatcher
if [ -f "qemu" ]; then
  cp qemu /etc/libvirt/hooks/qemu
  chmod +x /etc/libvirt/hooks/qemu
fi

# Expand and install start.sh hook
envsubst < start.sh.template > "/etc/libvirt/hooks/qemu.d/${VM_NAME}/prepare/begin/start.sh"
chmod +x "/etc/libvirt/hooks/qemu.d/${VM_NAME}/prepare/begin/start.sh"

# Expand and install revert.sh hook
envsubst < revert.sh.template > "/etc/libvirt/hooks/qemu.d/${VM_NAME}/release/end/revert.sh"
chmod +x "/etc/libvirt/hooks/qemu.d/${VM_NAME}/release/end/revert.sh"

# --- 3. Additive Environment Variable Update ---
echo "[+] Updating /etc/environment safely..."
ENV_FILE="/etc/environment"

if ! grep -q "KWIN_DRM_DEVICES" "$ENV_FILE"; then
  echo "KWIN_DRM_DEVICES=/dev/dri/${PRIMARY_DISPLAY_CARD}:/dev/dri/${PASSTHROUGH_DISPLAY_CARD}" >> "$ENV_FILE"
  echo "--> Added KWIN_DRM_DEVICES to /etc/environment"
fi

if ! grep -q "DRI_PRIME=" "$ENV_FILE"; then
  echo "DRI_PRIME=0" >> "$ENV_FILE"
  echo "--> Added DRI_PRIME=0 to /etc/environment"
fi

# --- 4. Generate and Define Virtual Machine XML ---
echo "[+] Generating VM XML configuration and defining domain..."
TEMP_XML=$(mktemp)
envsubst < win11.xml.template > "$TEMP_XML"

virsh define "$TEMP_XML"
rm -f "$TEMP_XML"

echo "=== Installation Completed Successfully! ==="