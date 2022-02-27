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

# Make sure the docker image exists
dockerimg="sysrescuebuildiso-${sysrescuearch}:latest"
if ! docker inspect ${dockerimg} >/dev/null 2>/dev/null ; then
    echo "ERROR: You must build the following docker image before you run this script: ${dockerimg}"
    exit 1
fi

# Determine the path to the git repository
fullpath="$(realpath $0)"
curdir="$(dirname ${fullpath})"
repodir="$(realpath ${curdir}/..)"
echo "curdir=${curdir}"
echo "repodir=${repodir}"

# Create a tmpfs for storing packages cache in memory
pkgcache="/tmp/pkgcache"
echo "pkgcache=${pkgcache}"
mkdir -p ${pkgcache}
if ! findmnt ${pkgcache} >/dev/null; then
    echo "Mounting ${pkgcache} as a tmpfs"
    sudo mount -t tmpfs tmpfs -o size=2G ${pkgcache}
fi

# Run the build process in the container
docker run --rm --user 0:0 --privileged -it --workdir /workspace \
    --volume=${repodir}:/workspace \
    --volume=${pkgcache}:/var/cache/pacman/pkg \
    ${dockerimg} setarch ${sysrescuearch} /bin/bash /workspace/build.sh "$@"
