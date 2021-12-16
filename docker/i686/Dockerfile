# https://hub.docker.com/r/gentoo/stage3
# gentoo/stage3:x86-20211215 -> DIGEST:sha256:e19a0f27353ff408c10ec4cff4b6a0e10f0d4b6ae7007c67990219a8ddae3cf2
ARG GENTOO_STAGE3_IMAGE_DIGEST=sha256:e19a0f27353ff408c10ec4cff4b6a0e10f0d4b6ae7007c67990219a8ddae3cf2

# https://hub.docker.com/r/gentoo/portage
# gentoo/portage:20211215 -> DIGEST:sha256:b70c0a36ffddc72ae41cbb09145def09c4c392cd348289e5e04b797bff3f3784
ARG GENTOO_PORTAGE_IMAGE_DIGEST=sha256:b70c0a36ffddc72ae41cbb09145def09c4c392cd348289e5e04b797bff3f3784

# Use the empty image with the portage tree as the first stage
FROM gentoo/portage@${GENTOO_PORTAGE_IMAGE_DIGEST} AS portage


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM --platform=386 gentoo/stage3@${GENTOO_STAGE3_IMAGE_DIGEST} as stage
ARG KERNEL_VERSION=

# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db

# Install kernel sources
RUN test -n "${KERNEL_VERSION}" || { echo "KERNEL_VERSION is not set" >&2; exit 1; }
RUN \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	emerge --quiet =sys-kernel/gentoo-sources-${KERNEL_VERSION}

# We need udev to embed into initramfs
RUN \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	emerge --quiet --oneshot \
		sys-fs/udev

# We need intel-microcode and linux-firmware to bundle microcode. See more https://wiki.gentoo.org/wiki/Microcode
RUN \
	ACCEPT_LICENSE="intel-ucode linux-fw-redistributable no-source-code" \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	emerge --quiet --oneshot \
		sys-firmware/intel-microcode \
		sys-kernel/linux-firmware

# We need busybox to embed into initramfs
# We need cpio to pack initramfs
# We need mdadm to embed into initramfs
RUN \
	ACCEPT_LICENSE="intel-ucode linux-fw-redistributable no-source-code" \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	USE="-pam static static-libs" \
	emerge --quiet --oneshot \
		app-arch/cpio \
		sys-apps/busybox \
		sys-fs/mdadm

# We need LVM to embed into initramfs
RUN \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	USE="readline thin udev" \
	emerge --quiet --oneshot \
		sys-fs/lvm2

# We need cryptsetup to embed into initramfs
RUN \
	FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" \
	USE="openssl udev" \
	emerge --quiet --oneshot \
		sys-fs/cryptsetup

# We need dropbear to embed into initramfs
RUN \
	ACCEPT_KEYWORDS="~x86" \
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
RUN echo "i686" > /support/IMAGE_ARCH

RUN rm -rf /var/db
RUN rm -rf /usr/share/man

# === Sites ==============================================================
COPY sites/i686/                                    /support/sites/
# ========================================================================

# Initramfs
COPY initramfs/init                                 /support/initramfs/init
COPY initramfs/initramfs_list.i686                  /support/initramfs/initramfs_list
COPY initramfs/uncrypt                              /support/initramfs/uncrypt

COPY docker/docker-entrypoint.sh /support/docker-entrypoint.sh


FROM scratch
COPY --from=stage / /
VOLUME [ "/data/build", "/data/cache" ]
ENV SITE=
ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
