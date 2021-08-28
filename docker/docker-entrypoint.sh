#!/bin/bash
#

set -e

if [ ! -f /support/KERNEL_VERSION ]; then
	echo "Look like you have wrong build container. The container should present a file /support/KERNEL_VERSION"
	exit 1
fi
KERNEL_VERSION=$(cat /support/KERNEL_VERSION)
if [ -z "${KERNEL_VERSION}" ]; then
	echo "Look like you have wrong build container. The container should present a file /support/KERNEL_VERSION with proper kernel version."
	exit 1
fi

if [ ! -d /data/cache/usr/src ]; then
	echo "Creating directory /data/cache/usr/src..."
	mkdir --parents /data/cache/usr/src
fi

if [ ! -d /data/build/boot ]; then
	echo "Creating boot directory /data/build/boot..."
	mkdir /data/build/boot
fi

cd /usr/src/linux
KERNEL_SLUG=$(basename $(pwd -LP) | cut -d- -f2-)

export KBUILD_OUTPUT="/data/cache/usr/src/linux-${KERNEL_SLUG}"


function initconfig_kernel() {
	if [ ! -d "${KBUILD_OUTPUT}" ]; then
		echo "Creating kernel build directory ${KBUILD_OUTPUT}..."
		mkdir --parents "${KBUILD_OUTPUT}"
	fi

	if [ -n "${SITE}" ]; then
		echo "Using SITE: ${SITE}"

		if [ ! -f "${KBUILD_OUTPUT}/.config" ]; then

			LATEST_SITE_KERNEL_CONFIG_FILE=$(ls "/support/sites/${SITE}"/config-*-gentoo-* | sort -rV | head -1)
			if [ -f "${LATEST_SITE_KERNEL_CONFIG_FILE}" ]; then
				echo "Initialize kernel configuration from ${LATEST_SITE_KERNEL_CONFIG_FILE} ..."
				cp "${LATEST_SITE_KERNEL_CONFIG_FILE}" "${KBUILD_OUTPUT}/.config"
			else
				echo "Cannot initialize kernel configuration due a file /support/sites/${SITE}/config-${KERNEL_SLUG} not found."
			fi
		fi
	else
		echo "Skip config initialization due SITE variable is not set."
	fi

	if [ -f "${KBUILD_OUTPUT}/.config" ]; then
		make oldconfig
	fi
}

function menuconfig_kernel() {
	initconfig_kernel

	make menuconfig
}

function build_kernel() {
	# Check that kernel config has correct settings for initramfs
	if ! grep 'CONFIG_RD_GZIP=y' "${KBUILD_OUTPUT}/.config" >/dev/null 2>&1; then
		echo "Kernel configuration must include CONFIG_RD_GZIP=y" >&2
		exit 1
	fi

	make "-j$(nproc)"

	# INSTALL_PATH=/data/build/boot make install
	# Copy artifacts to /boot directory instead "make install"
	if [ -n "${SITE}" ]; then
		cp --verbose "${KBUILD_OUTPUT}/System.map"               "/data/build/boot/System.map-${KERNEL_SLUG}-${SITE}"
		cp --verbose "${KBUILD_OUTPUT}/.config"                  "/data/build/boot/config-${KERNEL_SLUG}-${SITE}"
		cp --verbose "${KBUILD_OUTPUT}/arch/x86_64/boot/bzImage" "/data/build/boot/vmlinuz-${KERNEL_SLUG}-${SITE}"
	else
		cp --verbose "${KBUILD_OUTPUT}/System.map"               "/data/build/boot/System.map-${KERNEL_SLUG}"
		cp --verbose "${KBUILD_OUTPUT}/.config"                  "/data/build/boot/config-${KERNEL_SLUG}"
		cp --verbose "${KBUILD_OUTPUT}/arch/x86_64/boot/bzImage" "/data/build/boot/vmlinuz-${KERNEL_SLUG}"
	fi

	if grep 'CONFIG_MODULES=y' "${KBUILD_OUTPUT}/.config" >/dev/null 2>&1; then
		INSTALL_MOD_PATH=/data/cache make modules_install

		# rm /data/cache/lib/modules/${KERNEL_SLUG}/build
		# rm /data/cache/lib/modules/${KERNEL_SLUG}/source

		if [ -n "${SITE}" ]; then
			cd /data/cache && tar --create --gzip --preserve-permissions --file="/data/build/lib-modules-${KERNEL_SLUG}-${SITE}.tar.gz" lib/modules
		else
			cd /data/cache && tar --create --gzip --preserve-permissions --file="/data/build/lib-modules-${KERNEL_SLUG}.tar.gz"         lib/modules
		fi
	fi

	if [ -n "${SITE}" ]; then
		ln --symbolic --force "System.map-${KERNEL_SLUG}-${SITE}" /data/build/boot/System.map
		ln --symbolic --force "config-${KERNEL_SLUG}-${SITE}" /data/build/boot/config
		ln --symbolic --force "vmlinuz-${KERNEL_SLUG}-${SITE}" /data/build/boot/vmlinuz
	else
		ln --symbolic --force "System.map-${KERNEL_SLUG}" /data/build/boot/System.map
		ln --symbolic --force "config-${KERNEL_SLUG}" /data/build/boot/config
		ln --symbolic --force "vmlinuz-${KERNEL_SLUG}" /data/build/boot/vmlinuz
	fi
}

