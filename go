#!/bin/bash
#
# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

#TARGET="realtek" 	# For (most) realtek use "realtek"
STABLE="no" 		# Comment this out to use development version

# get a copy of latest hostapd
SRC=$(pwd)

if [ -d "$SRC/hostap" ]; then
	cd $SRC/hostap
	git checkout master
	git pull
	else
	git clone git://w1.fi/hostap.git
fi

if [ "$STABLE" == "yes" ]; then cd $SRC/hostap; git checkout hostap_2_4; fi




cp $SRC/files/*.* $SRC/hostap/src/drivers/

cd $SRC/hostap/

# patch for more bandwidth
if [ "$(patch --dry-run -t -p1 < $SRC/patch/300-noscan.patch | grep previ)" == "" ]; then
	patch --batch -f -p1 < $SRC/patch/300-noscan.patch
fi

# patch for realtek
if [ "$TARGET" == "realtek" ]; then
	cp $SRC/config/config_realtek $SRC/hostap/hostapd/.config
	patch --batch -f -p1 < $SRC/patch/realtek.patch
	else
	cp $SRC/config/config_default $SRC/hostap/hostapd/.config
	if [ "$(cat $SRC/hostap/hostapd/main.c | grep rtl871)" != "" ]; then
		echo "Reversing Banana patch"
		patch --batch -t -p1 < $SRC/patch/realtek.patch
	fi
fi

# more usefull patches
# https://dev.openwrt.org/browser/trunk/package/network/services/hostapd/patches?order=name

cd hostapd
#make clean >/dev/null 2>&1
make -j4
tar cvfz $SRC/hostapd-$TARGET.tgz hostapd hostapd_cli