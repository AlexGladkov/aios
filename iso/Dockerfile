# AIOS ISO Builder
# Builds Debian Live ISO image for AIOS distribution
# Usage: docker build -t aios-iso-builder iso/
#        docker run --rm --privileged -v $(pwd)/output:/output aios-iso-builder

FROM debian:trixie

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        live-build \
        debootstrap \
        xorriso \
        isolinux \
        syslinux-efi \
        grub-efi-amd64-bin \
    && rm -rf /var/lib/apt/lists/*

# Store config in image layer (immutable).
# At runtime, build-iso.sh copies everything to /workspace (a mounted
# Docker volume with plenty of space) before invoking live-build.
COPY config/ /build-config/config/
COPY build-iso.sh /build-config/build-iso.sh

# live-build expects auto/ at the top level of the working directory.
RUN cp -r /build-config/config/auto /build-config/auto

# Ensure scripts are executable
RUN chmod +x /build-config/build-iso.sh \
    && chmod +x /build-config/auto/config \
    && find /build-config/config/hooks -name '*.hook.chroot' -exec chmod +x {} +

ENTRYPOINT ["bash", "/build-config/build-iso.sh"]
