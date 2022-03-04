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
docker pull ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/amd64/5.10.100
```

#### Option: Build locally yourself

```shell
docker build --platform=i386 --tag "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/i686/5.10.100" --build-arg KERNEL_VERSION=5.10.100 --file "docker/i686/Dockerfile" .

docker build --platform=amd64 --tag "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/amd64/5.10.100" --build-arg KERNEL_VERSION=5.10.100 --file "docker/amd64/Dockerfile" .
```

### Use the image

```shell
# Select arch
#export ARCH=i686
export ARCH=amd64

# Select SITE
#export SITE=asrockpv530aitx
#export SITE=asusx402ca
#export SITE=axx99v102a
#export SITE=dellcs24sc
export SITE=digitaloceanvm
#export SITE=hp64xx
#export SITE=virtualboxvm

# Create cache volume
docker volume create "${ARCH}-${SITE}-cache"

# Create work directory
mkdir ".${SITE}"

# Make Kernel
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${ARCH}-${SITE}-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/5.10.100" \
    menuconfig
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${ARCH}-${SITE}-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/5.10.100" \
    kernel


# Make initramfs
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${ARCH}-${SITE}-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/5.10.100" \
    initramfs


# Cleanup
docker volume rm "${ARCH}-${SITE}-cache"
```


### Develop initramfs

To develop and debug `init` script you may attach `initramfs/init` file into container

```shell
docker run --rm --interactive --tty \
  --mount type=bind,source="${PWD}/initramfs/init",target=/support/initramfs/init \
  --mount type=bind,source="${PWD}/.${SITE}",target=/data/build \
  --volume "${ARCH}-${SITE}-cache":/data/cache \
  --env SITE \
  "ghcr.io/zxteamorg/deprecated-gentoo-sources-builder/${ARCH}/5.10.100" \
    initramfs
```