#!/bin/bash

# Record everything that is run from this script so appears in logs.

set -x

# Ensure that any failure within this script causes this script to fail
# immediately. This eliminates the need to check individual statuses for
# anything which is run and prematurely exit. Note that the feature of
# bash to exit in this way isn't foolproof. Ensure that you heed any
# advice in:
#
#   http://mywiki.wooledge.org/BashFAQ/105
#   http://fvue.nl/wiki/Bash:_Error_handling
#
# and use best practices to ensure that failures are always detected.
# Any user supplied scripts should also use this failure mode.

set -eo pipefail

# Set the umask to be '002' so that any files/directories created from
# this point are group writable. This does rely on any applications or
# installation scripts honouring the umask setting, which unfortunately
# not all do.

umask 002

# Set up the directory where Python and Apache installations will be put.

INSTALL_ROOT=/usr/local
export INSTALL_ROOT

BUILD_ROOT=/tmp/build
export BUILD_ROOT

mkdir -p $INSTALL_ROOT
mkdir -p $BUILD_ROOT

# Validate that package version details are set in the Dockerfile.

test ! -z "$NGHTTP2_VERSION" || exit 1
test ! -z "$APR_VERSION" || exit 1
test ! -z "$APR_UTIL_VERSION" || exit 1
test ! -z "$APACHE_VERSION" || exit 1
test ! -z "$NSS_WRAPPER_VERSION" || exit 1
test ! -z "$TINI_VERSION" || exit 1

# Download source code for packages and unpack them.

curl -SL -o $BUILD_ROOT/nghttp2.tar.gz https://github.com/tatsuhiro-t/nghttp2/releases/download/v$NGHTTP2_VERSION/nghttp2-$NGHTTP2_VERSION.tar.gz

mkdir $BUILD_ROOT/nghttp2

tar -xC $BUILD_ROOT/nghttp2 --strip-components=1 -f $BUILD_ROOT/nghttp2.tar.gz

curl -SL -o $BUILD_ROOT/apr.tar.gz http://mirror.ventraip.net.au/apache/apr/apr-$APR_VERSION.tar.gz

mkdir $BUILD_ROOT/apr

tar -xC $BUILD_ROOT/apr --strip-components=1 -f $BUILD_ROOT/apr.tar.gz

curl -SL -o $BUILD_ROOT/apr-util.tar.gz http://mirror.ventraip.net.au/apache/apr/apr-util-$APR_UTIL_VERSION.tar.gz

mkdir $BUILD_ROOT/apr-util

tar -xC $BUILD_ROOT/apr-util --strip-components=1 -f $BUILD_ROOT/apr-util.tar.gz

curl -SL -o $BUILD_ROOT/apache.tar.gz http://mirror.ventraip.net.au/apache/httpd/httpd-$APACHE_VERSION.tar.gz

mkdir $BUILD_ROOT/apache

tar -xC $BUILD_ROOT/apache --strip-components=1 -f $BUILD_ROOT/apache.tar.gz

curl -SL -o $BUILD_ROOT/nss_wrapper.tar.gz https://ftp.samba.org/pub/cwrap/nss_wrapper-$NSS_WRAPPER_VERSION.tar.gz

mkdir $BUILD_ROOT/nss_wrapper

tar -xC $BUILD_ROOT/nss_wrapper --strip-components=1 -f $BUILD_ROOT/nss_wrapper.tar.gz

curl -SL -o $BUILD_ROOT/tini.tar.gz https://github.com/krallin/tini/archive/v$TINI_VERSION.tar.gz

mkdir $BUILD_ROOT/tini

tar -xC $BUILD_ROOT/tini --strip-components=1 -f $BUILD_ROOT/tini.tar.gz

# Build Apache from source code.

cd $BUILD_ROOT/nghttp2

./configure --prefix=$INSTALL_ROOT/nghttp2

make
make install

cd $BUILD_ROOT/apr

./configure --prefix=$INSTALL_ROOT/apache

make
make install

cd $BUILD_ROOT/apr-util

./configure --prefix=$INSTALL_ROOT/apache \
    --with-apr=$INSTALL_ROOT/apache/bin/apr-1-config

make
make install

cd $BUILD_ROOT/apache

./configure --prefix=$INSTALL_ROOT/apache --enable-mpms-shared=all \
    --with-mpm=event --enable-so --enable-rewrite --enable-http2 \
    --with-apr=$INSTALL_ROOT/apache/bin/apr-1-config \
    --with-apr-util=$INSTALL_ROOT/apache/bin/apu-1-config \
    --with-nghttp2=$INSTALL_ROOT/nghttp2

make
make install

rm -rf $INSTALL_ROOT/apache/manual

# Build nss_wrapper package for use in returning proper user/group
# details if container run under random uid/gid.

cd $BUILD_ROOT/nss_wrapper

mkdir obj
cd obj

cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_ROOT/nss_wrapper -DLIB_SUFFIX=64 ..

make
make install

# Build tini package for use as a minimal init process to ensure
# correct reaping of zombie processes.

cd $BUILD_ROOT/tini

cmake .

make CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37" .
make install

# Clean up the temporary build area.

rm -rf $BUILD_ROOT
