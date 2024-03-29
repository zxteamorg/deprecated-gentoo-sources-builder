[![Docker Build Status](https://img.shields.io/docker/build/zxteamorg/gentoo-sources-builder?label=Status)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/builds)
[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/zxteamorg/gentoo-sources-builder?label=Size)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/tags)
[![Docker Pulls](https://img.shields.io/docker/pulls/zxteamorg/gentoo-sources-builder?label=Pulls)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder)
[![Docker Image Version (latest by date)](https://img.shields.io/docker/v/zxteamorg/gentoo-sources-builder?sort=semver&label=Version)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/tags)
[![Docker Image Info](https://images.microbadger.com/badges/image/zxteamorg/gentoo-sources-builder.svg)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/dockerfile)

# Gentoo Sources Builder

This image based on Gentoo stage3 with additionally emerged packages to make abillity to compile Gentoo Sources Kernel in few commands on a Docker Host.


## What the image includes

TBD

## Dev notes

### Prepare builder images

#### Option: Pull image

  * ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/i686/X.Y.Z
  * ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/i686/X.Y.Z:master
  * ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/i686/X.Y.Z:master.xxxxxx
  * ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/amd64/X.Y.Z
  * ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/amd64/X.Y.Z:master
  * ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/amd64/X.Y.Z:master.xxxxxx

where `X.Y.Z` is kernel version.

For example:
```shell
docker pull ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/amd64/5.15.52
```

#### Option: Build locally yourself

```shell
export KERNEL_VERSION=5.15.75
export KERNEL_VERSION=5.10.150

docker build --platform=i386 --tag "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/i686/${KERNEL_VERSION}" --build-arg KERNEL_VERSION --file "docker/i686/Dockerfile" .

docker build --platform=amd64 --tag "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/amd64/${KERNEL_VERSION}" --build-arg KERNEL_VERSION --file "docker/amd64/Dockerfile" .
```

### Use the image

```shell
export KERNEL_VERSION=5.15.75
export KERNEL_VERSION=5.10.150

# Select arch
#export ARCH=i686
export ARCH=amd64

# Select SITE
#export SITE=27K51EA#A2Q
#export SITE=ASRockPV530
#export SITE=B2G18EC#ABA
#export SITE=C3C58ES#AKD
#export SITE=D4H65EC#AKD
#export SITE=DELLCS24SC
#export SITE=H5E56ET#ABU
#export SITE=VirtualBoxGuest
#export SITE=zxtower00 #axx99v102a
#export SITE=zxtower04 #Fujitsu

# -- DEPRECATED --
#export SITE=asusx402ca
#export SITE=digitaloceanvm
#export SITE=qemu
# ----------------
```


# Create cache volume
```shell
docker volume create "${KERNEL_VERSION}-${ARCH}-$(echo ${SITE} | sed 's/#/_/g')-cache"
```

# Create work directory
```shell
mkdir ".${SITE}"
```

# Make Kernel
```shell
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${KERNEL_VERSION}-${ARCH}-$(echo ${SITE} | sed 's/#/_/g')-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/${KERNEL_VERSION}" \
    menuconfig
```

You may want to save kernel cfg changes into our Gentoo Overlay
```shell
cp .${SITE}/boot/config-${KERNEL_VERSION}-gentoo-${SITE} gentoo-overlay/profiles/${SITE}/kernel.config
```

```shell
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${KERNEL_VERSION}-${ARCH}-$(echo ${SITE} | sed 's/#/_/g')-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/${KERNEL_VERSION}" \
    kernel
```

# Make initramfs
```shell
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${KERNEL_VERSION}-${ARCH}-$(echo ${SITE} | sed 's/#/_/g')-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/${KERNEL_VERSION}" \
    initramfs
```

# Cleanup
```shell
docker volume rm "${KERNEL_VERSION}-${ARCH}-$(echo ${SITE} | sed 's/#/_/g')-cache"
```


### Develop initramfs

To develop and debug `init` script you may attach `initramfs/init` file into container

```shell
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/initramfs/init",target=/support/initramfs/init \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${KERNEL_VERSION}-${ARCH}-$(echo ${SITE} | sed 's/#/_/g')-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/${KERNEL_VERSION}" \
    initramfs
```
