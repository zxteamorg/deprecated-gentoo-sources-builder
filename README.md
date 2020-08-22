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
#export ARCH=i686
export ARCH=amd64
#export SITE=asrock-pv530a-itx
export SITE=dellcs24sc
#export SITE=hp64xx
docker build --tag "zxteamorg/gentoo-sources-builder-${ARCH}" --build-arg KERNEL_VERSION=5.4.48 --file docker/amd64/Dockerfile .
docker volume create "${SITE}-cache"
docker run --rm --interactive --tty --volume "${PWD}/.${SITE}":/data/build --volume "${SITE}-cache":/data/cache --env SITE "zxteamorg/gentoo-sources-builder-${ARCH}" kernel
docker run --rm --interactive --tty --volume "${PWD}/.${SITE}":/data/build --volume "${SITE}-cache":/data/cache --env SITE --env CLEAN_INITRAMFS=y "zxteamorg/gentoo-sources-builder-${ARCH}" initramfs
```

### Debug initramfs of `hp64xx` site

```
docker build --tag zxteamorg/gentoo-sources-builder-amd64 --build-arg KERNEL_VERSION=5.4.48 --file docker/amd64/Dockerfile . && \
rm -rf $PWD/.hp64xx/usr/src/initramfs && \
docker run --rm --interactive --tty --env SITE=hp64xx --volume $PWD/.hp64xx:/data zxteamorg/gentoo-sources-builder-amd64 initramfs
```

### Debug initramfs of `asrock-pv530a-itx` site

```
docker build --tag zxteamorg/gentoo-sources-builder-i686 --build-arg KERNEL_VERSION=5.4.48 --file docker/i686/Dockerfile . && \
rm -rf $PWD/.v/usr/src/initramfs && \
docker run --rm --interactive --tty --env SITE=asrock-pv530a-itx --volume $PWD/.asrock-pv530a-itx:/data zxteamorg/gentoo-sources-builder-i686 initramfs
```

### Debug initramfs of `dellcs24sc` site

```
docker build --tag zxteamorg/gentoo-sources-builder-amd64 --build-arg KERNEL_VERSION=5.4.48 --file docker/amd64/Dockerfile . && \
rm -rf $PWD/.dellcs24sc/usr/src/initramfs && \
docker run --rm --interactive --tty --env SITE=dellcs24sc --volume $PWD/.dellcs24sc:/data zxteamorg/gentoo-sources-builder-amd64 initramfs
```
