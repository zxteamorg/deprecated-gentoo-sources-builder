# https://hub.docker.com/r/gentoo/stage3
# gentoo/stage3:x86-20210820 -> DIGEST:sha256:0b8b2cc912674417028490c5acd33199d40cae2e94b0fa4e2853a9297154eb9f
ARG GENTOO_STAGE3_IMAGE_DIGEST=sha256:0b8b2cc912674417028490c5acd33199d40cae2e94b0fa4e2853a9297154eb9f

# https://hub.docker.com/r/gentoo/portage
# gentoo/portage:20210824 -> DIGEST:sha256:7aec3cb9a1bc645e3485c2cfad698a443cdab583a8f4b12da28c2bcb57467c07
ARG GENTOO_PORTAGE_IMAGE_DIGEST=sha256:7aec3cb9a1bc645e3485c2cfad698a443cdab583a8f4b12da28c2bcb57467c07

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

VOLUME [ "/data/build", "/data/cache" ]

ENV SITE=

ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
