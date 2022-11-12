# https://hub.docker.com/r/gentoo/stage3
# gentoo/stage3:amd64-openrc-20221107
ARG GENTOO_STAGE3_IMAGE_DIGEST=sha256:36390fac588a1d85f70d7d71ae2fcf2dbac3a7a48c37fdc40fcde96824b88e77

# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM --platform=linux/amd64 gentoo/stage3@${GENTOO_STAGE3_IMAGE_DIGEST} as stage
ARG KERNEL_VERSION=

RUN emerge-webrsync

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
		net-wireless/wireless-regdb \
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
	USE="minimal -pam -shadow static static-libs -syslog" \
	emerge --quiet \
		net-misc/dropbear

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

RUN \
  rm -rf /run/*; \
  rm -rf /tmp/*; \
  rm -rf /usr/share/man; \
  rm -rf /var/cache/*; \
  rm -rf /var/db/*; \
  rm -rf /var/log/*; \
  rm -rf /var/tmp/*

RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf

COPY BANNER /support/BANNER
COPY misc /support/misc
RUN echo "${KERNEL_VERSION}" > /support/KERNEL_VERSION
RUN echo "amd64" > /support/IMAGE_ARCH

# Initramfs
COPY initramfs/init                                 /support/initramfs/init
COPY initramfs/initramfs_list.amd64                 /support/initramfs/initramfs_list
COPY initramfs/uncrypt                              /support/initramfs/uncrypt

COPY docker/docker-entrypoint.sh /support/docker-entrypoint.sh

# === Profiles ==============================================================
COPY gentoo-overlay/                                   /support/gentoo-overlay/
# ===========================================================================


FROM --platform=linux/amd64 scratch
COPY --from=stage / /
VOLUME [ "/data/build", "/data/cache" ]
ENV SITE=
ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
