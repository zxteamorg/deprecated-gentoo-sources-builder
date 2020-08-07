ARG GENTOO_DOCKER_BUILD_DATE=20200806


# Use the empty image with the portage tree as the first stage
FROM gentoo/portage:${GENTOO_DOCKER_BUILD_DATE} AS portage


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM gentoo/stage3-x86:${GENTOO_DOCKER_BUILD_DATE} as stage
ARG KERNEL_VERSION=

# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db

# Install kernel sources
RUN test -z "${KERNEL_VERSION}" && { echo "KERNEL_VERSION is not set" >&2; exit 1; } || true
RUN emerge --quiet =sys-kernel/gentoo-sources-${KERNEL_VERSION}

# We need busybox to embed into initramfs
# We need cpio to pack initramfs
# We need LVM to embed into initramfs
RUN echo "sys-firmware/intel-microcode intel-ucode" >> /etc/portage/package.license
RUN echo "sys-kernel/linux-firmware linux-fw-redistributable no-source-code" >> /etc/portage/package.license
RUN FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" USE="bindist static static-libs" emerge --quiet app-arch/cpio sys-apps/busybox sys-firmware/intel-microcode sys-fs/cryptsetup sys-fs/lvm2 sys-kernel/linux-firmware

RUN eselect kernel set 1

RUN rm -rf /var/db
RUN rm -rf /usr/share/man

RUN cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs_list.sh

RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf

# === Sites ==============================================================

## zxteam-bootsrv
COPY sites/zxteam-bootsrv-asrock-pv530a-itx/i686/config-${KERNEL_VERSION}-gentoo /support/zxteam-bootsrv-asrock-pv530a-itx/config-${KERNEL_VERSION}-gentoo

## zxteam-desktop-hp64xx
#COPY sites/zxteam-desktop-hp64xx/i686/config-${KERNEL_VERSION}-gentoo           /support/zxteam-desktop-hp64xx/config-${KERNEL_VERSION}-gentoo

# ========================================================================

# Initramfs
COPY initramfs/init                                 /support/initramfs/init
COPY initramfs/initramfs_list.i686                  /support/initramfs/initramfs_list


COPY BANNER /support/BANNER
COPY misc /support/misc
RUN echo "${KERNEL_VERSION}" > /support/KERNEL_VERSION
COPY docker/docker-entrypoint.sh /support/docker-entrypoint.sh

#FROM scratch
#COPY --from=stage / /
VOLUME [ "/data" ]
ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
