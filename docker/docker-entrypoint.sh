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

if [ ! -d "/data/usr/src/linux-${KERNEL_VERSION}-gentoo" ]; then
	echo "Creating kernel build directory /data/usr/src/linux-${KERNEL_VERSION}-gentoo..."
	mkdir -p "/data/usr/src/linux-${KERNEL_VERSION}-gentoo"
fi
if [ ! -d /data/boot ]; then
	echo "Creating boot directory /data/boot..."
	mkdir /data/boot
fi


if [ -n "${SITE}" ]; then
	echo "Using SITE: ${SITE}"

	if [ ! -f "/data/usr/src/linux-${KERNEL_VERSION}-gentoo/.config" ]; then
		if [ -f "/support/${SITE}/config-${KERNEL_VERSION}-gentoo" ]; then
			echo "Initialize kernel configuration..."
			cp "/support/${SITE}/config-${KERNEL_VERSION}-gentoo" "/data/usr/src/linux-${KERNEL_VERSION}-gentoo/.config"
		else
			echo "Cannot initialize kernel configuration due a file /support/${SITE}/config-${KERNEL_VERSION}-gentoo not found."
		fi
	fi

else
	echo "Skip config initialization due SITE variable is not set."
fi

if [ ! -d "/data/usr/src/initramfs" ]; then
	if [ -d "/support/initramfs" ]; then
		echo "Initialize initramfs configuration..."
		cp -a "/support/initramfs" "/data/usr/src/initramfs"
	else
		echo "Cannot initialize initramfs configuration due a directory /support/initramfs not found."
	fi
fi


function config_kernel() {
	cd /usr/src/linux
	KBUILD_OUTPUT="/data/usr/src/linux-${KERNEL_VERSION}-gentoo" make menuconfig
}

function build_kernel() {
	# Check that kernel config has correct settings for initramfs
	if ! grep 'CONFIG_RD_GZIP=y' "/data/usr/src/linux-${KERNEL_VERSION}-gentoo/.config" >/dev/null 2>&1; then
		echo "Kernel configuration must include CONFIG_RD_GZIP=y" >&2
		exit 1
	fi

	cd "/usr/src/linux-${KERNEL_VERSION}-gentoo"
	KBUILD_OUTPUT="/data/usr/src/linux-${KERNEL_VERSION}-gentoo" make "-j$(nproc)"
	KBUILD_OUTPUT="/data/usr/src/linux-${KERNEL_VERSION}-gentoo" INSTALL_PATH=/data/boot make install
	if grep 'CONFIG_MODULES=y' "/data/usr/src/linux-${KERNEL_VERSION}-gentoo/.config" >/dev/null 2>&1; then
		KBUILD_OUTPUT="/data/usr/src/linux-${KERNEL_VERSION}-gentoo" make "-j$(nproc)" modules
		KBUILD_OUTPUT="/data/usr/src/linux-${KERNEL_VERSION}-gentoo" INSTALL_MOD_PATH="/data" make modules_install
	fi
	if [ -n "${SITE}" ]; then
		ln -sf "vmlinuz-${KERNEL_VERSION}-gentoo-${SITE}" /data/boot/vmlinuz
	else
		ln -sf "vmlinuz-${KERNEL_VERSION}-gentoo" /data/boot/vmlinuz
	fi
}

function build_initramfs() {
	local CPIO_LIST=$(mktemp)
	cat "/data/usr/src/initramfs/initramfs_list" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"
	echo "file /etc/group /support/misc/group 644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/nsswitch.conf /support/misc/nsswitch.conf 644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/passwd /support/misc/passwd 644 0 0" >> "${CPIO_LIST}"
	echo "file /init /data/usr/src/initramfs/init 755 0 0" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"
	echo "# Modules" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"

	if [ -d "/data/lib/modules" ]; then
		cd "/data/lib/modules"
		for n in $(find *); do
			echo "Adding module $n..."
			[ -d $n ] && echo "dir /lib/modules/$n 700 0 0" >> "${CPIO_LIST}"
			[ -f $n ] && echo "file /lib/modules/$n /data/lib/modules/$n 600 0 0" >> "${CPIO_LIST}"
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

	cd "/usr/src/linux-${KERNEL_VERSION}-gentoo"

	local INITRAMFS_FILE=
	if [ -n "${SITE}" ]; then
		INITRAMFS_FILE="initramfs-${KERNEL_VERSION}-gentoo-${SITE}"
	else
		INITRAMFS_FILE="initramfs-${KERNEL_VERSION}-gentoo"
	fi

	./usr/gen_initramfs_list.sh -o "/data/boot/${INITRAMFS_FILE}.cpio.gz" "${CPIO_LIST}"
	ln -sf "${INITRAMFS_FILE}.cpio.gz" /data/boot/initramfs.cpio.gz

	# # Debugging
	# echo "Unpack final image into ./boot.debug/${INITRAMFS_FILE}"
	# [ -d "/data/boot.debug/${INITRAMFS_FILE}" ] && rm -rf "/data/boot.debug/${INITRAMFS_FILE}"
	# mkdir -p "/data/boot.debug/${INITRAMFS_FILE}"
	# cd "/data/boot.debug/${INITRAMFS_FILE}"
	# zcat "/data/boot/${INITRAMFS_FILE}.cpio.gz" | cpio --extract
	# exec chroot . /bin/busybox sh -i

	#exec /bin/busybox sh
}


case "$1" in
	config)
		config_kernel
		;;
	kernel)
		config_kernel
		build_kernel
		;;
	initramfs)
		build_initramfs
		;;
	all)
		config_kernel
		build_kernel
		build_initramfs
		;;
	*)
		echo >&2
		echo "	Available quick commands: 'config', 'kernel', 'initramfs' and 'all'" >&2
		echo >&2
		echo >&2
		exec /bin/bash $*
		;;
esac
