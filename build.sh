#!/bin/sh

# Memo: How should I pass this in?

ARCH=x86_64

function dienow()
{
  echo "Exiting due to errors"
  exit 1
}


function dotprogress()
{
  x=0
  while read i
  do
    x=$[$x + 1]
    if [[ "$x" -eq 25 ]]
    then
      x=0
      echo -n .
    fi
  done
  echo
}

# Extract package $1, use work directory $2 (or $1 if no $2), use source
# directory $3 (or $1 if no $3)

function setupfor()
{
  echo "=== Building $1"
  echo -n "Extracting"
  cd "${WORK}" &&
  { tar xvjf "${SOURCES}/${STAGE}/$1".tar.bz2 || dienow
  } | dotprogress
  if [ -z "$2" ]
  then
    cd "$1"* || dienow
  else
    mkdir "$2"
    cd "$2" || dienow
  fi
  export CURSRC="$1"
  [ ! -z "$3" ] && CURSRC="$3"
  export CURSRC=`echo "${WORK}/${CURSRC}"*`
  [ ! -d "${CURSRC}" ] && dienow
}

# Setup

umask 022
unset CFLAGS CXXFLAGS

# Find/create directories

TOP=`pwd`
export SOURCES="${TOP}/sources"
export CROSS="${TOP}/build/cross-compiler/"
export WORK="${TOP}/build/temp"
mkdir -p "${CROSS}" "${WORK}"

[ $? -ne 0 ] && dienow

# For bash: check the $PATH for new executables added after startup.
set +h
# Put the cross compiler in the path
export PATH=${CROSS}/bin:/bin:/usr/bin

# Which platform are we building for?

[ "$ARCH" == x86_64 ] && export BUILD64="-m64"
export CROSS_HOST=i686-pc-linux-gnu
export CROSS_TARGET=${ARCH}-unknown-linux-gnu

export STAGE=build-cross

setupfor linux
make headers_install ARCH="${ARCH}" INSTALL_HDR_PATH="${CROSS}"

[ $? -ne 0 ] && dienow

setupfor binutils build-binutils
"${CURSRC}/configure" --prefix="${CROSS}" --host=${CROSS_HOST} \
	--target=${CROSS_TARGET} --with-lib-path=lib --disable-nls \
	--disable-shared --enable-64-bit-bfd --disable-multilib &&
make configure-host &&
make &&
make install &&
cd .. &&
cp binutils-*/include/libiberty.h "${CROSS}/include" &&
rm -rf binutils-* build-binutils

[ $? -ne 0 ] && dienow

setupfor gcc-core build-gcc gcc-
"${CURSRC}/configure" --prefix="${CROSS}" --host=${CROSS_HOST} \
	--target=${CROSS_TARGET} --with-local-prefix="${CROSS}" \
	--disable-multilib --disable-nls --disable-shared --disable-threads \
	--enable-languages=c &&
make all-gcc &&
make install-gcc &&
cd .. &&
rm -rf "${CURSRC}" build-gcc

[ $? -ne 0 ] && dienow

setupfor uClibc
make TARGET_ARCH=${ARCH} CROSS=${CROSS_TARGET}- defconfig &&
make TARGET_ARCH=${ARCH} CROSS=${CROSS_TARGET}- KERNEL_SOURCE="${CROSS}" &&
make TARGET_ARCH=${ARCH} CROSS=${CROSS_TARGET}- utils &&
# The kernel headers are already installed, but uClibc's install will try to
# be "helpful" and copy them over themselves, at which point hilarity ensues.
# Make it not do that.
rm include/{asm,asm-generic,linux} &&
make RUNTIME_PREFIX="${CROSS}" DEVEL_PREFIX="${CROSS}" \
	install_runtime install_dev &&
cd .. &&
rm -rf uClibc-*

[ $? -ne 0 ] && dienow
