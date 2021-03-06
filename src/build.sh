#!/bin/sh
#
# NAME
#
# DESCRIPTION
#
# COMMANDS
#    --help
#    -h
#       Prints this documentation.
#
#    --device=DEVICE_PATH_HERE
#       The stpraage device to partition and build the OS on. The device will be formatted during the build process. Required.
#
# DEPENDENCIES
#
# AUTHORS
#     Copyright (c) Robert Zack Jaidyn Norris-Karr <rzjnzk@gmail.com> <https://github.com/rzjnzk>
#
# NOTES
#     Untested.

(

_main()
{
    _verify_toolchain()
    {
        printf -- "int main(){}\n" > "${_script_path}/${_script_name}.test-src.tmp" 2>&1
        case "${1}" in
            1)
                "${_build_tools_target}"-gcc "${_script_path}/${_script_name}.test-src.tmp" \
                    -o "${_script_path}/${_script_name}".test-bin.tmp
                ;;
            2)
                cc "${_script_path}/${_script_name}".test-src.tmp \
                    -o "${_script_path}/${_script_name}".test-bin.tmp
                ;;
            3)
                cc "${_script_path}/${_script_name}".test-src.tmp -v -Wl,--verbose
                ;;
        esac
        test -n \
            "$(
                readelf -l "${_script_path}/${_script_name}".test-bin.tmp |
                    sed -n "/^ *\[Requesting program interpreter: \/tools\/lib/ p"
            )" ||
                {
                    tput setaf 1
                    printf -- "ERROR: Compiling and linking of the new toolchain is not working as expected."
                    tput sgr0
                    exit 1
                }
        rm -rfv "${_script_path}"/"${_script_name}".*.tmp
    }

    # Print help and exit if a help flag was supplied.
    test -n "$(printf -- "${_script_args}" | sed -n "/^--help\$/ p ; /^-h\$/ p")" &&
        cat "${_script_path}/${_script_name}" |
            sed -n "3,/^\$/ { s/^# // ; s/^#// ; p }" &&
                exit

    mkdir -pv "${_script_path}/../bin"
    cd "${_script_path}/../bin"

    # Create blank img file to build linux on, and mount to loop device.
    dd if=/dev/zero of=linux.img iflag=fullblock bs=1M count=20000
    sync
    _target_storage_device="$(losetup -f)"
    losetup -f linux.img

    # Partition img file.
    # Res: <https://www.thegeekstuff.com/2017/05/sfdisk-examples>
    # Res: <https://www.computerhope.com/unix/sfdisk.htm>
    tput setaf 4
    printf -- "Partitioning target storage device.\n"
    tput sgr0
    printf -- "%s\n" \
        ",100MiB" \
        ",12GiB,L" \
        ",4GiB,S" \
        ";" |
            sfdisk -b -- "${_target_storage_device}"
    sfdisk -l -- "${_target_storage_device}"

    # Set filesystems/swap for the partitions.
    mkfs -v -t ext2 -- "${_target_storage_device}"1
    mkfs -v -t ext4 -- "${_target_storage_device}"2
    mkswap -- "${_target_storage_device}"3

    # Mount filesystems/swap.
    _build_root="/mnt/linux_build_sys_root"
    _i=1
    while \
        test -d "${_build_root}"
    do
        _build_root="${_build_root}${_i}"
        i="$((_i + 1))"
    done
    mkdir -pv -- \
        "${_build_root}" \
        "${_build_root}"/boot \
    mount -v -t ext2 -- "${_target_storage_device}"1 "${_build_root}"/boot
    mount -v -t ext4 -- "${_target_storage_device}"2 "${_build_root}"
    /sbin/swapon -v "${_target_storage_device}"3

    # Download package source archives.
    cd "${_build_root}/sources"
    chmod -v a+wt .
    wget \
        http://download.savannah.gnu.org/releases/acl/acl-2.2.53.tar.gz \
        http://download.savannah.gnu.org/releases/attr/attr-2.4.48.tar.gz \
        http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.xz \
        http://ftp.gnu.org/gnu/automake/automake-1.16.1.tar.xz \
        http://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz \
        https://github.com/gavinhoward/bc/archive/2.5.3/bc-2.5.3.tar.gz \
        http://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.xz \
        http://ftp.gnu.org/gnu/bison/bison-3.5.2.tar.xz \
        https://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz \
        https://github.com/libcheck/check/releases/download/0.14.0/check-0.14.0.tar.gz \
        http://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz \
        https://dbus.freedesktop.org/releases/dbus/dbus-1.12.16.tar.gz \
        http://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.2.tar.gz \
        http://ftp.gnu.org/gnu/diffutils/diffutils-3.7.tar.xz \
        https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v1.45.5/e2fsprogs-1.45.5.tar.gz \
        https://sourceware.org/ftp/elfutils/0.178/elfutils-0.178.tar.bz2 \
        https://dev.gentoo.org/~blueness/eudev/eudev-3.2.9.tar.gz \
        https://prdownloads.sourceforge.net/expat/expat-2.2.9.tar.xz \
        https://prdownloads.sourceforge.net/expect/expect5.45.4.tar.gz \
        ftp://ftp.astron.com/pub/file/file-5.38.tar.gz \
        http://ftp.gnu.org/gnu/findutils/findutils-4.7.0.tar.xz \
        https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz \
        http://ftp.gnu.org/gnu/gawk/gawk-5.0.1.tar.xz \
        http://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz \
        http://ftp.gnu.org/gnu/gdbm/gdbm-1.18.1.tar.gz \
        http://ftp.gnu.org/gnu/gettext/gettext-0.20.1.tar.xz \
        http://ftp.gnu.org/gnu/glibc/glibc-2.31.tar.xz \
        http://ftp.gnu.org/gnu/gmp/gmp-6.2.0.tar.xz \
        http://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz \
        http://ftp.gnu.org/gnu/grep/grep-3.4.tar.xz \
        http://ftp.gnu.org/gnu/groff/groff-1.22.4.tar.gz \
        https://ftp.gnu.org/gnu/grub/grub-2.04.tar.xz \
        http://ftp.gnu.org/gnu/gzip/gzip-1.10.tar.xz \
        http://anduin.linuxfromscratch.org/LFS/iana-etc-2.30.tar.bz2 \
        http://ftp.gnu.org/gnu/inetutils/inetutils-1.9.4.tar.xz \
        https://launchpad.net/intltool/trunk/0.51.0/+download/intltool-0.51.0.tar.gz \
        https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-5.5.0.tar.xz \
        https://www.kernel.org/pub/linux/utils/kbd/kbd-2.2.0.tar.xz \
        https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-26.tar.xz \
        http://www.greenwoodsoftware.com/less/less-551.tar.gz \
        http://www.linuxfromscratch.org/lfs/downloads/9.1/lfs-bootscripts-20191031.tar.xz \
        https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.31.tar.xz \
        ftp://sourceware.org/pub/libffi/libffi-3.3.tar.gz \
        http://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.2.tar.gz \
        http://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz \
        https://www.kernel.org/pub/linux/kernel/v5.x/linux-5.5.3.tar.xz \
        http://ftp.gnu.org/gnu/m4/m4-1.4.18.tar.xz \
        http://ftp.gnu.org/gnu/make/make-4.3.tar.gz \
        http://download.savannah.gnu.org/releases/man-db/man-db-2.9.0.tar.xz \
        https://www.kernel.org/pub/linux/docs/man-pages/man-pages-5.05.tar.xz \
        https://github.com/mesonbuild/meson/releases/download/0.53.1/meson-0.53.1.tar.gz \
        https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz \
        http://www.mpfr.org/mpfr-4.0.2/mpfr-4.0.2.tar.xz \
        https://github.com/ninja-build/ninja/archive/v1.10.0/ninja-1.10.0.tar.gz \
        http://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz \
        https://www.openssl.org/source/openssl-1.1.1d.tar.gz \
        http://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz \
        https://www.cpan.org/src/5.0/perl-5.30.1.tar.xz \
        https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz \
        https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-3.3.15.tar.xz \
        https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.2.tar.xz \
        https://www.python.org/ftp/python/3.8.1/Python-3.8.1.tar.xz \
        https://www.python.org/ftp/python/doc/3.8.1/python-3.8.1-docs-html.tar.bz2 \
        http://ftp.gnu.org/gnu/readline/readline-8.0.tar.gz \
        http://ftp.gnu.org/gnu/sed/sed-4.8.tar.xz \
        https://github.com/shadow-maint/shadow/releases/download/4.8.1/shadow-4.8.1.tar.xz \
        http://www.infodrom.org/projects/sysklogd/download/sysklogd-1.5.1.tar.gz \
        https://github.com/systemd/systemd/archive/v244/systemd-244.tar.gz \
        http://anduin.linuxfromscratch.org/LFS/systemd-man-pages-244.tar.xz \
        http://download.savannah.gnu.org/releases/sysvinit/sysvinit-2.96.tar.xz \
        http://ftp.gnu.org/gnu/tar/tar-1.32.tar.xz \
        https://downloads.sourceforge.net/tcl/tcl8.6.10-src.tar.gz \
        http://ftp.gnu.org/gnu/texinfo/texinfo-6.7.tar.xz \
        https://www.iana.org/time-zones/repository/releases/tzdata2019c.tar.gz \
        http://anduin.linuxfromscratch.org/LFS/udev-lfs-20171102.tar.xz \
        https://www.kernel.org/pub/linux/utils/util-linux/v2.35/util-linux-2.35.1.tar.xz \
        http://anduin.linuxfromscratch.org/LFS/vim-8.2.0190.tar.gz \
        https://cpan.metacpan.org/authors/id/T/TO/TODDR/XML-Parser-2.46.tar.gz \
        https://tukaani.org/xz/xz-5.2.4.tar.xz \
        https://zlib.net/zlib-1.2.11.tar.xz \
        https://github.com/facebook/zstd/releases/download/v1.4.4/zstd-1.4.4.tar.gz \
        http://www.linuxfromscratch.org/patches/lfs/9.1/bash-5.0-upstream_fixes-1.patch \
        http://www.linuxfromscratch.org/patches/lfs/9.1/bzip2-1.0.8-install_docs-1.patch \
        http://www.linuxfromscratch.org/patches/lfs/9.1/coreutils-8.31-i18n-1.patch \
        http://www.linuxfromscratch.org/patches/lfs/9.1/glibc-2.31-fhs-1.patch \
        http://www.linuxfromscratch.org/patches/lfs/9.1/kbd-2.2.0-backspace-1.patch \
        http://www.linuxfromscratch.org/patches/lfs/9.1/sysvinit-2.96-consolidated-1.patch

    # Make and link tools dir.
    mkdir -pv -- "${_build_root}"/tools
    ln -sv -- "${_build_root}"/tools /


    # Configure the environment for compilation
    set +h
    umask 022
    export LC_ALL=POSIX
    export PATH=/tools/bin:/bin:/usr/bin
    export MAKEFLAGS="$(
        lscpu |
            sed -n \
                "
                    /^CPU(s): *.*\$/ \
                    {
                        s/^CPU(s): * \(.*\)\$/-j \1/
                        p
                    }
                "
        )"
    export _build_tools_target="$(uname -m)"-sysbuildtools-linux-gnu # TODO: Possibly remove lfs from name, and edit variable name.

    # Install binutils (pass 1).
    tar -xf binutils-*.tar.*
    cd binutils-*
    mkdir -pv build
    cd build
    ../configure \
        --prefix=/tools \
        --with-sysroot="${_build_root}" \
        --with-lib-path=/tools/lib \
        --target="${_build_tools_target}" \
        --disable-nls \
        --disable-werror
    make
    test -n "$(uname -m | sed -n "/x86_64/ p")" &&
        mkdir -pv /tools/lib &&
            ln -sv lib /tools/lib64
    make install
    cd ../..
    rm -rvf binutils-*/

    # Install gcc (pass 1).
    tar -xf gcc-*.tar.*
    cd gcc-*
    tar -xf ../mpfr-*.tar.*
    mv -v mpfr-*/ mpfr
    tar -xf ../gmp-*.tar.*
    mv -v gmp-*/ gmp
    tar -xf ../mpc-*.tar.*
    mv -v mpc-*/ mpc
    # TODO: Make snippet portable and more readable.
    for file in \
        gcc/config/{linux,i386/linux{,64}}.h
    do
        cp -uv "${file}"{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
            -e 's@/usr@/tools@g' "${file}.orig" > "${file}"
        printf -- "%s\n" \
            "#undef STANDARD_STARTFILE_PREFIX_1" \
            "#undef STANDARD_STARTFILE_PREFIX_2" \
            "#define STANDARD_STARTFILE_PREFIX_1 \"/tools/lib/\"" \
            "#define STANDARD_STARTFILE_PREFIX_2 \"\"" \
                >> "${file}"
        touch "${file}.orig"
    done
    test -n "$(uname -m | sed -n "/x86_64/ p")" &&
        sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64 # TODO: Consider what this does, and remove the need for `-e` flag if possible.
    mkdir -pv build
    cd build
    ../configure \
        --target="${_build_tools_target}" \
        --prefix=/tools \
        --with-glibc-version=2.31 \
        --with-sysroot="${_build_root}" \
        --with-newlib \
        --without-headers \
        --with-local-prefix=/tools \
        --with-native-system-header-dir=/tools/include \
        --disable-nls \
        --disable-shared \
        --disable-multilib \
        --disable-decimal-float \
        --disable-threads \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libvtv \
        --disable-libstdcxx \
        --enable-languages=c,c++
    make
    make install
    cd ../..
    rm -rvf gcc-*/

    # Insall Linux API headers.
    tar -xf linux-*.tar.*
    cd linux-*
    make mrproper
    make headers
    cp -rv usr/include/* /tools/include
    cd ..
    rm -rvf linux-*/

    # Install glibc.
    # There have been reports that this package may fail when building as a "parallel make". If this occurs, rerun the make command with a "-j1" option.
    tar -xf glibc-*.tar.*
    cd glibc-*
    mkdir -pv build
    cd build
    ../configure \
        --prefix=/tools \
        --host="${_build_tools_target}" \
        --build="$(../scripts/config.guess)" \
        --enable-kernel=3.2 \
        --with-headers=/tools/include
    make
    make install
    cd ../..
    rm -vrf glibc-*/

    # Verify toolchain.
    _verify_toolchain 1

    # Install libstd++.
    tar -xf gcc-*.tar.*
    cd gcc-*
    mkdir -vp build
    cd build
    ../libstdc++-v3/configure \
        --host="${_build_tools_target}" \
        --prefix=/tools \
        --disable-multilib \
        --disable-nls \
        --disable-libstdcxx-threads \
        --disable-libstdcxx-pch \
        --with-gxx-include-dir=/tools/"${_build_tools_target}"/include/c++/9.2.0
    make
    make install
    cd ../..
    rm -rvf gcc-*/

    # Install binutils (pass 2).
    tar -xf binutils-*.tar.*
    cd binutils-*
    mkdir -pv build
    cd build
    # TODO: Make sure removed `\` from the folowing three lines does not effect anything.
    CC="${_build_tools_target}"-gcc
    AR="${_build_tools_target}"-ar
    RANLIB="${_build_tools_target}"-ranlib
    ../configure \
        --prefix=/tools \
        --disable-nls \
        --disable-werror \
        --with-lib-path=/tools/lib \
        --with-sysroot
    make
    make install
    make -C ld clean
    make -C ld LIB_PATH=/usr/lib:/lib
    cp -v ld/ld-new /tools/bin
    cd ../..
    rm -rvf binutils-*/

    # Install gcc (pass 2).
    tar -xf gcc-*.tar.*
    cd gcc-*
    tar -xf ../mpfr-*.tar.*
    mv -v mpfr-*/ mpfr
    tar -xf ../gmp-*.tar.*
    mv -v gmp-*/ gmp
    tar -xf ../mpc-*.tar.*
    mv -v mpc-*/ mpc
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    $(dirname $("${_build_tools_target}"-gcc -print-libgcc-file-name))/include-fixed/limits.h
    for file in \
        gcc/config/{linux,i386/linux{,64}}.h
    do
        cp -uv "${file}"{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
            -e 's@/usr@/tools@g' "${file}.orig" > "${file}"
        printf -- "%s\n" \
            "#undef STANDARD_STARTFILE_PREFIX_1" \
            "#undef STANDARD_STARTFILE_PREFIX_2" \
            "#define STANDARD_STARTFILE_PREFIX_1 \"/tools/lib/\"" \
            "#define STANDARD_STARTFILE_PREFIX_2 \"\"" \
                >> "${file}"
        touch "${file}".orig
    done
    test -n "$(uname -m | sed -n "/x86_64/ p")" &&
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64 # TODO: Consider what this does, and remove the need for `-e` flag if possible.
    # Fix a problem introduced by Glibc-2.31
    sed -e '1161 s|^|//|' \
        -i libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cc
    mkdir -v build
    cd build
    CC="${_build_tools_target}"-gcc \
    CXX="${_build_tools_target}"-g++ \
    AR="${_build_tools_target}"-ar \
    RANLIB="${_build_tools_target}"-ranlib \
    ../configure \
        --prefix=/tools \
        --with-local-prefix=/tools \
        --with-native-system-header-dir=/tools/include \
        --enable-languages=c,c++ \
        --disable-libstdcxx-pch \
        --disable-multilib \
        --disable-bootstrap \
        --disable-libgomp
    make
    make install
    ln -sv gcc /tools/bin/cc
    cd ../..
    rm -rvf gcc-*/

    # Verify toolchain.
    _verify_toolchain 2

    # Install tcl.
    tar -xf tcl-*.tar.*
    cd tcl-*/unix
    ./configure --prefix=/tools
    make
    TZ=UTC make test ||
        {
            tput setaf 1
            printf -- "Non-zero exit code. Assuming non-critical error cause by unknown host conditions.\n"
            tput sgr0
        }
    make install
    # Make the installed library writable so debugging symbols can be removed later.
    chmod -v u+w /tools/lib/libtcl8.6.so
    make install-private-headers
    ln -sv tclsh8.6 /tools/bin/tclsh
    cd ../..
    rm -rvf tcl-*/

    # Install expect.
    tar -xf expect*.tar.*
    cd expect*
    cp -v configure{,.orig}
    # TODO: Check that `cmd > file >2>&1` is the correct POSIX equivelent for `cmd > file`.
    sed "s/\\/usr\\/local\\/bin/\\/bin/" configure.orig > configure 2>&1
    ./configure \
        --prefix=/tools \
        --with-tcl=/tools/lib \
        --with-tclinclude=/tools/include
    make
    make test
    make SCRIPTS="" install
    cd ..
    rm -rvf expect*/

    # Install dejagnu.
    tar -xf dejagnu-*.tar.*
    cd dejagnu-*
    ./configure --prefix=/tools
    make install
    make check
    cd ..
    rm -rvf dejagnu-*/

    # Install m4.
    tar -xf m4-*.tar.*
    cd m4-*
    sed -i "s/IO_ftrylockfile/IO_EOF_SEEN/" lib/*.c
    echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf m4-*/

    # Install ncurses.
    tar -xf ncurses-*.tar.*
    cd ncurses-*
    sed -i "s/mawk//" configure
    ./configure \
        --prefix=/tools \
        --with-shared \
        --without-debug \
        --without-ada \
        --enable-widec \
        --enable-overwrite
    make
    make install
    ln -s libncursesw.so /tools/lib/libncurses.so
    cd ..
    rm -rvf ncurses-*/

    # Install bash.
    tar -xf bash-*.tar.*
    cd bash-*
    ./configure --prefix=/tools --without-bash-malloc
    make
    make tests-
    make install
    ln -sv bash /tools/bin/sh
    cd ..
    rm -rvf bash-*/

    # Install bison.
    tar -xf bison-*.tar.*
    cd bison-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf bison-*/

    # Install bzip2.
    tar -xf bzip2-*.tar.*
    cd bzip2-*
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/tools install
    cp -v bzip2-shared /tools/bin/bzip2
    cp -av libbz2.so* /tools/lib
    ln -sv libbz2.so.1.0 /tools/lib/libbz2.so
    cd ..
    rm -rvf bzip2-*/

    # Install coreutils.
    tar -xf coreutils-*.tar.*
    cd coreutils-*
    ./configure \
        --prefix=/tools \
        --enable-install-program=hostname
    make
    make RUN_EXPENSIVE_TESTS=yes check
    make install
    cd ..
    rm -rvf coreutils-*/

    # Install diffutils.
    tar -xf diffutils-*.tar.*
    cd diffutils-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf diffutils-*/

    # Install file.
    tar -xf file-*.tar.*
    cd file-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf file-*/

    # Install findutils.
    tar -xf findutils-*.tar.*
    cd findutils-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf findutils-*/

    # Install gawk.
    tar -xf gawk-*.tar.*
    cd gawk-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf gawk-*/

    # Install gettext.
    tar -xf gettext-*.tar.*
    cd gettext-*
    ./configure --disable-shared
    make
    cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin
    cd ..
    rm -rvf gettext-*/

    # Install grep.
    tar -xf grep-*.tar.*
    cd grep-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf grep-*/

    # Install gzip.
    tar -xf gzip-*.tar.*
    cd gzip-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf gzip-*/

    # Install make.
    tar -xf make-*.tar.*
    cd make-*
    ./configure \
        --prefix=/tools \
        --without-guile
    make
    make check
    make install
    cd ..
    rm -rvf make-*/

    # Install patch.
    tar -xf patch-*.tar.*
    cd patch-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf patch-*/

    # Install perl 5.
    tar -xf perl-*.tar.*
    cd perl-*
    sh Configure \
        -des \
        -Dprefix=/tools \
        -Dlibs=-lm \
        -Uloclibpth \
        -Ulocincpth
    make
    cp -v perl cpan/podlators/scripts/pod2man /tools/bin
    mkdir -pv /tools/lib/perl5/5.30.1
    cp -Rv lib/* /tools/lib/perl5/5.30.1
    cd ..
    rm -rvf perl-*/

    # Install python.
    tar -xf python-*.tar.*
    cd python-*
    sed -i '/def add_multiarch_paths/a \        return' setup.py
    ./configure --prefix=/tools --without-ensurepip
    make
    make install
    cd ..
    rm -rvf python-*/

    # Install sed.
    tar -xf sed-*.tar.*
    cd sed-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf sed-*/

    # Install tar.
    tar -xf tar-*.tar.*
    cd tar-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf tar-*/

    # Install texinfo.
    tar -xf texinfo-*.tar.*
    cd texinfo-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf texinfo-*/

    # Install util-linux.
    tar -xf util-linux-*.tar.*
    cd util-linux-*
    ./configure \
        --prefix=/tools \
        --without-python \
        --disable-makeinstall-chown \
        --without-systemdsystemunitdir \
        --without-ncurses \
        PKG_CONFIG=""
    make
    make install
    cd ..
    rm -rvf util-linux-*/

    # Install xz.
    tar -xf xz-*.tar.*
    cd xz-*
    ./configure --prefix=/tools
    make
    make check
    make install
    cd ..
    rm -rvf xz-*/

    # # Strip ~70MB dugugging symbols.
    # strip --strip-debug /tools/lib/*
    # /usr/bin/strip --strip-unneeded /tools/{,s}bin/*

    # Remove unneeded files.
    find /tools/{lib,libexec} -name \*.la -delete

    # Change ownership.
    chown -R root:root "${_build_root}"/tools

    # Create fs mount dirs.
    mkdir -pv "${_build_root}"/{dev,proc,sys,run}

    # Create initial device nodes.
    mknod -m 600 "${_build_root}"/dev/console c 5 1
    mknod -m 666 "${_build_root}"/dev/null c 1 3

    mount -v --bind /dev "${_build_root}"/dev
    mount -vt devpts devpts "${_build_root}"/dev/pts -o gid=5,mode=620
    mount -vt proc proc "${_build_root}"/proc
    mount -vt sysfs sysfs "${_build_root}"/sys
    mount -vt tmpfs tmpfs "${_build_root}"/run

    test -h "${_build_root}"/dev/shm &&
        mkdir -pv "${_build_root}"/$(readlink "${_build_root}"/dev/shm)

    # Enter chroot environment.
    chroot "${_build_root}" /tools/bin/env -i \
        HOME=/root \
        TERM="${TERM}" \
        PS1="(lfs chroot) \u:\w\\$ " \
        PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
        /tools/bin/bash --login +h

    # Create standard dir tree.
    mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
    mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
    install -dv -m 0750 /root
    install -dv -m 1777 /tmp /var/tmp
    mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
    mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
    mkdir -pv  /usr/{,local/}share/{misc,terminfo,zoneinfo}
    mkdir -pv  /usr/libexec
    mkdir -pv /usr/{,local/}share/man/man{1..8}
    mkdir -pv  /usr/lib/pkgconfig
    test -n "$(uname -m | sed -n "/x86_64/ p")" &&
        mkdir -v /lib64
    mkdir -pv /var/{log,mail,spool}
    ln -sv /run /var/run
    ln -sv /run/lock /var/lock
    mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

    # Create essential files and symlinks.
    ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} /bin
    ln -sv /tools/bin/{env,install,perl,printf} /usr/bin
    ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib
    ln -sv /tools/lib/libstdc++.{a,so{,.6}} /usr/lib
    ln -sv bash /bin/sh
    ln -sv /proc/self/mounts /etc/mtab
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
systemd-bus-proxy:x:72:72:systemd Bus Proxy:/:/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/bin/false
systemd-network:x:76:76:systemd Network Management:/:/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-bus-proxy:x:72:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
    exec /tools/bin/bash --login +h
    touch /var/log/{btmp,lastlog,faillog,wtmp}
    chgrp -v utmp /var/log/lastlog
    chmod -v 664 /var/log/lastlog
    chmod -v 600 /var/log/btmp

    ##################################
    # BEGIN Install system software. #
    ##################################

    cd sources

    # Install Linux API Headers.
    tar -xf linux-*.tar.*
    cd linux-*
    make mrproper
    make headers
    find usr/include -name '.*' -delete
    rm usr/include/Makefile
    cp -rv usr/include/* /usr/include
    cd ..
    rm -rvf linux-*/

    # Install man-pages.
    tar -xf man-pages-*.tar.*
    cd man-pages-*
    make install
    cd ..
    rm -rvf man-pages-*/

    # Install glibc.
    tar -xf glibc-*.tar.*
    cd glibc-*
    patch -Np1 -i ../glibc-2.31-fhs-1.patch
    case $(uname -m) in
        i?86)   ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
        ;;
        x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
                ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
        ;;
    esac
    mkdir -v build
    cd build
    CC="gcc -ffile-prefix-map=/tools=/usr" \
    ../configure \
        --prefix=/usr \
        --disable-werror \
        --enable-kernel=3.2 \
        --enable-stack-protector=strong \
        --with-headers=/usr/include \
        libc_cv_slibdir=/lib
    make
    case $(uname -m) in
        i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
        x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
    esac
    make check
    touch /etc/ld.so.conf
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
    make install
    cp -v ../nscd/nscd.conf /etc/nscd.conf
    mkdir -pv /var/cache/nscd
    install -v -Dm644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
    install -v -Dm644 ../nscd/nscd.service /lib/systemd/system/nscd.service
    mkdir -pv /usr/lib/locale
    make localedata/install-locales
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
    tar -xf ../../tzdata2019c.tar.gz

    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}

    for tz in etcetera southamerica northamerica europe africa antarctica  \
            asia australasia backward pacificnew systemv; do
        zic -L /dev/null   -d $ZONEINFO       ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        zic -L leapseconds -d $ZONEINFO/right ${tz}
    done

    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO
    ln -sfv /usr/share/zoneinfo/UTC-0 /etc/localtime
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
    mkdir -pv /etc/ld.so.conf.d
    cd ../..
    rm -rvf glibc-*/

    # Adjust the toolchain.
    mv -v /tools/bin/{ld,ld-old}
    mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
    mv -v /tools/bin/{ld-new,ld}
    ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
    gcc -dumpspecs | sed -e 's@/tools@@g'                   \
        -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
        -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' > \
        `dirname $(gcc --print-libgcc-file-name)`/specs

    # Verify toolchain.
    _verify_toolchain 3 &> "${_script_path}/${_script_name}.test-log.tmp"
    grep -o '/usr/lib.*/crt[1in].*succeeded' "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "/usr/lib/../lib/crt1.o succeeded\n" \
        "/usr/lib/../lib/crti.o succeeded\n" \
        "/usr/lib/../lib/crtn.o succeeded\n\n"
    grep -B1 '^ /usr/include' "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "#include <...> search starts here:\n" \
        "/usr/include\n\n"
    grep 'SEARCH.*/usr/lib' "${_script_path}/${_script_name}.test-log.tmp" | sed 's|; |\n|g'
    printf -- "Output of previous command should match the following:\n" \
        "SEARCH_DIR(\"/usr/lib\")\n" \
        "SEARCH_DIR(\"/lib\")\n\n"
    grep "/lib.*/libc.so.6 " "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "SEARCH_DIR(\"/usr/lib\")\n" \
        "SEARCH_DIR(\"/lib\")\n\n"
    grep "/lib.*/libc.so.6 " "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "attempt to open /lib/libc.so.6 succeeded\n\n"
    grep found "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "found ld-linux-x86-64.so.2 at /lib/ld-linux-x86-64.so.2\n\n"
    rm -rfv "${_script_path}"/"${_script_name}".*.tmp

    # Install zlib.
    tar -xf zlib-*.tar.*
    cd zlib-*
    ./configure --prefix=/usr
    make
    make check
    make install
    mv -v /usr/lib/libz.so.* /lib
    ln -sfv ../../lib/"$(readlink /usr/lib/libz.so)" /usr/lib/libz.so
    cd ..
    rm -rvf zlib-*/

    # Install bzip2.
    tar -xf bzip2-*.tar.*
    cd bzip2-*
    patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/usr install
    cp -v bzip2-shared /bin/bzip2
    cp -av libbz2.so* /lib
    ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
    rm -v /usr/bin/{bunzip2,bzcat,bzip2}
    ln -sv bzip2 /bin/bunzip2
    ln -sv bzip2 /bin/bzcat
    cd ..
    rm -rvf bzip2-*/

    # Install xz.
    tar -xf xz-*.tar.*
    cd -*
    ./configure \
        --prefix=/usr \
        --disable-static \
        --docdir=/usr/share/doc/xz-5.2.4
    make
    make check
    make install
    mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
    mv -v /usr/lib/liblzma.so.* /lib
    ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
    cd ..
    rm -rvf xz-*/

    # Install file.
    tar -xf file-*.tar.*
    cd file-*
    ./configure --prefix=/usr
    make
    make check
    make install
    cd ..
    rm -rvf file-*/

    # Install realine.
    tar -xf realine-*.tar.*
    cd realine-*
    sed -i '/MV.*old/d' Makefile.in
    sed -i '/{OLDSUFF}/c:' support/shlib-install
    ./configure \
        --prefix=/usr \
        --disable-static \
        --docdir=/usr/share/doc/readline-8.0
    make SHLIB_LIBS="-L/tools/lib -lncursesw"
    make SHLIB_LIBS="-L/tools/lib -lncursesw" install
    mv -v /usr/lib/lib{readline,history}.so.* /lib
    chmod -v u+w /lib/lib{readline,history}.so.*
    ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
    ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.0
    cd ..
    rm -rvf realine-*/

    # Install m4.
    tar -xf m4-*.tar.*
    cd m4-*
    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
    echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
    ./configure --prefix=/usr
    make
    make check
    make install
    cd ..
    rm -rvf m4-*/

    # Install bc.
    tar -xf bc-*.tar.*
    cd bc-*
    PREFIX=/usr CC=gcc CFLAGS="-std=c99" ./configure.sh -G -O3
    make
    make test
    make install
    cd ..
    rm -rvf bc-*/

    # Install binutils.
    tar -xf binutils-*.tar.*
    cd binutils-*
    expect -c "spawn ls"
    spawn ls
    printf -- "If the output of previous command should matches the following, then the environment is not set up for proper PTY operation. This issue needs to be resolved before running the test suites for Binutils and GCC.\n" \
        "The system has no more ptys.\n" \
        "Ask your system administrator to create more.\n\n"
    sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in
    mkdir -pv build
    cd build
    ../configure \
        --prefix=/usr \
        --enable-gold \
        --enable-ld=default \
        --enable-plugins \
        --enable-shared \
        --disable-werror \
        --enable-64-bit-bfd \
        --with-system-zlib
    make tooldir=/usr
    make -k check
    make tooldir=/usr install
    cd ../..
    rm -rvf binutils-*/

    # Install gmp.
    tar -xf gmp-*.tar.*
    cd gmp-*
    ABI=32 ./configure ...
    cp -v configfsf.guess config.guess
    cp -v configfsf.sub config.sub
    ./configure \
        --prefix=/usr \
        --enable-cxx \
        --disable-static \
        --docdir=/usr/share/doc/gmp-6.2.0
    make
    make html
    make check 2>&1 | tee gmp-check-login
    # Caution
    # The code in gmp is highly optimized for the processor where it is built. Occasionally, the code that detects the processor misidentifies the system capabilities and there will be errors in the tests or other applications using the gmp libraries with the message "Illegal instruction". In this case, gmp should be reconfigured with the option --build=x86_64-unknown-linux-gnu and rebuilt.
    # Ensure that all 190 tests in the test suite passed.
    printf -- "Checking test results.\n"
    awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
    make install
    make install-html
    cd ..
    rm -rvf gmp-*/

    # Install mpfr.
    tar -xf mpfr-*.tar.*
    cd mpfr-*
    ./configure \
        --prefix=/usr \
        --disable-static \
        --enable-thread-safe \
        --docdir=/usr/share/doc/mpfr-4.0.2
    make
    make html
    make check
    make install
    make install-html
    cd ..
    rm -rvf mpfr-*/

    # Install mpc.
    tar -xf mpc-*.tar.*
    cd mpc-*
    ./configure \
        --prefix=/usr \
        --disable-static \
        --docdir=/usr/share/doc/mpc-1.1.0
    make
    make html
    make check
    make install
    make install-html
    cd ..
    rm -rvf mpc-*/

    # Install attr.
    tar -xf attr-*.tar.*
    cd attr-*
    ./configure \
        --prefix=/usr \
        --disable-static \
        --sysconfdir=/etc \
        --docdir=/usr/share/doc/attr-2.4.48
    make
    make check
    make install
    mv -v /usr/lib/libattr.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
    cd ..
    rm -rvf attr-*/

    # Install acl.
    tar -xf acl-*.tar.*
    cd acl-*
    ./configure \
        --prefix=/usr \
        --disable-static \
        --libexecdir=/usr/lib \
        --docdir=/usr/share/doc/acl-2.2.53
    make
    make install
    mv -v /usr/lib/libacl.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
    cd ..
    rm -rvf acl-*/

    # Install shadow.
    tar -xf shadow-*.tar.*
    cd shadow-*
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;
    sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs
    # If you chose to build Shadow with Cracklib support, run the following:
    sed -i 's@DICTPATH.*@DICTPATH\t/lib/cracklib/pw_dict@' etc/login.defs
    sed -i 's/1000/999/' etc/useradd
    ./configure --sysconfdir=/etc --with-group-name-max-length=32
    make
    make install
    cd ..
    rm -rvf shadow-*/

    # Set password handling.
    pwconv
    grpconv
    printf -- "pw\npw\n" | passwd root
    # printf -- "
    # spawn passwd root
    # expect \"password: \"
    # send \"root\"
    # expect \"password: \"
    # send \"root\"
    # " \
    #     > "/tmp/${_script_name}.expect-input.tmp" 2>&1
    # expect "/tmp/${_script_name}.expect-input.tmp"

    # Install gcc.
    tar -xf gcc-*.tar.*
    cd gcc-*
    case $(uname -m) in
        x86_64)
            sed -e '/m64=/s/lib64/lib/' \
                -i.orig gcc/config/i386/t-linux64
        ;;
    esac
    sed -e '1161 s|^|//|' \
        -i libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cc
    mkdir -pv build
    cd build
    SED=sed \
    ../configure \
        --prefix=/usr \
        --enable-languages=c,c++ \
        --disable-multilib \
        --disable-bootstrap \
        --with-system-zlib
    make
    ulimit -s 32768
    chown -Rv nobody .
    su nobody -s /bin/bash -c "PATH=\"${PATH}\" make -k check"
    ../contrib/test_summary
    make install
    rm -rf /usr/lib/gcc/"$(gcc -dumpmachine)"/9.2.0/include-fixed/bits/
    chown -v -R root:root \
        /usr/lib/gcc/*linux-gnu/9.2.0/include{,-fixed}
    ln -sv ../usr/bin/cpp /lib
    ln -sv gcc /usr/bin/cc
    install -v -dm755 /usr/lib/bfd-plugins
    ln -sfv ../../libexec/gcc/"$(gcc -dumpmachine)"/9.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/
    cd ../..
    rm -rvf gcc-*/

    # Verify toolchain.
    _verify_toolchain 3 &> "${_script_path}/${_script_name}.test-log.tmp"
    grep -o '/usr/lib.*/crt[1in].*succeeded' "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "/usr/lib/gcc/x86_64-pc-linux-gnu/9.2.0/../../../../lib/crt1.o succeeded\n" \
        "/usr/lib/gcc/x86_64-pc-linux-gnu/9.2.0/../../../../lib/crti.o succeeded\n" \
        "/usr/lib/gcc/x86_64-pc-linux-gnu/9.2.0/../../../../lib/crtn.o succeeded\n\n"
    grep -B4 '^ /usr/include' "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "#include <...> search starts here:\n" \
        "/usr/lib/gcc/x86_64-pc-linux-gnu/9.2.0/include\n" \
        "/usr/local/include\n" \
        "/usr/lib/gcc/x86_64-pc-linux-gnu/9.2.0/include-fixed\n" \
        "/usr/include\n\n"
    grep 'SEARCH.*/usr/lib' "${_script_path}/${_script_name}.test-log.tmp" | sed 's|; |\n|g'
    printf -- \
        "Output of previous command should match the following on a 64bit system:\n" \
        "SEARCH_DIR(\"/usr/x86_64-pc-linux-gnu/lib64\")\n" \
        "SEARCH_DIR(\"/usr/local/lib64\")\n" \
        "SEARCH_DIR(\"/lib64\")\n" \
        "SEARCH_DIR(\"/usr/lib64\")\n" \
        "SEARCH_DIR(\"/usr/x86_64-pc-linux-gnu/lib\")\n" \
        "SEARCH_DIR(\"/usr/local/lib\")\n" \
        "SEARCH_DIR(\"/lib\")\n" \
        "SEARCH_DIR(\"/usr/lib\");\n\n" \
        "Output of previous command should match the following on a 32bit system:\n" \
        "SEARCH_DIR(\"/usr/i686-pc-linux-gnu/lib32\")\n" \
        "SEARCH_DIR(\"/usr/local/lib32\")\n" \
        "SEARCH_DIR(\"/lib32\")\n" \
        "SEARCH_DIR(\"/usr/lib32\")\n" \
        "SEARCH_DIR(\"/usr/i686-pc-linux-gnu/lib\")\n" \
        "SEARCH_DIR(\"/usr/local/lib\")\n" \
        "SEARCH_DIR(\"/lib\")\n" \
        "SEARCH_DIR(\"/usr/lib\");\n\n"
    grep "/lib.*/libc.so.6 " "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "attempt to open /lib/libc.so.6 succeeded\n\n"
    grep found "${_script_path}/${_script_name}.test-log.tmp"
    printf -- "Output of previous command should match the following:\n" \
        "found ld-linux-x86-64.so.2 at /lib/ld-linux-x86-64.so.2\n\n"
    mkdir -pv /usr/share/gdb/auto-load/usr/lib
    mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

    # Install pkg-config.
    tar -xf pkg-config-*.tar.*
    cd pkg-config-*
    ./configure \
        --prefix=/usr \
        --with-internal-glib \
        --disable-host-tool \
        --docdir=/usr/share/doc/pkg-config-0.29.2
    make
    make check
    make install
    cd ..
    rm -rvf pkg-config-*/

    # Install .
    tar -xf ncurses-*.tar.*
    cd ncurses-*
    sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
    ./configure --prefix=/usr \
        --mandir=/usr/share/man \
        --with-shared \
        --without-debug \
        --without-normal \
        --enable-pc-files \
        --enable-widec
    make
    make install
    mv -v /usr/lib/libncursesw.so.6* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
    for lib in ncurses form panel menu ; do
        rm -vf                    /usr/lib/lib${lib}.so
        echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
    done
    rm -vf /usr/lib/libcursesw.so
    printf -- "INPUT(-lncursesw)\n" > /usr/lib/libcursesw.so 2>&1
    ln -sfv libncurses.so /usr/lib/libcurses.so
    mkdir -pv /usr/share/doc/ncurses-6.2
    cp -v -R doc/* /usr/share/doc/ncurses-6.2
    # Note
    # The instructions above don't create non-wide-character Ncurses libraries since no package installed by compiling from sources would link against them at runtime. However, the only known binary-only applications that link against non-wide-character Ncurses libraries require version 5. If you must have such libraries because of some binary-only application or to be compliant with LSB, build the package again with the following commands:

    # make distclean
    # ./configure --prefix=/usr    \
    #             --with-shared    \
    #             --without-normal \
    #             --without-debug  \
    #             --without-cxx-binding \
    #             --with-abi-version=5
    # make sources libs
    # cp -av lib/lib*.so.5* /usr/lib
    cd ..
    rm -rvf ncurses-*/

    # Install libcap.
    tar -xf libcap-*.tar.*
    cd libcap-*
    sed -i '/install.*STA...LIBNAME/d' libcap/Makefile
    make lib=lib
    make test
    make lib=lib install
    chmod -v 755 /lib/libcap.so.2.31
    cd ..
    rm -rvf libcap-*/

    # Install sed.
    tar -xf sed-*.tar.*
    cd sed-*
    sed -i 's/usr/tools/' build-aux/help2man
    sed -i 's/testsuite.panic-tests.sh//' Makefile.in
    ./configure --prefix=/usr --bindir=/bin
    make
    make html
    make check
    make install
    install -d -m755 /usr/share/doc/sed-4.8
    install -m644 doc/sed.html /usr/share/doc/sed-4.8
    cd ..
    rm -rvf sed-*/

    # Install psmisc.
    tar -xf psmisc-*.tar.*
    cd psmisc-*
    ./configure --prefix=/usr
    make
    make install
    mv -v /usr/bin/fuser /bin
    mv -v /usr/bin/killall /bin
    cd ..
    rm -rvf psmisc-*/

    # Install iana-etc.
    tar -xf iana-etc-*.tar.*
    cd iana-etc-*
    make
    make install
    cd ..
    rm -rvf iana-etc-*/

    # Install bison.
    tar -xf bison-*.tar.*
    cd bison-*
    ./configure \
        --prefix=/usr \
        --docdir=/usr/share/doc/bison-3.5.2
    make
    make install
    cd ..
    rm -rvf bison-*/

    # Install flex.
    tar -xf flex-*.tar.*
    cd flex-*
    sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
    HELP2MAN=/tools/bin/true \
    ./configure \
        --prefix=/usr \
        --docdir=/usr/share/doc/flex-2.6.4
    make
    make check
    make install
    ln -sv flex /usr/bin/lex
    cd ..
    rm -rvf flex-*/

    # Install grep.
    tar -xf grep-*.tar.*
    cd grep-*
    ./configure \
        --prefix=/usr \
        --bindir=/bin
    make
    make check
    make install
    cd ..
    rm -rvf grep-*/

    # Install bash.
    tar -xf bash-*.tar.*
    cd bash-*
    patch -Np1 -i ../bash-5.0-upstream_fixes-1.patch
    ./configure --prefix=/usr \
        --docdir=/usr/share/doc/bash-5.0 \
        --without-bash-malloc \
        --with-installed-readline
    make
    chown -Rv nobody .
    su nobody -s /bin/bash -c "PATH=$PATH HOME=/home make tests"
    make install
    mv -vf /usr/bin/bash /bin
    cd ..
    rm -rvf bash-*/

    # Run the newly compiled bash program.
    exec /bin/bash --login +h

    # Install libtool.
    tar -xf libtool-*.tar.*
    cd libtool-*
    ./configure --prefix=/usr
    make
    make check
    make install
    cd ..
    rm -rvf libtool-*/

    # Install gdbm.
    tar -xf gdbm-*.tar.*
    cd gdbm-*
    ./configure --prefix=/usr \
        --disable-static \
        --enable-libgdbm-compat
    make
    make check
    make install
    cd ..
    rm -rvf gdbm-*/

    # Install gperf.
    tar -xf gperf-*.tar.*
    cd gperf-*
    ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
    make
    make -j1 check
    make install
    cd ..
    rm -rvf gperf-*/

    # Install xpat.
    tar -xf xpat-*.tar.*
    cd xpat-*
    sed -i 's|usr/bin/env |bin/|' run.sh.in
    ./configure \
        --prefix=/usr \
        --disable-static \
        --docdir=/usr/share/doc/expat-2.2.9
    make
    make check
    make install
    install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.9
    cd ..
    rm -rvf xpat-*/

    # Install inetutils.
    tar -xf inetutils-*.tar.*
    cd inetutils-*
    ./configure \
        --prefix=/usr \
        --localstatedir=/var \
        --disable-logger \
        --disable-whois \
        --disable-rcp \
        --disable-rexec \
        --disable-rlogin \
        --disable-rsh \
        --disable-servers
    make
    make check
    make install
    mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
    mv -v /usr/bin/ifconfig /sbin
    cd ..
    rm -rvf inetutils-*/

    # Install perl.
    tar -xf perl-*.tar.*
    cd perl-*
    echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
    export BUILD_ZLIB=False
    export BUILD_BZIP2=0
    sh Configure -des -Dprefix=/usr \
        -Dvendorprefix=/usr \
        -Dman1dir=/usr/share/man/man1 \
        -Dman3dir=/usr/share/man/man3 \
        -Dpager="/usr/bin/less -isR" \
        -Duseshrplib \
        -Dusethreads
    make
    make test
    make install
    unset BUILD_ZLIB BUILD_BZIP2
    cd ..
    rm -rvf perl-*/

    # Install XML-Parser.
    tar -xf XML-Parser-*.tar.*
    cd XML-Parser-*
    perl Makefile.PL
    make
    make test
    make install
    cd ..
    rm -rvf XML-Parser-*/

    # Install intltool.
    tar -xf intltool-*.tar.*
    cd intltool-*
    sed -i 's:\\\${:\\\$\\{:' intltool-update.in
    ./configure --prefix=/usr
    make
    make check
    make install
    install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
    cd ..
    rm -rvf intltool-*/

    # Install autoconf.
    tar -xf autoconf-*.tar.*
    cd autoconf-*
    sed '361 s/{/\\{/' -i bin/autoscan.in
    ./configure --prefix=/usr
    make
    make check
    make install
    cd ..
    rm -rvf autoconf-*/

    # Install automake.
    tar -xf automake-*.tar.*
    cd automake-*
    ./configure \
        --prefix=/usr \
        --docdir=/usr/share/doc/automake-1.16.1
    make
    # Using the -j4 make option speeds up the tests, even on systems with only one processor, due to internal delays in individual tests. To test the results, issue the following.
    make -j4 check
    make install
    cd ..
    rm -rvf automake-*/

    # Install kmod.
    tar -xf kmod-*.tar.*
    cd kmod-*
    ./configure \
        --prefix=/usr \
        --bindir=/bin \
        --sysconfdir=/etc \
        --with-rootlibdir=/lib \
        --with-xz \
        --with-zlib
    make
    make install
    for target in depmod insmod lsmod modinfo modprobe rmmod; do
        ln -sfv ../bin/kmod /sbin/$target
    done
    ln -sfv kmod /bin/lsmod
    cd ..
    rm -rvf kmod-*/

    # Install gettext.
    tar -xf gettext-*.tar.*
    cd gettext-*
    ./configure \
        --prefix=/usr \
        --disable-static \
        --docdir=/usr/share/doc/gettext-0.20.1
    make
    make check
    make install
    chmod -v 0755 /usr/lib/preloadable_libintl.so
    cd ..
    rm -rvf gettext-*/

    # Install libelf from elfutils.
    tar -xf elfutils-*.tar.*
    cd elfutils-*
    ./configure --prefix=/usr --disable-debuginfod
    make
    make check
    make -C libelf install
    install -vm644 config/libelf.pc /usr/lib/pkgconfig
    rm /usr/lib/libelf.a
    cd ..
    rm -rvf elfutils-*/

    # Install libffi.
    tar -xf libffi-*.tar.*
    cd libffi-*
    ./configure --prefix=/usr --disable-static --with-gcc-arch=native
    make
    make check
    make install
    cd ..
    rm -rvf libffi-*/

    # Install openssl.
    tar -xf openssl-*.tar.*
    cd openssl-*
    ./config \
        --prefix=/usr \
        --openssldir=/etc/ssl \
        --libdir=lib \
        shared \
        zlib-dynamic
    make
    make test
    sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
    make MANSUFFIX=ssl install
    mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1d
    cp -vfr doc/* /usr/share/doc/openssl-1.1.1d
    cd ..
    rm -rvf openssl-*/

    # Install python.
    tar -xf python-*.tar.*
    cd python-*
    ./configure \
        --prefix=/usr \
        --enable-shared \
        --with-system-expat \
        --with-system-ffi \
        --with-ensurepip=yes
    make
    make install
    chmod -v 755 /usr/lib/libpython3.8.so
    chmod -v 755 /usr/lib/libpython3.so
    ln -sfv pip3.8 /usr/bin/pip3
    install -v -dm755 /usr/share/doc/python-3.8.1/html
    tar \
        --strip-components=1 \
        --no-same-owner \
        --no-same-permissions \
        -C /usr/share/doc/python-3.8.1/html \
        -xvf ../python-3.8.1-docs-html.tar.bz2
    cd ..
    rm -rvf python-*/

    # Install ninja.
    tar -xf ninja-*.tar.*
    cd ninja-*
    export NINJAJOBS=4
    sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
    python3 configure.py --bootstrap
    ./ninja ninja_test
    ./ninja_test --gtest_filter=-SubprocessTest.SetWithLots
    install -vm755 ninja /usr/bin/
    install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
    install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
    cd ..
    rm -rvf ninja-*/

    # Install meson.
    tar -xf meson-*.tar.*
    cd meson-*
    python3 setup.py build
    python3 setup.py install --root=dest
    cp -rv dest/* /
    cd ..
    rm -rvf meson-*/

    # Install coreutils.
    tar -xf coreutils-*.tar.*
    cd coreutils-*
    patch -Np1 -i ../coreutils-8.31-i18n-1.patch
    sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
    autoreconf -fiv
    FORCE_UNSAFE_CONFIGURE=1 ./configure \
        --prefix=/usr \
        --enable-no-install-program=kill,uptime
    make
    make NON_ROOT_USERNAME=nobody check-root
    echo "dummy:x:1000:nobody" >> /etc/group
    chown -Rv nobody .
    su nobody -s /bin/bash \
        -c "PATH=${PATH} make RUN_EXPENSIVE_TESTS=yes check"
    sed -i '/dummy/d' /etc/group
    make install
    mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
    mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
    mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
    mv -v /usr/bin/chroot /usr/sbin
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
    sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
    mv -v /usr/bin/{head,nice,sleep,touch} /bin
    cd ..
    rm -rvf coreutils-*/

    # Install check.
    tar -xf check-*.tar.*
    cd check-*
    ./configure --prefix=/usr
    make
    make check
    make docdir=/usr/share/doc/check-0.14.0 install &&
    sed -i '1 s/tools/usr/' /usr/bin/checkmk
    cd ..
    rm -rvf check-*/

    # Install diffutils.
    tar -xf diffutils-*.tar.*
    cd diffutils-*
    ./configure --prefix=/usr
    make
    make check
    make install
    cd ..
    rm -rvf diffutils-*/

    # Install gawk.
    tar -xf gawk-*.tar.*
    cd gawk-*
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr
    make
    make check
    make install
    mkdir -v /usr/share/doc/gawk-5.0.1
    cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.0.1
    cd ..
    rm -rvf gawk-*/

    # Install findutils.
    tar -xf findutils-*.tar.*
    cd findutils-*
    ./configure --prefix=/usr --localstatedir=/var/lib/locate
    make
    make check
    make install
    mv -v /usr/bin/find /bin
    sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb
    cd ..
    rm -rvf findutils-*/

    # Install groff.
    tar -xf groff-*.tar.*
    cd groff-*
    PAGE=A4 ./configure --prefix=/usr
    make -j1
    make install
    cd ..
    rm -rvf groff-*/

    # Install grub.
    tar -xf grub-*.tar.*
    cd grub-*
    ./configure --prefix=/usr \
        --sbindir=/sbin \
        --sysconfdir=/etc \
        --disable-efiemu \
        --disable-werror
    make
    make install
    mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
    cd ..
    rm -rvf grub-*/

    # Install less.
    tar -xf less-*.tar.*
    cd less-*
    ./configure --prefix=/usr --sysconfdir=/etc
    make
    make install
    cd ..
    rm -rvf less-*/

    # Install gzip.
    tar -xf gzip-*.tar.*
    cd gzip-*
    ./configure --prefix=/usr
    make
    make check
    make install
    mv -v /usr/bin/gzip /bin
    cd ..
    rm -rvf gzip-*/

    # Install zstd.
    tar -xf zstd-*.tar.*
    cd zstd-*
    make
    make prefix=/usr install
    rm -v /usr/lib/libzstd.a
    mv -v /usr/lib/libzstd.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libzstd.so) /usr/lib/libzstd.so
    cd ..
    rm -rvf zstd-*/

    # Install iproute2.
    tar -xf iproute2-*.tar.*
    cd iproute2-*
    sed -i /ARPD/d Makefile
    rm -fv man/man8/arpd.8
    sed -i 's/.m_ipt.o//' tc/Makefile
    make
    make DOCDIR=/usr/share/doc/iproute2-5.5.0 install
    cd ..
    rm -rvf iproute2-*/

    # Install kbd.
    tar -xf kbd-*.tar.*
    cd kbd-*
    patch -Np1 -i ../kbd-2.2.0-backspace-1.patch
    sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
    sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
    PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock
    make
    make check
    make install
    mkdir -pv/usr/share/doc/kbd-2.2.0
    cp -R -v docs/doc/* /usr/share/doc/kbd-2.2.0
    cd ..
    rm -rvf kbd-*/

    # Install libpipeline.
    tar -xf libpipeline-*.tar.*
    cd libpipeline-*
    ./configure --prefix=/usr
    make
    make check
    make install
    cd ..
    rm -rvf libpipeline-*/

    # Install make.
    tar -xf make-*.tar.*
    cd make-*
    ./configure --prefix=/usr
    make
    make PERL5LIB="${PWD}"/tests/ check
    make install
    cd ..
    rm -rvf make-*/

    # Install patch.
    tar -xf patch-*.tar.*
    cd patch-*
    ./configure --prefix=/usr
    make
    make check
    make install
    cd ..
    rm -rvf patch-*/

    # Install man-db.
    tar -xf man-db-*.tar.*
    cd man-db-*
    sed -i '/find/s@/usr@@' init/systemd/man-db.service.in
    ./configure \
        --prefix=/usr \
        --docdir=/usr/share/doc/man-db-2.9.0 \
        --sysconfdir=/etc \
        --disable-setuid \
        --enable-cache-owner=bin \
        --with-browser=/usr/bin/lynx \
        --with-vgrind=/usr/bin/vgrind \
        --with-grap=/usr/bin/grap
    make
    make check
    make install
    cd ..
    rm -rvf man-db-*/

    # Install tar.
    tar -xf tar-*.tar.*
    cd tar-*
    FORCE_UNSAFE_CONFIGURE=1  \
    ./configure \
        --prefix=/usr \
        --bindir=/bin
    make
    make check
    make install
    make -C doc install-html docdir=/usr/share/doc/tar-1.32
    cd ..
    rm -rvf tar-*/

    # Install texinfo.
    tar -xf texinfo-*.tar.*
    cd texinfo-*
    ./configure --prefix=/usr --disable-static
    make
    make check
    make install
    make TEXMF=/usr/share/texmf install-tex
    pushd /usr/share/info
    rm -v dir
    for f in *
        do install-info $f dir 2>/dev/null
    done
    popd
    cd ..
    rm -rvf texinfo-*/

    # Install vim.
    tar -xf vim-*.tar.*
    cd vim-*
    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
    ./configure --prefix=/usr
    make
    chown -Rv nobody .
    su nobody -s /bin/bash -c "LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
    make install
    ln -sv vim /usr/bin/vi
    for L in  /usr/share/man/{,*/}man1/vim.1; do
        ln -sv vim.1 $(dirname $L)/vi.1
    done
    ln -sv ../vim/vim82/doc /usr/share/doc/vim-8.2.0190
    cd ..
    rm -rvf vim-*/

    # Configure vim.
    cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF

    # Install systemd.
    tar -xf systemd-*.tar.*
    cd systemd-*
    ln -sf /tools/bin/true /usr/bin/xsltproc
    for file in /tools/lib/lib{blkid,mount,uuid}.so*; do
        ln -sf $file /usr/lib/
    done
    tar -xf ../systemd-man-pages-244.tar.xz
    sed '177,$ d' -i src/resolve/meson.build
    sed -i 's/GROUP="render", //' rules.d/50-udev-default.rules.in
    mkdir -p build
    cd build
    PKG_CONFIG_PATH="/usr/lib/pkgconfig:/tools/lib/pkgconfig" \
    LANG=en_US.UTF-8 meson \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        -Dblkid=true \
        -Dbuildtype=release \
        -Ddefault-dnssec=no \
        -Dfirstboot=false \
        -Dinstall-tests=false \
        -Dkmod-path=/bin/kmod \
        -Dldconfig=false \
        -Dmount-path=/bin/mount \
        -Drootprefix= \
        -Drootlibdir=/lib \
        -Dsplit-usr=true \
        -Dsulogin-path=/sbin/sulogin \
        -Dsysusers=false \
        -Dumount-path=/bin/umount \
        -Db_lto=false \
        -Drpmmacrosdir=no \
        ..
    LANG=en_US.UTF-8 ninja
    LANG=en_US.UTF-8 ninja install
    rm -f /usr/bin/xsltproc
    systemd-machine-id-setup
    systemctl preset-all
    systemctl disable systemd-time-wait-sync.service
    rm -fv /usr/lib/lib{blkid,uuid,mount}.so*
    cd ../..
    rm -rvf systemd-*/

    # Install dbus.
    tar -xf dbus-*.tar.*
    cd dbus-*
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --disable-static \
        --disable-doxygen-docs \
        --disable-xml-docs \
        --docdir=/usr/share/doc/dbus-1.12.16 \
        --with-console-auth-dir=/run/console
    make
    make install
    mv -v /usr/lib/libdbus-1.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libdbus-1.so) /usr/lib/libdbus-1.so
    ln -sfv /etc/machine-id /var/lib/dbus
    cd ..
    rm -rvf dbus-*/

    # Install procps-ng.
    tar -xf procps-ng-*.tar.*
    cd procps-ng-*
    ./configure \
        --prefix=/usr \
        --exec-prefix= \
        --libdir=/usr/lib \
        --docdir=/usr/share/doc/procps-ng-3.3.15 \
        --disable-static \
        --disable-kill \
        --with-systemd
    make
    sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
    sed -i '/set tty/d' testsuite/pkill.test/pkill.exp
    rm testsuite/pgrep.test/pgrep.exp
    make check
    make install
    mv -v /usr/lib/libprocps.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
    cd ..
    rm -rvf procps-ng-*/

    # Install util-linux.
    tar -xf util-linux-*.tar.*
    cd util-linux-*
    mkdir -pv /var/lib/hwclock
    rm -vf /usr/include/{blkid,libmount,uuid}
    ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
        --docdir=/usr/share/doc/util-linux-2.35.1 \
        --disable-chfn-chsh \
        --disable-login \
        --disable-nologin \
        --disable-su \
        --disable-setpriv \
        --disable-runuser \
        --disable-pylibmount \
        --disable-static \
        --without-python
    make
    chown -Rv nobody .
    su nobody -s /bin/bash -c "PATH=${PATH} make -k check"
    make install
    cd ..
    rm -rvf util-linux-*/

    # Install e2fsprogs.
    tar -xf e2fsprogs-*.tar.*
    cd e2fsprogs-*
    mkdir -pv build
    cd build
    ../configure \
        --prefix=/usr \
        --bindir=/bin \
        --with-root-prefix="" \
        --enable-elf-shlibs \
        --disable-libblkid \
        --disable-libuuid \
        --disable-uuidd \
        --disable-fsck
    make
    make check
    make install
    chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
    gunzip -v /usr/share/info/libext2fs.info.gz
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
    makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
    install -v -m644 doc/com_err.info /usr/share/info
    install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
    cd ..
    rm -rvf e2fsprogs-*/

    # Cleanup some extra files left over from testing,
    rm -rvf /tmp/*

    # Relog into chroot environment with updated command.
    # The reason for this is that the programs in /tools are no longer needed. For this reason you can delete the /tools directory if so desired.
    logout
    chroot "${_build_root}" \
        /usr/bin/env -i \
        HOME=/root \
        TERM="${TERM}" \
        PS1="(lfs chroot) \u:\w\\$ " \
        PATH=/bin:/usr/bin:/sbin:/usr/sbin \
        /bin/bash --login

    # Remove unneeded files.
    rm -f /usr/lib/lib{bfd,opcodes}.a
    rm -f /usr/lib/libbz2.a
    rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
    rm -f /usr/lib/libltdl.a
    rm -f /usr/lib/libfl.a
    rm -f /usr/lib/libz.a
    find /usr/lib /usr/libexec -name \*.la -delete

    # # Unmount img file.
    # losetup -d "${_target_storage_device}"

    # <http://www.linuxfromscratch.org/lfs/downloads/stable-systemd/LFS-BOOK-9.1-systemd-NOCHUNKS.html#ch-config-network>
    # # Install .
    #     tar -xf -*.tar.*
    #     cd -*
    #     cd ..
    #     rm -rvf -*/
}

set -e
_script_name="$(basename -- "${0}")"
_script_path="$(dirname -- "${0}")"
_script_path="$(cd "${_script_path}" ; pwd)"
_script_args="$(printf -- "%s\n" "${@}")"
mkdir -p -- "${_script_path}/${_script_name}-logs"
_main "${@}" | tee -a -- "${_script_path}/${_script_name}-logs/$(date --utc +%Y-%m-%d_%H-%M-%S)_UTC.log"

)