function build_initramfs() {
	echo "Building initramfs..."

	if [ -d /data/cache/usr/src/initramfs ]; then
		rm --force --recursive /data/cache/usr/src/initramfs
	fi
	if [ -d /support/initramfs ]; then
		echo "Initialize initramfs configuration..."
		cp --archive /support/initramfs /data/cache/usr/src/initramfs
	else
		echo "Cannot initialize initramfs configuration due a directory /support/initramfs not found."
	fi

	local CPIO_LIST=$(mktemp)
	cat "/data/cache/usr/src/initramfs/initramfs_list" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"
	echo "file /etc/group /support/misc/group 644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/mdadm.conf /support/misc/mdadm.conf 644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/nsswitch.conf /support/misc/nsswitch.conf 644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/passwd /support/misc/passwd 644 0 0" >> "${CPIO_LIST}"
	echo "file /init /data/cache/usr/src/initramfs/init 755 0 0" >> "${CPIO_LIST}"
	echo "file /uncrypt /data/cache/usr/src/initramfs/uncrypt 755 0 0" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"
	echo "# Modules" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"

	if [ -d "/data/cache/lib/modules" ]; then
		cd "/data/cache/lib/modules"
		for n in $(find *); do
			echo "Adding module $n..."
			[ -d $n ] && echo "dir /lib/modules/$n 700 0 0" >> "${CPIO_LIST}"
			[ -f $n ] && echo "file /lib/modules/$n /data/cache/lib/modules/$n 600 0 0" >> "${CPIO_LIST}"
		done
	fi

	echo >> "${CPIO_LIST}"
	find /lib/udev -type d | while read D; do
		echo "dir $D 755 0 0" >> "${CPIO_LIST}"
	done
	find /lib/udev -type f | while read F; do 
		MODE=$(stat -c %a $F)
		echo "file $F $F $MODE 0 0" >> "${CPIO_LIST}"
	done

	cd "/usr/src/linux"

	local INITRAMFS_FILE=
	if [ -n "${SITE}" ]; then
		INITRAMFS_FILE="initramfs-${KERNEL_SLUG}-${SITE}"
	else
		INITRAMFS_FILE="initramfs-${KERNEL_SLUG}"
	fi

	echo "Generating initramfs file ${INITRAMFS_FILE}.cpio.gz..."
	./usr/gen_initramfs.sh -o "/data/build/boot/${INITRAMFS_FILE}.cpio.gz" "${CPIO_LIST}"
	ln -sf "${INITRAMFS_FILE}.cpio.gz" /data/build/boot/initramfs.cpio.gz

	# # Debugging
	# echo "Unpack final image into ./boot.debug/${INITRAMFS_FILE}"
	# [ -d "/data/cache/boot.debug/${INITRAMFS_FILE}" ] && rm -rf "/data/cache/boot.debug/${INITRAMFS_FILE}"
	# mkdir -p "/data/cache/boot.debug/${INITRAMFS_FILE}"
	# cd "/data/cache/boot.debug/${INITRAMFS_FILE}"
	# zcat "/data/build/boot/${INITRAMFS_FILE}.cpio.gz" | cpio --extract
	# exec chroot . /bin/busybox sh -i

	#exec /bin/busybox sh
}

if [ -z "$1" ]; then
	exec /bin/busybox sh
fi

case "$1" in
	initconfig)
		initconfig_kernel
		;;
	menuconfig)
		menuconfig_kernel
		;;
	kernel)
		build_kernel
		;;
	initramfs)
		build_initramfs
		;;
	all)
		menuconfig_kernel
		build_kernel
		build_initramfs
		;;
	*)
		echo >&2
		echo "	Available quick commands: 'initconfig', 'menuconfig', 'kernel', 'initramfs' and 'all'" >&2
		echo >&2
		echo >&2
		exec /bin/busybox sh -c "$*"
		;;
esac
