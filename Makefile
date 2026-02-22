.PHONY: build-linux install-binaries build-iso all run-qemu clean

# The four Rust binaries shipped inside the AIOS ISO.
# aios-memory and aios-voice are excluded from the ISO build.
AIOS_BINS := aios-agent aios-chat aios-dock aios-confirm
BIN_DIR   := iso/config/includes.chroot/usr/local/bin

# -----------------------------------------------------------------------
# Build Rust binaries for Linux x86_64 inside a Debian Trixie container.
# Docker volumes persist the Cargo registry and build cache across runs
# to avoid full recompilation on every invocation.
# Only the four ISO-targeted binaries are compiled.
# -----------------------------------------------------------------------
build-linux:
	docker build -t aios-rust-builder -f iso/Dockerfile.build .
	docker run --rm \
		-v "$(PWD)":/src \
		-v aios-cargo-cache:/root/.cargo/registry \
		-v aios-cargo-git:/root/.cargo/git \
		-v aios-target-cache:/src/target \
		aios-rust-builder \
		cargo build --release \
			$(addprefix -p ,$(AIOS_BINS))

# -----------------------------------------------------------------------
# Copy the compiled binaries from the Docker build-cache volume into the
# live-build includes tree so they appear at /usr/local/bin inside the ISO.
# -----------------------------------------------------------------------
install-binaries:
	mkdir -p $(BIN_DIR)
	docker run --rm \
		-v aios-target-cache:/src/target:ro \
		-v "$(PWD)/$(BIN_DIR)":/output \
		debian:trixie \
		sh -c 'cp $(addprefix /src/target/release/,$(AIOS_BINS)) /output/'
	@echo "Installed binaries:"
	@ls -lh $(BIN_DIR)/aios-*

# -----------------------------------------------------------------------
# Build the Debian Live ISO image.
# Must be preceded by build-linux + install-binaries so the binaries
# are present inside iso/config/includes.chroot before live-build runs.
# -----------------------------------------------------------------------
build-iso:
	docker build --platform linux/amd64 -t aios-iso-builder iso/
	mkdir -p output
	docker run --rm --privileged --platform linux/amd64 \
		-v "$(PWD)/output":/output \
		-v aios-iso-work:/workspace \
		aios-iso-builder

# -----------------------------------------------------------------------
# Full pipeline: compile binaries -> stage into ISO tree -> build ISO.
# -----------------------------------------------------------------------
all: build-linux install-binaries build-iso

# -----------------------------------------------------------------------
# Boot the built ISO in QEMU for smoke-testing without real hardware.
# Requires: qemu-system-x86_64 installed on the host (brew install qemu).
#
# On macOS there is no KVM; we use software emulation (TCG).
# To use Apple HVF acceleration add: -accel hvf
# On Linux with KVM support add:     -enable-kvm
# -----------------------------------------------------------------------
run-qemu:
	qemu-system-x86_64 \
		-cdrom output/live-image-amd64.hybrid.iso \
		-m 4G \
		-smp 2 \
		-device virtio-vga \
		-display default \
		-boot d

# -----------------------------------------------------------------------
# Remove Docker volumes that hold the Cargo and build caches, and delete
# any previously generated ISO files from the output directory.
# -----------------------------------------------------------------------
clean:
	docker volume rm aios-cargo-cache aios-cargo-git aios-target-cache aios-iso-work 2>/dev/null || true
	rm -rf output/*.iso
	rm -f $(BIN_DIR)/aios-*
