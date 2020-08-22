ARG GENTOO_DOCKER_BUILD_DATE=20200820


# Use the empty image with the portage tree as the first stage
FROM gentoo/portage:${GENTOO_DOCKER_BUILD_DATE} AS portage


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM gentoo/stage3-amd64:${GENTOO_DOCKER_BUILD_DATE} as stage
ARG KERNEL_VERSION=

# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db

# Install kernel sources
RUN test -n "${KERNEL_VERSION}" || { echo "KERNEL_VERSION is not set" >&2; exit 1; }
RUN emerge --quiet =sys-kernel/gentoo-sources-${KERNEL_VERSION}

# We need busybox to embed into initramfs
# We need cpio to pack initramfs
# We need LVM to embed into initramfs
RUN \
	ACCEPT_LICENSE="intel-ucode linux-fw-redistributable no-source-code" \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	USE="bindist static static-libs" \
	emerge --quiet --oneshot \
		app-arch/cpio \
		sys-apps/busybox \
		sys-firmware/intel-microcode \
		sys-fs/cryptsetup \
		sys-fs/lvm2 \
		sys-fs/mdadm \
		sys-kernel/linux-firmware

RUN \
	ACCEPT_KEYWORDS="~amd64" \
	USE="minimal -pam -shadow static static-libs -syslog" \
	emerge --quiet --oneshot \
		dropbear

RUN eselect kernel set 1

RUN cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs_list.sh

RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf

COPY BANNER /support/BANNER
COPY misc /support/misc
RUN echo "${KERNEL_VERSION}" > /support/KERNEL_VERSION

RUN rm -rf /var/db
RUN rm -rf /usr/share/man

# === Sites ==============================================================

## hp64xx
COPY sites/hp64xx/amd64/config-${KERNEL_VERSION}-gentoo                        /support/hp64xx/config-${KERNEL_VERSION}-gentoo

# dellcs24sc
COPY sites/dellcs24sc/amd64/config-${KERNEL_VERSION}-gentoo                    /support/dellcs24sc/config-${KERNEL_VERSION}-gentoo

# ========================================================================

# Initramfs
COPY initramfs/init                                 /support/initramfs/init
COPY initramfs/initramfs_list.amd64                 /support/initramfs/initramfs_list
COPY initramfs/uncrypt                              /support/initramfs/uncrypt

COPY docker/docker-entrypoint.sh /support/docker-entrypoint.sh

VOLUME [ "/data/build", "/data/cache" ]
ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
