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
[[ $REVISION == "" ]] && REVISION="1.0"
[[ $ARCHITECTURE == "" ]] && ARCHITECTURE=$(dpkg --print-architecture)


#--------------------------------------------------------------------------------------------------------------------------------
# Set prerequisities and cleanup
#--------------------------------------------------------------------------------------------------------------------------------
SRC=$(pwd)
CPUS=$(grep -c 'processor' /proc/cpuinfo) 
CTHREADS="-j$(($CPUS + $CPUS/2))"; 
rm -f build.log
rm -f hostapd-armbian*.deb


#--------------------------------------------------------------------------------------------------------------------------------
# Download some dependencies
#--------------------------------------------------------------------------------------------------------------------------------
echo -e "[\e[0;32m o.k. \x1B[0m] Building hostapd$TARGET"
echo -e "[\e[0;32m o.k. \x1B[0m] Downloading dependencies."
apt-get -qq -y install libnl-3-dev libssl-dev libnl-genl-3-dev


#--------------------------------------------------------------------------------------------------------------------------------
# Download latest hostapd sources 
#--------------------------------------------------------------------------------------------------------------------------------
if [ -d "$SRC/hostap" ]; then
		cd $SRC/hostap
		git checkout -f -q master >> ../build.log 2>&1
		git pull -q
		echo -e "[\e[0;32m o.k. \x1B[0m] Updating sources."
	else
		git clone -q git://w1.fi/hostap.git >> ../build.log 2>&1 
fi


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
# Read version
VERSION=$(cat $SRC/hostap/src/common/version.h | grep "#define VERSION_STR " | awk '{ print $3 }' | sed 's/\"//g')
}

#--------------------------------------------------------------------------------------------------------------------------------
# Copy Driver interface for rtl871x driver
#--------------------------------------------------------------------------------------------------------------------------------
cp $SRC/files/*.* $SRC/hostap/src/drivers/
cd $SRC/hostap/





patching ()
{
#--------------------------------------------------------------------------------------------------------------------------------
# Patching
#
# Other usefull patches:
# https://dev.openwrt.org/browser/trunk/package/network/services/hostapd/patches?order=name
#--------------------------------------------------------------------------------------------------------------------------------
# brute force for 40Mhz
if [ "$(patch --dry-run -t -p1 < $SRC/patch/300-noscan.patch | grep previ)" == "" ]; then
	patch --batch -f -p1 < $SRC/patch/300-noscan.patch >> ../build.log 2>&1
fi
# patch for realtek
if [ "$1" == "-realtek" ]; then
		cp $SRC/config/config_realtek $SRC/hostap/hostapd/.config
		patch --batch -f -p1 < $SRC/patch/realtek.patch >> ../build.log 2>&1
	else
		cp $SRC/config/config_default $SRC/hostap/hostapd/.config
		if [ "$(cat $SRC/hostap/hostapd/main.c | grep rtl871)" != "" ]; then
			patch --batch -t -p1 < $SRC/patch/realtek.patch >> ../build.log 2>&1
		fi
fi
}

compiling ()
{
#--------------------------------------------------------------------------------------------------------------------------------
# Compile
#--------------------------------------------------------------------------------------------------------------------------------
make clean >/dev/null 2>&1
echo -e "[\e[0;32m o.k. \x1B[0m] Compiling v$VERSION""$1."
make $CTHREADS >> ../../build.log 2>&1
if [ $? -ne 0 ] || [ ! -f $SRC/hostap/hostapd/hostapd ]; then
	echo -e "[\e[0;31m err. \x1B[0m] hostapd not built."
        exit 1
fi
}

checkout "stable"

cd hostapd
patching "-realtek"
compiling " for Realteks"
mv "$SRC/hostap/hostapd/hostapd" $SRC/hostap/hostapd/hostapd-rt
mv "$SRC/hostap/hostapd/hostapd_cli" $SRC/hostap/hostapd/hostapd_cli-rt
patching ""
compiling

#--------------------------------------------------------------------------------------------------------------------------------
# Pack to deb. Replacec files in original package
#--------------------------------------------------------------------------------------------------------------------------------
cd $SRC
apt-get -qq -d install hostapd
dpkg-deb -R /var/cache/apt/archives/hostapd* hostapd-armbian${TARGET}"_"${REVISION}_${ARCHITECTURE}

# set up control file
cat <<END > hostapd-armbian${TARGET}_${REVISION}_${ARCHITECTURE}/DEBIAN/control
Package: hostapd-armbian$TARGET
Version: $REVISION
Architecture: $ARCHITECTURE
Maintainer: $MAINTAINER <$MAINTAINERMAIL>
Installed-Size: 1
Section: kernel
Conflicts: hostapd
Priority: optional
Description: Sources: https://github.com/igorpecovnik/hostapd
END
#

cp "$SRC/hostap/hostapd/hostapd" "$SRC/hostap/hostapd/hostapd-rt" "$SRC/hostap/hostapd/hostapd_cli" "$SRC/hostap/hostapd/hostapd_cli-rt"  hostapd-armbian${TARGET}_${REVISION}_${ARCHITECTURE}/usr/sbin
cp $SRC/hostapd.conf/*.conf hostapd-armbian${TARGET}_${REVISION}_${ARCHITECTURE}/etc
cd hostapd-armbian${TARGET}_${REVISION}_${ARCHITECTURE}
find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '%P ' | xargs md5sum > DEBIAN/md5sums
cd ..
dpkg -b hostapd-armbian${TARGET}_${REVISION}_${ARCHITECTURE} >/dev/null 2>&1
rm -rf hostapd-armbian${TARGET}_${REVISION}_${ARCHITECTURE}
echo -e "[\e[0;32m o.k. \x1B[0m] All done. Hostapd is packed into: hostapd-armbian${TARGET}_${REVISION}_${ARCHITECTURE}.deb"