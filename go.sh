#!/bin/bash
#
# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/igorpecovnik/hostapd
#


[[ $MAINTAINER == "" ]] && MAINTAINER="Igor Pecovnik"                                   # deb signature
[[ $MAINTAINERMAIL == "" ]] && MAINTAINERMAIL="igor.pecovnik@****l.com"                 # deb signature
[[ $REVISION == "" ]] && REVISION="1.1"
[[ $ARCHITECTURE == "" ]] && ARCHITECTURE=$(dpkg --print-architecture)
[[ $SRC == "" ]] && SRC=$(pwd)

#--------------------------------------------------------------------------------------------------------------------------------
# Set prerequisities and cleanup
#--------------------------------------------------------------------------------------------------------------------------------

CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS="-j$(($CPUS + $CPUS/2))";
rm -f build.log hostapd-custom*.deb


#--------------------------------------------------------------------------------------------------------------------------------
# Download some dependencies
#--------------------------------------------------------------------------------------------------------------------------------
echo -e "[\e[0;32m o.k. \x1B[0m] Building hostapd$TARGET"
echo -e "[\e[0;32m o.k. \x1B[0m] Downloading dependencies."
apt-get -qq -y install build-essential pkg-config libnl-3-dev libssl-dev libnl-genl-3-dev patchutils libnl*


download ()
{
#--------------------------------------------------------------------------------------------------------------------------------
# Download latest hostapd sources
#--------------------------------------------------------------------------------------------------------------------------------
if [ -d "$SRC/hostap" ]; then
		cd $SRC/hostap
		git checkout -f -q master >> ../build.log 2>&1
		git pull -q
		echo -e "[\e[0;32m o.k. \x1B[0m] Updating sources."
	else
		git clone -q http://w1.fi/hostap.git >> ../build.log 2>&1
fi
}

checkout ()
{
#--------------------------------------------------------------------------------------------------------------------------------
# Choose stable branch if selected
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$1" == "stable" ]; then
	cd $SRC/hostap
	git checkout -f -q "hostap_2_5" >> ../build.log 2>&1
	else
	git checkout -f -q >> ../build.log 2>&1
fi
}

compiling ()
{
#--------------------------------------------------------------------------------------------------------------------------------
# Compile
#--------------------------------------------------------------------------------------------------------------------------------
make clean >/dev/null 2>&1
echo -e "[\e[0;32m o.k. \x1B[0m] Compiling v$VERSION""$1."
make >> ../../build.log 2>&1
if [ $? -ne 0 ] || [ ! -f $SRC/hostap/hostapd/hostapd ]; then
	echo -e "[\e[0;31m err. \x1B[0m] hostapd not built."
        exit 1
fi
}

# download inside chroot fails
if [ "$(stat -c %d:%i /)" == "$(stat -c %d:%i /proc/1/root/.)" ]; then
download
checkout "stable"
fi

packing ()
{
#--------------------------------------------------------------------------------------------------------------------------------
# Pack to deb. Replacec files in original package
#--------------------------------------------------------------------------------------------------------------------------------
if [[ $1 == "-realtek" ]]; then REPLACES="hostapd-custom"; else REPLACES="hostapd-custom-realtek"; fi
cd $SRC
apt-get -qq -d install hostapd
dpkg-deb -R /var/cache/apt/archives/hostapd* hostapd-custom$1${TARGET}"_"${REVISION}_${ARCHITECTURE}
# set up control file
cat <<END > hostapd-custom$1${TARGET}_${REVISION}_${ARCHITECTURE}/DEBIAN/control
Package: hostapd-custom$1$TARGET
Version: $REVISION
Architecture: $ARCHITECTURE
Maintainer: $MAINTAINER <$MAINTAINERMAIL>
Installed-Size: 1
Section: kernel
Conflicts: hostapd
Replaces: hostapd,hostapd-custom,hostapd-custom-realtek
Priority: optional
Description: Sources: https://github.com/igorpecovnik/hostapd
END
#

cp "$SRC/hostap/hostapd/hostapd" "$SRC/hostap/hostapd/hostapd_cli" hostapd-custom$1${TARGET}_${REVISION}_${ARCHITECTURE}/usr/sbin
cp $SRC/hostapd.conf/*.conf hostapd-custom$1${TARGET}_${REVISION}_${ARCHITECTURE}/etc
cd hostapd-custom$1${TARGET}_${REVISION}_${ARCHITECTURE}
find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '%P ' | xargs md5sum > DEBIAN/md5sums
cd ..
dpkg -b hostapd-custom$1${TARGET}_${REVISION}_${ARCHITECTURE} >/dev/null 2>&1
rm -rf hostapd-custom$1${TARGET}_${REVISION}_${ARCHITECTURE}
echo -e "[\e[0;32m o.k. \x1B[0m] All done. Hostapd is packed into: hostapd-custom$1${TARGET}_${REVISION}_${ARCHITECTURE}.deb"
}



#--------------------------------------------------------------------------------------------------------------------------------
# Copy Driver interface for rtl871x driver
#--------------------------------------------------------------------------------------------------------------------------------
# Read version
VERSION=$(cat $SRC/hostap/src/common/version.h | grep "#define VERSION_STR " | awk '{ print $3 }' | sed 's/\"//g')
cd $SRC/hostap/
for i in $SRC/patch/*.patch; do
	lsdiff -s --strip=1 $i | grep '^+' | awk '{print $2}' | xargs -I % sh -c 'rm -f %'
	patch -p1 -s --batch < $i
	if [ $? -ne 0 ]; then echo -e "[\e[0;31m err. \x1B[0m] hostapd not built."; exit 1; fi
done
cp $SRC/config/config_realtek $SRC/hostap/hostapd/.config
cd hostapd
compiling
packing
checkout "stable"
cd $SRC/hostap/
rm -f src/drivers/driver_rtl.h src/drivers/driver_rtw.c
patch --batch -f -p1 < $SRC/patch/realtek/rtlxdrv.patch >> ../build.log 2>&1
cp $SRC/config/config_realtek $SRC/hostap/hostapd/.config
cp $SRC/files/*.* $SRC/hostap/src/drivers/
cd hostapd
compiling " realtek"
packing "-realtek"