# https://hub.docker.com/r/gentoo/stage3
# gentoo/stage3:amd64-20210725 -> DIGEST:sha256:ddc8cd57ab62dedb384a440d4e98e5f07897983811b0fa497d8642ad02579134
ARG GENTOO_STAGE3_IMAGE_DIGEST=sha256:ddc8cd57ab62dedb384a440d4e98e5f07897983811b0fa497d8642ad02579134

# https://hub.docker.com/r/gentoo/portage
# gentoo/portage:20210725 -> DIGEST:sha256:36087d3148dbf052562b970bb263a786fa05bc316f427fed898aa0dce06095fc
ARG GENTOO_PORTAGE_IMAGE_DIGEST=sha256:36087d3148dbf052562b970bb263a786fa05bc316f427fed898aa0dce06095fc

# Use the empty image with the portage tree as the first stage
FROM gentoo/portage@${GENTOO_PORTAGE_IMAGE_DIGEST} AS portage


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM --platform=amd64 gentoo/stage3@${GENTOO_STAGE3_IMAGE_DIGEST} as stage
ARG KERNEL_VERSION=

# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db

# Install kernel sources
RUN test -n "${KERNEL_VERSION}" || { echo "KERNEL_VERSION is not set" >&2; exit 1; }
RUN \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	emerge --quiet =sys-kernel/gentoo-sources-${KERNEL_VERSION}

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
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	emerge --quiet --oneshot \
		dropbear

RUN eselect kernel set 1

RUN cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs.sh

RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf

COPY BANNER /support/BANNER
COPY misc /support/misc
RUN echo "${KERNEL_VERSION}" > /support/KERNEL_VERSION

RUN rm -rf /var/db
RUN rm -rf /usr/share/man

# === Sites ==============================================================
COPY sites/amd64/                                   /support/sites/
# ========================================================================

# Initramfs
COPY initramfs/init                                 /support/initramfs/init
COPY initramfs/initramfs_list.amd64                 /support/initramfs/initramfs_list
COPY initramfs/uncrypt                              /support/initramfs/uncrypt

COPY docker/docker-entrypoint.sh /support/docker-entrypoint.sh

VOLUME [ "/data/build", "/data/cache" ]

ENV SITE=

ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
