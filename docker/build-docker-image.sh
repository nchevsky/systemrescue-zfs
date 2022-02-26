#!/bin/bash

# Parameters
architecture="x86_64"
dockerimg="sysrescuebuildiso-${architecture}:latest"

# Determine the path to the git repository
fullpath="$(realpath $0)"
curdir="$(dirname ${fullpath})"
repodir="$(realpath ${curdir}/..)"
tmpdir="${repodir}/docker/tmpfiles"
echo "fullpath=${fullpath}"
echo "repodir=${repodir}"

# Copy configuration files
mkdir -p ${tmpdir}
cp -a ${repodir}/pacman.conf ${tmpdir}

# Build the docker image
docker build -t ${dockerimg} -f ${repodir}/docker/Dockerfile-build-iso-${architecture} ${repodir}/docker

# Cleanup
rm -rf ${tmpdir}
