# Dynamic GPU Passthrough Setup (KVM/Libvirt)

This repository contains automated installation scripts and template files to set up dynamic single/dual-GPU passthrough on Linux (specifically CachyOS / Arch / Fedora with KDE Plasma Wayland).

---

## ⚙️ Prerequisites & Kernel Parameters (Limine / Bootloader)

For VFIO device assignment to work properly, IOMMU must be explicitly enabled in your bootloader kernel parameters.

### Enabling IOMMU in Limine Bootloader

If your system uses **Limine** (common in CachyOS), configure the kernel command line parameters:

1. Locate your Limine configuration file:
```bash
   sudo micro /boot/limine.conf
```

*(Note: If using systemd-boot or GRUB, edit `/boot/loader/entries/` or `/etc/default/grub` respectively).*

2. Append the required IOMMU parameters to your kernel command line (`cmdline:` or `kernel_cmdline:`):
* For **Intel CPUs**: `intel_iommu=on iommu=pt`
* For **AMD CPUs**: `amd_iommu=on iommu=pt`


*Example line:*
```text
cmdline: boot=UUID=... quiet splash intel_iommu=on iommu=pt
```


3. Ensure VFIO modules are loaded at boot:
```bash
echo -e "vfio\nvfio_pci\nvfio_iommu_type1" | sudo tee /etc/modules-load.d/vfio.conf
```



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

## 🖥️ Mouse & Keyboard Sharing Across Displays (Deskflow)

When using the physical display output of the passthrough GPU connected to a second monitor, you can use **Deskflow** to seamlessly share your mouse, keyboard, and clipboard across Linux and Windows as if it were an extended multi-monitor desktop setup.

* **Linux Host:** Run Deskflow as a Server.
* **Windows VM:** Run Deskflow as a Client pointing to the host's local IP or bridge interface.
* **UAC / Secure Desktop Fix:** In Windows, install Deskflow as a Windows Service to maintain mouse control during Administrator/UAC prompts.

---

## 🚀 Installation Command

Make `install.sh` executable and run it with `sudo`:

```bash
chmod +x install.sh
sudo ./install.sh
```

After installation completes, **reboot your PC once** to ensure KDE Plasma loads the updated `/etc/environment` DRM device order and IOMMU kernel parameters.
