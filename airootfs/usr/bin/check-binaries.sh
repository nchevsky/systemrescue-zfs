#!/bin/bash
errcnt=0

for curfile in /usr/bin/{*btrfs*,*xfs*,dislocker*,udp*,dump,restore} \
               /usr/bin/{ghex,growpart*,hardinfo,*lshw*,ms-sys,nwipe,whdd,zerofree} \
               /opt/firefox*/firefox* \
               /usr/lib/ntfs-3g/ntfs-plugin*.so \
               /usr/lib/libgbm.so* \
               /usr/lib/xorg/modules/drivers/modesetting_drv.so \
               /usr/lib/libdislocker.so*
do
    test -x ${curfile} || continue
    file --mime ${curfile} | grep -q -E "x-pie-executable|x-sharedlib" || continue

    if ldd ${curfile} | grep -q -F 'not found'
    then
        echo "ERROR: Program ${curfile} is missing libraries"
        ldd ${curfile}
        errcnt=$((errcnt + 1))
    fi

done

# check for missing programs
# mkpasswd might be packaged separately from whois in the future
for curfile in /usr/bin/mkpasswd ; \
do
   if ! [[ -x "${curfile}" ]]; then
        echo "ERROR: Program ${curfile} is missing"
        errcnt=$((errcnt + 1))
    fi
done

if [ ${errcnt} -eq 0 ]
then
    echo "SUCCESS: Have not found any missing library or program"
    exit 0
else
    echo "FAILURE: Have found ${errcnt} issues"
    exit 1
fi
