[![Docker Build Status](https://img.shields.io/docker/build/zxteamorg/gentoo-sources-builder?label=Status)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/builds)
[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/zxteamorg/gentoo-sources-builder?label=Size)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/tags)
[![Docker Pulls](https://img.shields.io/docker/pulls/zxteamorg/gentoo-sources-builder?label=Pulls)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder)
[![Docker Image Version (latest by date)](https://img.shields.io/docker/v/zxteamorg/gentoo-sources-builder?sort=semver&label=Version)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/tags)
[![Docker Image Info](https://images.microbadger.com/badges/image/zxteamorg/gentoo-sources-builder.svg)](https://hub.docker.com/r/zxteamorg/gentoo-sources-builder/dockerfile)

# Gentoo Sources Builder

This image based on Gentoo stage3 with additionally emerged packages to make abillity to compile Gentoo Sources Kernel in few commands on a Docker Host.


## Quick Start

```bash
docker run --rm --interactive --tty --volume $(pwd):/data [--env SITE=hp64xx] zxteamorg/gentoo-sources-builder kernel
```

See directory `sites` for the SITE variable.

## What the image includes

TBD



## Dev notes

```
# Define arch
#export ARCH=i686
export ARCH=amd64

# Build image
docker build --tag "zxteamorg/gentoo-sources-builder-${ARCH}" --build-arg KERNEL_VERSION=5.4.97 --file "docker/${ARCH}/Dockerfile" .

# Define SITE
#export SITE=asrockpv530aitx
#export SITE=axx99v102a
export SITE=dellcs24sc
#export SITE=hp64xx

# Create cache volume
docker volume create "${SITE}-cache"

# Make Kernel
docker run --rm --interactive --tty --volume "${PWD}/.${SITE}":/data/build --volume "${SITE}-cache":/data/cache --env SITE "zxteamorg/gentoo-sources-builder-${ARCH}" kernel

# Make initramfs
docker run --rm --interactive --tty --volume "${PWD}/.${SITE}":/data/build --volume "${SITE}-cache":/data/cache --env SITE --env CLEAN_INITRAMFS=y "zxteamorg/gentoo-sources-builder-${ARCH}" initramfs


# Cleanup
docker volume rm "${SITE}-cache"
docker image rm "zxteamorg/gentoo-sources-builder-${ARCH}"
```
