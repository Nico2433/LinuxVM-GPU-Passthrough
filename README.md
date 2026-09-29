# Dynamic GPU Passthrough Setup (KVM/Libvirt)

This repository contains automated installation scripts and template files to set up dynamic single/dual-GPU passthrough on Linux (specifically CachyOS / Arch / Fedora with KDE Plasma Wayland).

---

## 📋 How to Find Hardware Information for `install.sh`

Before running `sudo ./install.sh`, inspect your system hardware to fill in the variables inside `install.sh`.

### 1. Identify GPU PCI Addresses (`PASSTHROUGH_GPU_PCI`)
Run the following command to list all graphics cards:
```bash
lspci -nn | grep -iE "vga|3d|display"

```

Example output:

```text
00:02.0 VGA compatible controller [0300]: Intel Corporation UHD Graphics 770
03:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. Navi 48

```

Set `PASSTHROUGH_GPU_PCI="0000:03:00"` (Format: `domain:bus:slot` up to `.0`, omit the `.0` suffix).

---

### 2. Identify Host Kernel Drivers (`HOST_GPU_DRIVER` & `HOST_AUDIO_DRIVER`)

Check which kernel driver is actively managing your passthrough GPU:

```bash
lspci -k -s 03:00.0
lspci -k -s 03:00.1

```

* **Example output for Video (.0):** `Kernel driver in use: amdgpu` (or `nvidia`, `i915`, etc.)
* **Example output for Audio (.1):** `Kernel driver in use: snd_hda_intel`

Set `HOST_GPU_DRIVER="amdgpu"` and `HOST_AUDIO_DRIVER="snd_hda_intel"`.

---

### 3. Identify DRM Card Mapping (`PRIMARY_DISPLAY_CARD` & `PASSTHROUGH_DISPLAY_CARD`)

Check which DRM card nodes map to your primary host GPU and passthrough GPU:

```bash
ls -l /dev/dri/by-path/

```

Example output:

```text
pci-0000:00:02.0-card -> ../card1   # Host primary iGPU
pci-0000:03:00.0-card -> ../card0   # Passthrough dGPU

```

* Set `PRIMARY_DISPLAY_CARD="card1"` (the GPU driving your desktop).
* Set `PASSTHROUGH_DISPLAY_CARD="card0"` (the GPU assigned to the VM).

---

### 4. Locate Virtual Disk and ISO Images

* `VM_DISK_PATH`: Absolute path to your `.qcow2` virtual disk image.
* `VM_ISO_PATH`: Absolute path to your Windows ISO installer.

---

## 🚀 Installation Command

Make `install.sh` executable and run it with `sudo`:

```bash
chmod +x install.sh
sudo ./install.sh

```

After installation completes, **reboot your PC once** to ensure KDE Plasma loads the updated `/etc/environment` DRM device order.
