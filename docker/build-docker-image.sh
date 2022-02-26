#!/bin/bash

# Parameters validation
if [ -z "${sysrescuearch}" ] ; then
    echo "ERROR: You must define the environment variable 'sysrescuearch' as either 'x86_64' or 'i686' before you run this script"
    exit 1
fi

if [ "${sysrescuearch}" != "x86_64" ] && [ "${sysrescuearch}" != "i686" ] ; then
    echo "Value '${sysrescuearch}' is invalid for environment variable 'sysrescuearch'. Only 'x86_64' and 'i686' are supported"
    exit 1
fi

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
dockerimg="sysrescuebuildiso-${sysrescuearch}:latest"
docker build -t ${dockerimg} -f ${repodir}/docker/Dockerfile-build-iso-${sysrescuearch} ${repodir}/docker

# Cleanup
rm -rf ${tmpdir}
