# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY assets /assets/
COPY thirdparty /thirdparty/
COPY cosign.pub /

# Base Image
FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable@sha256:d8743773b84627d376ae168cc9807e8f27849ad345d075dd1201617f833de5df as rootfs-base

ARG IMAGE_COMMIT_ID
ARG GITHUB_REF_NAME
ARG GPU_FAMILY=generic

ENV IMAGE_COMMIT_ID=${IMAGE_COMMIT_ID}
ENV GITHUB_REF_NAME=${GITHUB_REF_NAME}

### BASE IMAGE SETUP
# General changes done to the base image
RUN --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/var \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/prepare-rootfs.sh

# Replace Fedora's systemd-boot with our signed one
#COPY --from=systemd-boot /systemd-bootx64.efi /usr/lib/systemd/boot/efi/systemd-bootx64.efi

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/scripts/dracut-config.sh

### BUILD INITRD
# Rebuild the initramfs and move kernel to the root    
FROM rootfs-base as initrd
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/scripts/rebuild-initrd.sh
RUN mv /usr/lib/modules/*/vmlinuz /vmlinuz    

# Remove the kernel and initrd from the base image
FROM rootfs-base as rootfs
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/scripts/remove-kernel-initrd.sh

# Rechunk container image to ensure that we compute the correct composefs hash
# - Use more layers (128)
# - Ignore legacy ostree folders
FROM quay.io/coreos/chunkah AS chunkah
RUN --mount=from=rootfs,src=/,target=/chunkah,ro \
    --mount=type=bind,src=/tmp,target=/tmp,rw \
        chunkah build \
            --max-layers 256 \
            --prune /ostree \
            --prune /sysroot/ostree \
            --output oci:/tmp/chunkah-out

### FINAL IMAGE BEFORE HASH
# Create the final base image from the rechunked oci output
FROM oci:/tmp/chunkah-out as rootfs-chunked
RUN --mount=type=bind,from=chunkah,src=/,target=/run/target,ro \
    export CHUNKAH_DEPENDENCY_RESOLVED=true
LABEL containers.bootc 1
LABEL org.opencontainers.image.title="Deimos"
LABEL org.opencontainers.image.source="https://github.com/bsingh-kpt/deimos"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL quay.expires-after="4w"
ENV container=oci
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]

### LINTING
## Verify final image and contents are correct.
# Make sure we pass the lints
FROM rootfs-base as lint
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=rootfs-chunked,src=/,target=/tmp/target,ro \
    /ctx/scripts/bootc-container-lint.sh

### UKIFY
# Build and sign UKI OR sign during deployment
FROM rootfs-base as sealed-uki
# Copy kernel & initramfs from earlier stage
COPY --from=initrd /vmlinuz /vmlinuz
COPY --from=initrd /initramfs /initramfs
RUN mkdir -p /tmp/uki-build-scratch /tmp/build-vartmp
RUN --mount=type=tmpfs,target=/run \
    --mount=type=bind,src=/tmp/uki-build-scratch,target=/tmp,rw \
    --mount=type=bind,src=/tmp/build-vartmp,target=/var/tmp,rw \
    --mount=type=bind,from=rootfs-chunked,src=/,target=/mnt/target,ro \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/scripts/uki.sh

### FINAL IMAGE
# Copy UKI to our final image
FROM rootfs-chunked as final
COPY --from=sealed-uki /boot/EFI/Linux /boot/EFI/Linux
