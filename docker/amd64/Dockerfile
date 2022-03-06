# https://hub.docker.com/r/gentoo/stage3
# gentoo/stage3:amd64-openrc-20220306 -> DIGEST:sha256:e97bf00db6717f278ebf772e965b6fa6a8068226f89ba4b895a719da4ed98d11
ARG GENTOO_STAGE3_IMAGE_DIGEST=sha256:e97bf00db6717f278ebf772e965b6fa6a8068226f89ba4b895a719da4ed98d11

# https://hub.docker.com/r/gentoo/portage
# gentoo/portage:20220306 -> DIGEST:sha256:99528388a6e5cfe25f79bee2ec908650bc5a4910d983048b0d47cc5a50850a89
ARG GENTOO_PORTAGE_IMAGE_DIGEST=sha256:99528388a6e5cfe25f79bee2ec908650bc5a4910d983048b0d47cc5a50850a89

# Use the empty image with the portage tree as the first stage
FROM gentoo/portage@${GENTOO_PORTAGE_IMAGE_DIGEST} AS portage


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM --platform=amd64 gentoo/stage3@${GENTOO_STAGE3_IMAGE_DIGEST} as stage
ARG KERNEL_VERSION=

# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db

RUN echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
RUN echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox"' >> /etc/portage/make.conf
RUN echo 'EMERGE_DEFAULT_OPTS="--jobs 3"' >> /etc/portage/make.conf
RUN echo "MAKEOPTS=\"-j$(nproc)\"" >> /etc/portage/make.conf

RUN cat /etc/portage/make.conf

# Install kernel sources
RUN test -n "${KERNEL_VERSION}" || { echo "KERNEL_VERSION is not set" >&2; exit 1; }
RUN \
	emerge --quiet =sys-kernel/gentoo-sources-${KERNEL_VERSION}

# We need udev to embed into initramfs
RUN \
	emerge --quiet \
		sys-fs/udev

# We need intel-microcode and linux-firmware to bundle microcode. See more https://wiki.gentoo.org/wiki/Microcode
RUN \
	emerge --quiet \
		sys-firmware/intel-microcode \
		sys-kernel/linux-firmware

# We need busybox to embed into initramfs
RUN \
	USE="-pam" \
	emerge --quiet \
		sys-apps/busybox

# We need cpio to pack initramfs
# We need mdadm to embed into initramfs
RUN \
	USE="-pam static static-libs" \
	emerge --quiet \
		app-arch/cpio \
		sys-fs/mdadm

# We need LVM to embed into initramfs
RUN \
	USE="readline thin udev" \
	emerge --quiet \
		sys-fs/lvm2

# We need cryptsetup to embed into initramfs
RUN \
	USE="openssl udev" \
	emerge --quiet \
		sys-fs/cryptsetup

# We need dropbear to embed into initramfs
RUN \
	ACCEPT_KEYWORDS="~amd64" \
	USE="minimal -pam -shadow static static-libs -syslog" \
	emerge --quiet \
		dropbear

# GPT disk tools
RUN \
	emerge --quiet \
		sys-apps/gptfdisk \
		sys-block/parted

# strace
RUN \
	emerge --quiet \
		dev-util/strace

RUN eselect kernel set 1

RUN cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs.sh

RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf

COPY BANNER /support/BANNER
COPY misc /support/misc
RUN echo "${KERNEL_VERSION}" > /support/KERNEL_VERSION
RUN echo "amd64" > /support/IMAGE_ARCH

# === Sites ==============================================================
COPY sites/amd64/                                   /support/sites/
# ========================================================================

# Initramfs
COPY initramfs/init                                 /support/initramfs/init
COPY initramfs/initramfs_list.amd64                 /support/initramfs/initramfs_list
COPY initramfs/uncrypt                              /support/initramfs/uncrypt

COPY docker/docker-entrypoint.sh /support/docker-entrypoint.sh

RUN \
  rm -rf /run/*; \
  rm -rf /tmp/*; \
  rm -rf /usr/share/man; \
  rm -rf /var/cache/*; \
  rm -rf /var/db/*; \
  rm -rf /var/log/*; \
  rm -rf /var/tmp/*

FROM scratch
COPY --from=stage / /
VOLUME [ "/data/build", "/data/cache" ]
ENV SITE=
ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
