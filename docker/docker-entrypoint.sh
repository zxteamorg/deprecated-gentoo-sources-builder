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
	mkdir -p /data/cache/usr/src
fi

if [ ! -d /data/build/boot ]; then
	echo "Creating boot directory /data/build/boot..."
	mkdir /data/build/boot
fi


function config_kernel() {
	if [ ! -d "/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo" ]; then
		echo "Creating kernel build directory /data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo..."
		mkdir -p "/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo"
	fi

	if [ -n "${SITE}" ]; then
		echo "Using SITE: ${SITE}"

		if [ ! -f "/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo/.config" ]; then

			LATEST_SITE_KERNEL_CONFIG_FILE=$(ls --reverse "/support/sites/${SITE}"/config-*-gentoo| head -1)
			if [ -f "${LATEST_SITE_KERNEL_CONFIG_FILE}" ]; then
				echo "Initialize kernel configuration..."
				cp "${LATEST_SITE_KERNEL_CONFIG_FILE}" "/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo/.config"
			else
				echo "Cannot initialize kernel configuration due a file /support/sites/${SITE}/config-${KERNEL_VERSION}-gentoo not found."
			fi
		fi
	else
		echo "Skip config initialization due SITE variable is not set."
	fi

	cd /usr/src/linux
	if [ -f ".config" ]; then
		KBUILD_OUTPUT="/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo" make oldconfig
	fi
	KBUILD_OUTPUT="/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo" make menuconfig
}

function build_kernel() {
	# Check that kernel config has correct settings for initramfs
	if ! grep 'CONFIG_RD_GZIP=y' "/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo/.config" >/dev/null 2>&1; then
		echo "Kernel configuration must include CONFIG_RD_GZIP=y" >&2
		exit 1
	fi

	cd "/usr/src/linux-${KERNEL_VERSION}-gentoo"
	KBUILD_OUTPUT="/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo" make "-j$(nproc)"
	KBUILD_OUTPUT="/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo" INSTALL_PATH=/data/build/boot make install
	if grep 'CONFIG_MODULES=y' "/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo/.config" >/dev/null 2>&1; then
		KBUILD_OUTPUT="/data/cache/usr/src/linux-${KERNEL_VERSION}-gentoo" INSTALL_MOD_PATH=/data/cache make modules_install

		if [ -n "${SITE}" ]; then
			cd /data/cache
			tar -czpf "/data/build/lib-modules-${KERNEL_VERSION}-gentoo-${SITE}.tar.gz" lib/modules
		else
			cd /data/cache
			tar -czpf "/data/build/lib-modules-${KERNEL_VERSION}-gentoo.tar.gz" lib/modules
		fi
	fi
	if [ -n "${SITE}" ]; then
		ln -sf "System.map-${KERNEL_VERSION}-gentoo-${SITE}" /data/build/boot/System.map
		ln -sf "config-${KERNEL_VERSION}-gentoo-${SITE}" /data/build/boot/config
		ln -sf "vmlinuz-${KERNEL_VERSION}-gentoo-${SITE}" /data/build/boot/vmlinuz
		cd /data/cache && tar -czpf "/data/build/lib-modules-${KERNEL_VERSION}-gentoo-${SITE}.tar.gz" lib/modules
	else
		ln -sf "System.map-${KERNEL_VERSION}-gentoo" /data/build/boot/System.map
		ln -sf "config-${KERNEL_VERSION}-gentoo" /data/build/boot/config
		ln -sf "vmlinuz-${KERNEL_VERSION}-gentoo" /data/build/boot/vmlinuz
		cd /data/cache && tar -czpf "/data/build/lib-modules-${KERNEL_VERSION}-gentoo.tar.gz" lib/modules
	fi
}

function build_initramfs() {
	echo "Building initramfs..."

	if [ -d /data/cache/usr/src/initramfs ]; then
		rm -rf /data/cache/usr/src/initramfs
	fi
	if [ -d /support/initramfs ]; then
		echo "Initialize initramfs configuration..."
		cp -a /support/initramfs /data/cache/usr/src/initramfs
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

	cd "/usr/src/linux-${KERNEL_VERSION}-gentoo"

	local INITRAMFS_FILE=
	if [ -n "${SITE}" ]; then
		INITRAMFS_FILE="initramfs-${KERNEL_VERSION}-gentoo-${SITE}"
	else
		INITRAMFS_FILE="initramfs-${KERNEL_VERSION}-gentoo"
	fi

	echo "Generating initramfs file ${INITRAMFS_FILE}.cpio.gz..."
	./usr/gen_initramfs_list.sh -o "/data/build/boot/${INITRAMFS_FILE}.cpio.gz" "${CPIO_LIST}"
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
		exec /bin/busybox sh -c "$*"
		;;
esac
