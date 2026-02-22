#!/bin/sh
# Auto-detect GPU and set Wayland environment accordingly.
# Supports NVIDIA (proprietary + nouveau/NVK), AMD, Intel, and software fallback.
#
# Detection priority: when multiple GPUs are present (e.g. AMD iGPU + NVIDIA dGPU),
# prefer the one with a working open-source driver for EGL/GLES2 (AMD/Intel).
# NVIDIA nouveau on modern GPUs uses NVK (Vulkan-only), so sway must use
# WLR_RENDERER=vulkan instead of the default GLES2 renderer.

HAS_NVIDIA=""
HAS_AMD=""
HAS_INTEL=""
NVIDIA_PROPRIETARY=""

if command -v lspci > /dev/null 2>&1; then
    lspci_vga=$(lspci -nn 2>/dev/null | grep -iE 'VGA|3D|Display')
    case "$lspci_vga" in *NVIDIA*|*nvidia*) HAS_NVIDIA=1 ;; esac
    case "$lspci_vga" in *AMD*|*ATI*|*Radeon*) HAS_AMD=1 ;; esac
    case "$lspci_vga" in *Intel*|*intel*) HAS_INTEL=1 ;; esac
fi

# Check if NVIDIA proprietary driver is loaded (not just nouveau)
if [ -d /sys/module/nvidia ]; then
    NVIDIA_PROPRIETARY=1
fi

# Pick the best available GPU for sway/wlroots 0.18+.
GPU_VENDOR=""
if [ -n "$NVIDIA_PROPRIETARY" ]; then
    GPU_VENDOR="nvidia"
elif [ -n "$HAS_AMD" ]; then
    GPU_VENDOR="amd"
elif [ -n "$HAS_INTEL" ]; then
    GPU_VENDOR="intel"
elif [ -n "$HAS_NVIDIA" ]; then
    GPU_VENDOR="nouveau"
fi

case "$GPU_VENDOR" in
    nvidia)
        # Proprietary NVIDIA driver — supports EGL natively
        export WLR_NO_HARDWARE_CURSORS=1
        export GBM_BACKEND=nvidia-drm
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export LIBVA_DRIVER_NAME=nvidia
        ;;
    amd)
        export LIBVA_DRIVER_NAME=radeonsi
        ;;
    intel)
        export LIBVA_DRIVER_NAME=iHD
        ;;
    nouveau)
        # NVK is Vulkan-only — enable Zink so OpenGL/EGL works too
        # (Zink translates GL calls to Vulkan/NVK)
        export MESA_LOADER_DRIVER_OVERRIDE=zink
        # Sway: prefer Vulkan renderer (direct NVK, fastest path)
        # Falls back to GLES2 via Zink if Vulkan renderer fails
        export WLR_RENDERER=vulkan
        export WLR_NO_HARDWARE_CURSORS=1
        ;;
    *)
        # No GPU detected — software rendering
        export WLR_RENDERER=pixman
        export LIBGL_ALWAYS_SOFTWARE=1
        ;;
esac
