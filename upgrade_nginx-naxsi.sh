#!/bin/bash

# Copyright (C) 2012-2017 Didier Conchaudron (didier@conchaudron.net)

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# History
# v0.1 - 2012-11-26 - initial release
# v0.2 - 2012-11-27 - fixed return codes, polishing
# v0.3 - 2012-12-21 - nginx stable = 1.2.6, upgrade nginx executable on the fly
# v0.3.1 - 2013-05-22 - Late nginx stable upgrade, fix trailing /, svn up/checkout proper end checks
# v0.4 - 2014-04-17 - Update nginx version, git repo
# v0.5 - 2017-05-25 - Update and adapt to new 1.12 stable branch

# TODO
# Automagically fetch latest stable Nginx: eg html parsing :(
# Check integrity of nginx src using gpg
# Add lua support for Nginx (check for local lua interpreter and fetch nginx lua mode)

NGINX_CURRENT="1.12.0"
PREFIX_INSTALL="/usr/local"

echo "## Naxsi WAF installation/upgrade script ##"

# Checking out the latest stable Naxsi
echo "[+] Installing/upgrading Naxsi from main repository..."
if [ -d "naxsi" ]; then
	cd naxsi
	git checkout
	if [ $? != 0 ]; then
		echo "  [-] Something went wrong while updating naxsi src from main repository"
		exit
	fi
	cd ..
else
	git clone https://github.com/nbs-system/naxsi.git
	if [ $? != 0 ]; then
		echo "  [-] Something went wrong while checking out naxsi src from main repository"
		exit
	fi
fi

if [ -f "nginx-$NGINX_CURRENT.tar.gz" ]; then
	echo "[+] You already have the latest Nginx tarball: $NGINX_CURRENT"
else
	echo "[+] Fetching latest stable Nginx release from nginx.org "
	wget --quiet http://nginx.org/download/nginx-$NGINX_CURRENT.tar.gz
fi

## Place holder: gpg signature check
# wget http://nginx.org/download/nginx-$NGINX_CURRENT.tar.gz.asc
# gpg --verify nginx-$NGINX_CURRENT.tar.gz.asc
#	0	-> next
#	!0	-> look for key ID in gpg error msg, gpg --recv-keys $KEYID, ask user to compare KEYID owner with name of authorized commiters from http://nginx.org/en/pgp_keys.html
# 

if [ -d "nginx-$NGINX_CURRENT/" ]; then
	echo "[+] You already have untar the Nginx tarball"
else
	echo "[+] Un-tar-ing Nginx tarball..."
	tar xzf nginx-$NGINX_CURRENT.tar.gz
fi

cd nginx-$NGINX_CURRENT/

echo "[+] Configuring build..."
# Configure Nginx together with Naxsi, using most Debian options
./configure \
 --prefix=$PREFIX_INSTALL \
 --conf-path=/etc/nginx/nginx.conf \
 --add-module=../naxsi/naxsi_src \
 --error-log-path=/var/log/nginx/error.log \
 --http-client-body-temp-path=/var/lib/nginx/body \
 --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
 --http-log-path=/var/log/nginx/access.log \
 --http-proxy-temp-path=/var/lib/nginx/proxy \
 --http-scgi-temp-path=/var/lib/nginx/scgi \
 --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
 --lock-path=/var/lock/nginx.lock \
 --pid-path=/var/run/nginx.pid \
 --with-pcre-jit \
 --with-http_ssl_module \
 --without-mail_pop3_module \
 --without-mail_smtp_module \
 --without-mail_imap_module \
 --without-http_uwsgi_module \
 --without-http_scgi_module \
# >/dev/null

if [ $? != 0 ]; then
	echo "  [-] Something went wrong while configuring the build, please check above error logs"
	exit
fi

# Compiling Nginx with Naxsi
echo "[+] Building..."
make -j 2 >/dev/null

if [ $? != 0 ]; then
	echo "  [-] Something went wrong while compiling, please check above error logs"
	exit
fi

# Sudo-ing on a random command to provide enable sudo session single authentication, aka password auth.
if [ $EUID != 0 ]; then
	echo "[+] Sudo token"
	echo "  [-] Since we use sudo for root commands, your password might be necessary 4 times"
	echo "  [-] Echo-ing $EUID with sudo so sudo is happy for the next commands"
	sudo echo $EUID
	if [ $? != 0 ]; then
		echo "  [-] Sudo did not like your password attempt, see you later :)"
		exit
	fi
fi

echo "[+] Installing files in $PREFIX_INSTALL ..."
sudo make install >/dev/null
if [ $? != 0 ]; then
	echo "  [-] Something went wrong while installing files, please check above error logs"
	exit
fi

# Copying fresh Naxsi core rules unless already a file is already existing
sudo cp -n ../naxsi/naxsi_config/naxsi_core.rules /etc/nginx/
if [ $? != 0 ]; then
	echo "  [-] Something went wrong while copying Naxsi_core.rules file, please check above error logs"
fi

echo "[+] Upgrading Nginx executable on the fly..."
sudo kill -s SIGUSR2 `cat /var/run/nginx.pid`
if [ $? != 0 ]; then
	echo "  [-] Something went wrong while upgrading nginx executable on the fly, please check above error logs"
fi

exit 0
