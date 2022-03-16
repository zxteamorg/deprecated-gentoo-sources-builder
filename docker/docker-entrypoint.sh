#!/bin/bash
#

set -e

if [ ! -f /support/IMAGE_ARCH ]; then
	echo "Look like you have wrong build container. The container should present a file /support/IMAGE_ARCH"
	exit 1
fi
IMAGE_ARCH=$(cat /support/IMAGE_ARCH)
if [ -z "${IMAGE_ARCH}" ]; then
	echo "Look like you have wrong build container. The container should present a file /support/IMAGE_ARCH with proper arch value."
	exit 1
fi

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

	if [ -n "${SITE}" ]; then
		cp --verbose "${KBUILD_OUTPUT}/.config" "/data/build/boot/config-${KERNEL_SLUG}-${SITE}"
	else
		cp --verbose "${KBUILD_OUTPUT}/.config" "/data/build/boot/config-${KERNEL_SLUG}"
	fi
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

	case "${IMAGE_ARCH}" in
		i686)
			KERNEL_ARCH=x86
			;;
		*)
			KERNEL_ARCH=x86_64
			;;
	esac
	if [ -n "${SITE}" ]; then
		cp --verbose "${KBUILD_OUTPUT}/System.map"                       "/data/build/boot/System.map-${KERNEL_SLUG}-${SITE}"
		cp --verbose "${KBUILD_OUTPUT}/.config"                          "/data/build/boot/config-${KERNEL_SLUG}-${SITE}"
		cp --verbose "${KBUILD_OUTPUT}/arch/${KERNEL_ARCH}/boot/bzImage" "/data/build/boot/vmlinuz-${KERNEL_SLUG}-${SITE}"
	else
		cp --verbose "${KBUILD_OUTPUT}/System.map"                       "/data/build/boot/System.map-${KERNEL_SLUG}"
		cp --verbose "${KBUILD_OUTPUT}/.config"                          "/data/build/boot/config-${KERNEL_SLUG}"
		cp --verbose "${KBUILD_OUTPUT}/arch/${KERNEL_ARCH}/boot/bzImage" "/data/build/boot/vmlinuz-${KERNEL_SLUG}"
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
	echo "file /etc/ld.so.conf /etc/ld.so.conf 644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/nsswitch.conf /support/misc/nsswitch.conf 644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/passwd /support/misc/passwd 644 0 0" >> "${CPIO_LIST}"
	echo "file /init /data/cache/usr/src/initramfs/init 755 0 0" >> "${CPIO_LIST}"
	echo "file /uncrypt /data/cache/usr/src/initramfs/uncrypt 755 0 0" >> "${CPIO_LIST}"
	echo "dir /usr/share/udhcpc 755 0 0" >> "${CPIO_LIST}"
	echo "file /usr/share/udhcpc/default.script /usr/share/udhcpc/default.script 755 0 0" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"


	echo "# Software" >> "${CPIO_LIST}"
	SOFT_ITEMS=""

	# Busybox
	SOFT_ITEMS="${SOFT_ITEMS} /bin/busybox"

	# Strace
	SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/strace"

	# Curl requires for stratum download
	SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/curl"

	# Filesystem tools
	SOFT_ITEMS="${SOFT_ITEMS} /sbin/e2fsck /sbin/fsck /sbin/fsck.ext4 /sbin/mke2fs /sbin/mkfs /sbin/mkfs.ext4 /sbin/resize2fs"

	# Disk partition tools
	SOFT_ITEMS="${SOFT_ITEMS} /sbin/fdisk /sbin/sfdisk /usr/sbin/gdisk /usr/sbin/parted"

	# LVM stuff
	SOFT_ITEMS="${SOFT_ITEMS} /sbin/dmsetup /sbin/lvm /sbin/lvcreate /sbin/lvdisplay /sbin/lvextend /sbin/lvremove /sbin/lvresize /sbin/lvs /sbin/pvcreate /sbin/pvdisplay /sbin/pvresize /sbin/vgchange /sbin/vgcreate /sbin/vgdisplay /sbin/vgextend /sbin/vgscan"
	echo "dir /etc/lvm 755 0 0" >> "${CPIO_LIST}"
	echo "file /etc/lvm/lvm.conf /etc/lvm/lvm.conf 644 0 0" >> "${CPIO_LIST}"

	# Tool for running RAID systems
	SOFT_ITEMS="${SOFT_ITEMS} /sbin/mdadm"
	echo "file /etc/mdadm.conf /support/misc/mdadm.conf 644 0 0" >> "${CPIO_LIST}"

	# Cryptsetup
	SOFT_ITEMS="${SOFT_ITEMS} /sbin/cryptsetup"

	# Dropbear SSH Server
	SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/dbclient /usr/bin/dropbearkey /usr/sbin/dropbear"

	# UDEV (See for udevd location indise init script /etc/init.d/udev)
	SOFT_ITEMS="${SOFT_ITEMS} /bin/udevadm"
	echo "slink /bin/udevd /bin/udevadm 755 0 0" >> "${CPIO_LIST}"

	case "${IMAGE_ARCH}" in
		amd64)
			ELF_IGNORE="linux-vdso"
			;;
		i686)
			ELF_IGNORE="linux-gate"
			;;
		*)
			echo "Unsupported IMAGE_ARCH: ${IMAGE_ARCH}" >&2
			exit 62
			;;
	esac

	declare -a LIB_ITEMS

	# libgcc_s.so.1 for cryptsetup
	case "${IMAGE_ARCH}" in
		amd64)
			echo "file /lib64/libgcc_s.so.1 /usr/lib/gcc/x86_64-pc-linux-gnu/11.2.0/libgcc_s.so.1 755 0 0" >> "${CPIO_LIST}"
			;;
		i686)
			echo "file /lib/libgcc_s.so.1 /usr/lib/gcc/i686-pc-linux-gnu/11.2.0/libgcc_s.so.1 755 0 0" >> "${CPIO_LIST}"
			;;
	esac

	for SOFT_ITEM in ${SOFT_ITEMS}; do
		if [ -e "${SOFT_ITEM}" ]; then
			if [ ! -L "${SOFT_ITEM}" ]; then
				declare -a DIRECT_LIBS_ARRAY=($(ldd "${SOFT_ITEM}" 2>/dev/null | grep -v "${ELF_IGNORE}" | grep -v '=>' | awk '{print $1}'))
				declare -a LINKED_LIBS_ARRAY=($(ldd "${SOFT_ITEM}" 2>/dev/null | grep '=>' | awk '{print $3}'))
				for LIB in ${DIRECT_LIBS_ARRAY[@]} ${LINKED_LIBS_ARRAY[@]}; do
					if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${LIB}"); then
						LIB_ITEMS+=("${LIB}")
					fi

					if [ -L "${LIB}" ]; then
						TARGET_LIB=$(readlink -f "${LIB}")
						if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${TARGET_LIB}"); then
							LIB_ITEMS+=("${TARGET_LIB}")
						fi
					fi
				done
			fi
		else
			echo "Bad soft file: ${SOFT_ITEM}" >&2
			exit 2
		fi
	done

	for NSSLIB in $(ls -1 /lib/libnss_*); do
		if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${NSSLIB}"); then
			LIB_ITEMS+=("${NSSLIB}")
		fi
	done

	for RESOLVLIB in $(ls -1 /lib/libresolv*); do
		if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${RESOLVLIB}"); then
			LIB_ITEMS+=("${RESOLVLIB}")
		fi
	done

	for LIB_ITEM in ${LIB_ITEMS[@]}; do
		if [ -e "${LIB_ITEM}" ]; then
			# # Right now pass all libs as files (without symlinks)
		 	# echo "file ${LIB_ITEM} ${LIB_ITEM} 755 0 0" >> "${CPIO_LIST}"

			if [ -L "${LIB_ITEM}" ]; then
				TARGET_LIB_ITEM=$(readlink -f "${LIB_ITEM}")
				echo "slink ${LIB_ITEM} ${TARGET_LIB_ITEM} 755 0 0" >> "${CPIO_LIST}"
			else
				echo "file ${LIB_ITEM} ${LIB_ITEM} 755 0 0" >> "${CPIO_LIST}"
			fi
		else
			echo "Bad soft file: ${LIB_ITEM}" >&2
			exit 2
		fi
	done

	for SOFT_ITEM in ${SOFT_ITEMS}; do
		if [ -e "${SOFT_ITEM}" ]; then
			if [ -L "${SOFT_ITEM}" ]; then
				TARGET_SOFT_ITEM=$(readlink -f "${SOFT_ITEM}")
				echo "slink ${SOFT_ITEM} ${TARGET_SOFT_ITEM} 755 0 0" >> "${CPIO_LIST}"
			else
				echo "file ${SOFT_ITEM} ${SOFT_ITEM} 755 0 0" >> "${CPIO_LIST}"
			fi
		else
			echo "Bad soft file: ${SOFT_ITEM}" >&2
			exit 2
		fi
	done

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

	cp "${CPIO_LIST}" "/data/build/boot/${INITRAMFS_FILE}.cpiolist"

	echo "Generating initramfs file ${INITRAMFS_FILE}.cpio.gz..."
	./usr/gen_initramfs.sh -o "/data/build/boot/${INITRAMFS_FILE}.cpio" "${CPIO_LIST}"
	gzip -9 -f -k "/data/build/boot/${INITRAMFS_FILE}.cpio"
	ln -sf "${INITRAMFS_FILE}.cpio.gz" /data/build/boot/initramfs.cpio.gz

	# Double check initramfs integrity by unpack
	echo "Unpack final image into ./boot.debug/${INITRAMFS_FILE}"
	[ -d "/data/cache/boot.debug/${INITRAMFS_FILE}" ] && rm -rf "/data/cache/boot.debug/${INITRAMFS_FILE}"
	mkdir -p "/data/cache/boot.debug/${INITRAMFS_FILE}"
	cd "/data/cache/boot.debug/${INITRAMFS_FILE}"
	zcat "/data/build/boot/${INITRAMFS_FILE}.cpio.gz" | cpio --extract

	# Debugging
	# mount --bind /dev ./dev
	# chroot . /bin/busybox sh -i

	# exec /bin/busybox sh
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

