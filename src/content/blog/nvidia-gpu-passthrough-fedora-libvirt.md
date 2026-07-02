---
title: "NVIDIA GPU Passthrough on Fedora with dual vendor GPUs"
description: "Getting VFIO GPU passthrough working on Fedora 44 with an Intel Arc for display and an NVIDIA RTX 3060 Ti for VM compute. "
date: 2026-07-02
tags: ["fedora", "gpu", "libvirt", "vfio", "nvidia"]
featured: true
---

I have a Lenovo workstation running Fedora 44 with two GPUs. An Intel Arc A310 Sparkle handles display output, and an NVIDIA RTX 3060 Ti to be passed through to a KVM virtual machine for CUDA workloads. The goal was to run vLLM inference inside a libvirt VM with direct consumer GPU access while keeping the host display on the Intel card.
Having two different GPU vendors actually simplifies passthrough. The vfio-pci driver binds to devices by vendor:device ID, so with an Intel card (8086:56a6) and an 
NVIDIA card (10de:2486), the kernel can unambiguously route each GPU to the right driver. Two NVIDIA GPUs with the same device ID would both get claimed by vfio-pci, 
leaving nothing for the host display. With separate vendors there is no ambiguity, but getting the boot sequence right still took some effort and this turned out to be harder than expected...

## The setup

The hardware is an i7-11700KF with no integrated GPU, which means I ended up purchasing and Intel Arc to use as a "discrete" GPU, even though losing console access is not such a big deal for labs, I still like to be able to use Wayland for other purposes (NVIDIA Nsight, ...). The RTX 3060 Ti needs to be bound to `vfio-pci` so libvirt can pass it through to a VM.  

First, I confirmed IOMMU is enabled and the GPU is in a "clean" group.

```bash
cat /proc/cmdline | grep intel_iommu
# Should contain: intel_iommu=on iommu=pt
```

Check IOMMU groups to make sure the NVIDIA GPU and its audio controller are isolated from host devices.

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/}; n=${n%/devices/*}
  printf 'IOMMU Group %s: ' "$n"
  lspci -nns "${d##*/}"
done
```

On my system the RTX 3060 Ti (10de:2486) and its integrated audio device (10de:228b) are in IOMMU group 12. The device IDs are `10de:2486` for the GPU and `10de:228b` for the audio controller. You can find yours with `lspci -nn | grep -i nvidia`.

## What did not work

The standard advice is to create a modprobe config, blacklist nouveau, and rebuild the initramfs.

```bash
echo 'options vfio-pci ids=10de:2486,10de:228b disable_vga=1' > /etc/modprobe.d/vfio.conf

cat > /etc/modprobe.d/blacklist-nvidia.conf <<EOF
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
EOF

echo 'add_drivers+=" vfio vfio_iommu_type1 vfio_pci "' > /etc/dracut.conf.d/vfio.conf
dracut -f
reboot
```

After rebooting, `lspci -nnk -s 02:00.0` still showed `Kernel driver in use: nouveau`. The vfio modules were not in the initramfs and the kernel parameter `vfio-pci.ids=10de:2486,10de:228b` was being read too late.

Adding the IDs to the kernel command line via GRUB did not help either.

```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX="... vfio-pci.ids=10de:2486,10de:228b"
```

After another revoot, still nouveau.  
The problem is that on modern Fedora kernels, the `vfio-pci.ids` parameter is only effective if the vfio-pci module is loaded from the initramfs before nouveau gets a chance to claim the device.

## What worked

Three changes are needed together and none of them works by itself.

First, use `force_drivers` instead of `add_drivers` in the dracut configuration. This ensures the modules are both included in the initramfs and loaded early.

```bash
echo 'force_drivers+=" vfio vfio_iommu_type1 vfio_pci "' > /etc/dracut.conf.d/vfio.conf
```

Second, add `rd.driver.pre=vfio-pci` to the kernel command line. This tells dracut to load vfio-pci before any other driver during the initramfs stage.

```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX="rhgb quiet intel_iommu=on iommu=pt rd.driver.blacklist=nouveau modprobe.blacklist=nouveau rd.driver.pre=vfio-pci vfio-pci.ids=10de:2486,10de:228b"
```

Third, rebuild both GRUB and the initramfs, then verify the modules are present.

```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
dracut -f --kver $(uname -r)
lsinitrd | grep vfio
```

The `lsinitrd` output should show the vfio kernel modules and `rd.driver.pre=vfio` entries. If it doesn't the passthrough will not work.

```
usr/lib/modules/.../kernel/drivers/vfio/pci/vfio-pci.ko.xz
usr/lib/modules/.../kernel/drivers/vfio/vfio.ko.xz
usr/lib/modules/.../kernel/drivers/vfio/vfio_iommu_type1.ko.xz
rd.driver.pre=vfio
rd.driver.pre=vfio_iommu_type1
rd.driver.pre=vfio_pci
```

After rebooting, verify the binding.

```bash
lspci -nnk -s 02:00.0
```

```
02:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA104 [GeForce RTX 3060 Ti] [10de:2486] (rev a1)
    Kernel driver in use: vfio-pci
    Kernel modules: nouveau
```

The `Kernel driver in use: vfio-pci` confirms the GPU is claimed by VFIO. The `Kernel modules: nouveau` line just lists what could handle the device, not what is active. The Intel Arc stays on `i915` for the host display to work normally.

## Why this is confusing

The Fedora and Arch documentation often presents `add_drivers` and `vfio-pci.ids` in the kernel cmdline as sufficient. On recent kernels (7.0.13-200.fc44.x86_64) with dracut 107+ this is no longer the case. The `add_drivers` directive includes modules in the initramfs but does not force them to load. Without `force_drivers` and `rd.driver.pre=vfio-pci`, the vfio-pci module sits in the initramfs unused while nouveau claims the GPU first.

The distinction between `add_drivers` and `force_drivers` is documented in `man dracut.conf` but really easy to miss IMO. The `rd.driver.pre` parameter is mentioned in `man dracut.cmdline` under the driver loading section.

## References

- [Fedora RHEL VFIO Guide](https://github.com/pascal48/Fedora-RHEL-VFIO-guide)
- [PCI passthrough via OVMF, ArchWiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [GPU Passthrough on Fedora](https://gist.github.com/paul-vd/5328d8eb2c626dff36ee143da2e85179)
- [VFIO grub vfio-pci.ids with kernel 6+](https://www.heiko-sieger.info/vfio-grub-vfio-pci-ids-doesnt-work-with-kernel-6-try-driver-verride-feature/)
- [dracut.conf man page](https://man7.org/linux/man-pages/man5/dracut.conf.5.html)
