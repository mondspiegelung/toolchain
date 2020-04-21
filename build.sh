#!/bin/bash

renice -n 19 -p $$

BASE_DIR=$(realpath $(dirname $0))

TC_VERSION=${TC_VERSION:-toolchain-9.x}
SOURCE_DIR=${SOURCE_DIR:-${BASE_DIR}/SOURCE}
BUILD_DIR=${BUILD_DIR:-/scratch/BUILD}
INSTALL_DIR=${INSTALL_DIR:-${HOME}/opt/${TC_VERSION}}

echo "Starting build of toolchain..."
echo -e "\tArchive dowload directory = $SOURCE_DIR"
echo -e "\tPackage build directory = $BUILD_DIR"
echo -e "\tToolchain installation directory = $INSTALL_DIR"

PARALLEL="-j $(( $(nproc) ))"
OUT=/dev/null
#OUT=/dev/stderr

# this is used to format the 'time' builtin's output at the end of build steps
export TIMEFORMAT=$'    (%P%%) real: %lR, user: %lU, sys: %lS'

# add our install directory to our path
export PATH="${INSTALL_DIR}/bin:$PATH"

# and ${INSTALL_DIR}/lib to LD_RUN_PATH - we use this to set the DT_RUNPATH
# ELF attribute so that LD_LIBRARY_PATH can override it for users if needed
# export LD_RUN_PATH=${INSTALL_DIR}/lib:$LD_RUN_PATH

# FIXME - this may not be necessary
export PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig:$PKG_CONFIG_PATH

DO_TESTS=1

##
# Pulls the top-level directory name out of a tarbal
##
function get_name()
{
	archive="$1"
	dest="$2"

	case $archive in
	 *.tar.gz|*.tgz)	uncat=zcat ;;
	 *.tar.xz)			uncat=xzcat ;;
	 *.tar.bz2)			uncat=bzcat ;;
	 *)					exit 1 ;;
	esac

	$uncat $archive | tar -C $dest -tf - | sed -e 's!/.*!!g' | head -1
}

##
# Unpacks a tarbal, returning its top-level directory name
##
function unpack()
{
	archive="$1"
	dest="$2"

	case $archive in
	 *.tar.gz|*.tgz)	uncat=zcat ;;
	 *.tar.xz)			uncat=xzcat ;;
	 *.tar.bz2)			uncat=bzcat ;;
	 *)					exit 1 ;;
	esac

	time $uncat $archive | tar -C $dest -xvf - | sed -e 's!/.*!!g' | uniq
}

######################################################################
function build_zlib()
{
	dir="$1"
	cd $1
	echo "Configuring zlib... "
	time CFLAGS='-O3 -march=native' ./configure \
		--prefix=${INSTALL_DIR} \
		2>&1 | \
		tee ${BUILD_DIR}/zlib-config.log > $OUT

	echo "Building zlib... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/zlib-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking zlib... "
		time make ${PARALLEL} check \
			2>&1 | tee ${BUILD_DIR}/zlib-check.log > $OUT
	fi

	echo "Installing zlib... "
	time make install 2>&1 | tee ${BUILD_DIR}/zlib-install.log > $OUT

	echo "Completed zlib: "
}

######################################################################
function build_guile()
{
	dir="$1"

	cd "$1"

	echo "Configuring guile... "
	time CFLAGS='-O3 -march=native' ./configure  \
		--prefix=${INSTALL_DIR} \
		--disable-static \
		--with-sysroot=${INSTALL_DIR} \
		--with-libgmp-prefix=${INSTALL_DIR} \
		2>&1 | tee ${BUILD_DIR}/guile-config.log > $OUT

	echo "Building guile... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/guile-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking guile... "
		time make check 2>&1 | tee ${BUILD_DIR}/guile-check.log > $OUT
	fi

	echo "Installing guile... "
	time make install 2>&1 | tee ${BUILD_DIR}/guile-install.log > $OUT

	echo "Completed guile: "
}

######################################################################
function build_autogen()
{
	dir="$1"
	cd $1
	echo "Configuring autogen... "
	time ./configure --prefix=${INSTALL_DIR} 2>&1 | \
		tee ${BUILD_DIR}/autogen-config.log > $OUT

	echo "Building autogen... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/autogen-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking autogen... "
		time make check 2>&1 | tee ${BUILD_DIR}/autogen-check.log > $OUT
	fi

	echo "Installing autogen... "
	time make install 2>&1 | tee ${BUILD_DIR}/autogen-install.log > $OUT

	echo "Completed autogen: "
}

######################################################################
function build_gmp()
{
	dir="$1"
	cd $1
	echo "Configuring gmp... "
	time CFLAGS='-O3 -march=native' ./configure \
		--prefix=${INSTALL_DIR} \
		--enable-cxx \
		--disable-static \
		2>&1 | \
		tee ${BUILD_DIR}/gmp-config.log > $OUT

	echo "Building gmp... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/gmp-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking gmp... "
		time make ${PARALLEL} check \
			2>&1 | tee ${BUILD_DIR}/gmp-check.log > $OUT
	fi

	echo "Installing gmp... "
	time make install 2>&1 | tee ${BUILD_DIR}/gmp-install.log > $OUT

	echo "Completed gmp: "
}

######################################################################
function build_mpfr()
{
	dir="$1"
	cd $1
	echo "Configuring mpfr... "
	time CFLAGS='-O3 -march=native' ./configure \
		--prefix=${INSTALL_DIR} \
		--with-gmp=${INSTALL_DIR} \
		--disable-static \
		2>&1 | \
		tee ${BUILD_DIR}/mpfr-config.log > $OUT

	echo "Building mpfr... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/mpfr-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking mpfr... "
		time make ${PARALLEL} check \
			2>&1 | tee ${BUILD_DIR}/mpfr-check.log > $OUT
	fi

	echo "Installing mpfr... "
	time make install 2>&1 | tee ${BUILD_DIR}/mpfr-install.log > $OUT

	echo "Completed mpfr: "
}

######################################################################
function build_mpc()
{
	dir="$1"
	cd $1
	echo "Configuring mpc... "
	time CFLAGS='-O3 -march=native' ./configure \
		--prefix=${INSTALL_DIR} \
		--with-gmp=${INSTALL_DIR} \
		--with-mpfr=${INSTALL_DIR} \
		--disable-static \
		2>&1 | \
		tee ${BUILD_DIR}/mpc-config.log > $OUT

	echo "Building mpc... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/mpc-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking mpc... "
		time make ${PARALLEL} check \
			2>&1 | tee ${BUILD_DIR}/mpc-check.log > $OUT
	fi

	echo "Installing mpc... "
	time make install 2>&1 | tee ${BUILD_DIR}/mpc-install.log > $OUT

	echo "Completed mpc: "
}

######################################################################
function build_isl()
{
	dir="$1"
	cd $1
	echo "Configuring isl... "
	time CFLAGS='-O3 -march=native' ./configure \
		--prefix=${INSTALL_DIR} \
		--with-gcc-arch=native \
		--with-gmp-prefix=${INSTALL_DIR} \
		--disable-static \
		2>&1 | \
		tee ${BUILD_DIR}/isl-config.log > $OUT

	echo "Building isl... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/isl-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking isl... "
		time make ${PARALLEL} check \
			2>&1 | tee ${BUILD_DIR}/isl-check.log > $OUT
	fi

	echo "Installing isl... "
	time make install 2>&1 | tee ${BUILD_DIR}/isl-install.log > $OUT

	echo "Completed isl: "
}

######################################################################
function build_binutils()
{
	dir="$1"
	echo "Configuring binutils... "

	mkdir ${BUILD_DIR}/binutils-build
	cd ${BUILD_DIR}/binutils-build
	time CFLAGS="-I${INSTALL_DIR}/include -L${INSTALL_DIR}/lib" \
		${dir}/configure \
			--prefix=${INSTALL_DIR} \
			--with-build-time-tools=${INSTALL_DIR} \
			--with-stage1-ldflags="-Wl,-rpath,${INSTALL_DIR}/lib" \
			--with-boot-ldflags="-Wl,-rpath,${INSTALL_DIR}/lib" \
			--with-system-zlib \
			--enable-gold \
			--with-gmp=${INSTALL_DIR} \
			--with-mpfr=${INSTALL_DIR} \
			--with-mpc=${INSTALL_DIR} \
			--with-isl=${INSTALL_DIR} \
			--enable-lto \
			2>&1 | tee ${BUILD_DIR}/binutils-config.log > $OUT

	echo "Building binutils... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/binutils-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Checking binutils... "
		time make check
			2>&1 | tee ${BUILD_DIR}/binutils-check.log > $OUT
	fi

	echo "Installing binutils... "
	time make install 2>&1 | tee ${BUILD_DIR}/binutils-install.log > $OUT

	echo "Completed binutils: "
}

######################################################################
function build_gcc()
{
	dir="$1"
	echo "Configuring gcc... "

	mkdir ${BUILD_DIR}/gcc-build
	cd ${BUILD_DIR}/gcc-build
	time BOOT_LDFLAGS="-L${INSTALL_DIR}/lib -Wl,-rpath,${INSTALL_DIR}/lib" \
		CFLAGS="-O3 -march=native" ${dir}/configure \
		--prefix=${INSTALL_DIR} \
		--with-gnu-as \
		--with-gnu-ld \
		--with-as=${INSTALL_DIR}/bin/as \
		--with-ld=${INSTALL_DIR}/bin/ld \
		--with-system-zlib \
		--with-gmp=${INSTALL_DIR} \
		--with-mpfr=${INSTALL_DIR} \
		--with-mpc=${INSTALL_DIR} \
		--with-isl=${INSTALL_DIR} \
		--enable-languages=c,c++ \
		--enable-__cxa_atexit \
		--enable-lto \
		--disable-multilib \
		2>&1 | \
		tee ${BUILD_DIR}/gcc-config.log > $OUT

	echo "Building gcc... "
	time make ${PARALLEL} \
		BOOT_LDFLAGS="-L${INSTALL_DIR}/lib -Wl,-rpath,${INSTALL_DIR}/lib" \
		2>&1 | tee ${BUILD_DIR}/gcc-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		date +"(%T)"
		echo "Checking gcc... "
		time make -k ${PARALLEL} \
			BOOT_LDFLAGS="-L${INSTALL_DIR}/lib  -Wl,-rpath,${INSTALL_DIR}/lib" \
			check \
			2>&1 | tee ${BUILD_DIR}/gcc-check.log > $OUT
	fi

	echo "Installing gcc... "
	time make \
		BOOT_LDFLAGS="-L${INSTALL_DIR}/lib -Wl,-rpath,${INSTALL_DIR}/lib" \
		install-strip \
		2>&1 | tee ${BUILD_DIR}/gcc-install.log > $OUT

	specfile=$(dirname $(${INSTALL_DIR}/bin/gcc -print-libgcc-file-name))/specs

	cat <<- EOF > edit.sed
	/^\*link:$/ {
		n
		s@--eh-frame-hdr} @& %{!shared: %{!static: -rpath ${INSTALL_DIR}/lib}}\t@
	}
	EOF

	${INSTALL_DIR}/bin/gcc -dumpspecs | sed -f edit.sed > ${specfile}
	rm -f edit.sed


	echo "Completed gcc: "
}

######################################################################
function build_xz()
{
	dir="$1"
	cd $1
	echo "Configuring xz... "
	time CFLAGS='-O3 -march=native' ./configure \
		--prefix=${INSTALL_DIR} \
		--disable-static \
		2>&1 | \
		tee ${BUILD_DIR}/xz-config.log > $OUT

	echo "Building xz... "
	time make ${PARALLEL} 2>&1 | tee ${BUILD_DIR}/xz-build.log > $OUT

	echo "Checking xz... "
	time make ${PARALLEL} check 2>&1 | tee ${BUILD_DIR}/xz-check.log > $OUT

	echo "Installing xz... "
	time make install 2>&1 | tee ${BUILD_DIR}/xz-install.log > $OUT

	echo "Completed xz: "
}

######################################################################
function build_llvm()
{
	dir="$1"

	mv ${dir}/../clang-9.0.1.src tools/clang
	mv ${dir}/../clang-tools-extra-9.0.1.src tools/clang/tools/extra
	mv ${dir}/../compiler-rt-9.0.1.src projects/compiler-rt
	mv ${dir}/../libcxx-9.0.1.src projects/libcxx
	mv ${dir}/../libcxxabi-9.0.1.src projects/libcxxabi
	mv ${dir}/../lld-9.0.1.src tools/lld

	echo "Configuring llvm/clang... "

	mkdir ${BUILD_DIR}/llvm-build
	cd ${BUILD_DIR}/llvm-build

	time cmake -GNinja \
		-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
		-DGCC_INSTALL_PREFIX=${INSTALL_DIR} \
		-DCMAKE_C_COMPILER=${INSTALL_DIR}/bin/gcc \
		-DCMAKE_CXX_COMPILER=${INSTALL_DIR}/bin/g++ \
		-DCMAKE_CXX_LINK_FLAGS="-L${INSTALL_DIR}/lib -Wl,-rpath,${INSTALL_DIR}/lib" \
		-DLLVM_TARGETS_TO_BUILD="X86" \
		-DCMAKE_BUILD_TYPE="Release" \
		-DPYTHON_EXECUTABLE="/usr/bin/python3" \
		-DLLVM_ENABLE_ASSERTIONS=On \
		-DCMAKE_INSTALL_DO_STRIP=1 \
		$dir \
		2>&1 | tee ${BUILD_DIR}/llvm-config.log > $OUT

	echo "Building llvm/clang..."
	time ninja \
		2>&1 | tee ${BUILD_DIR}/llvm-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		echo "Testing llvm/clang..."
		time ninja -k 0 check-clang \
			2>&1 | tee ${BUILD_DIR}/llvm-check.log > $OUT

		echo "Testing llvm/libcxx..."
		time ninja -k 0 check-libcxx \
			2>&1 | tee -a ${BUILD_DIR}/llvm-check.log > $OUT
	fi

	echo "Installing llvm/clang..."
	time ninja install \
		2>&1 | tee ${BUILD_DIR}/llvm-install.log > $OUT

	echo "Completed llvm/clang: "
}

######################################################################
function build_vim()
{
	dir="$1"

	pwd
	echo "Configuring vim..."

	./configure --with-features=huge \
		--enable-multibyte \
		--enable-rubyinterp=yes \
		--enable-python3interp=yes \
		--with-python3-config-dir=$(python3-config --configdir) \
		--enable-perlinterp=yes \
		--enable-luainterp=yes \
		--enable-gui=gtk2 \
		--enable-cscope \
		--prefix=${INSTALL_DIR} \
		2>&1 | tee ${BUILD_DIR}/vim-config.log > $OUT

	echo "Building vim..."
	time make ${PARALLEL} VIMRUNTIMEDIR=${INSTALL_DIR}/share/vim/vim82 \
		2>&1 | tee ${BUILD_DIR}/vim-build.log > $OUT

	if [ "$DO_TESTS" -eq "1" ]
	then
		# FIXME: VIM doesn't appear to have a functional test suite
		true
	fi

	echo "Installing vim..."
	time make install \
		2>&1 | tee ${BUILD_DIR}/vim-install.log > $OUT

	echo "Completed vim: "
}

######################################################################

LLVMLOC="https://github.com/llvm/llvm-project/releases/download"

xPackages="
	https://tukaani.org/xz/xz-5.2.5.tar.xz

	https://www.python.org/ftp/python/3.8.2/Python-3.8.2.tar.xz
"

PACKAGES="
	https://www.zlib.net/zlib-1.2.11.tar.gz
	ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
	https://ftp.gnu.org/gnu/guile/guile-2.0.14.tar.xz
	http://ftp.gnu.org/gnu/autogen/autogen-5.18.7.tar.xz
	ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2
	ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz
	ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2
	http://mirror.us-midwest-1.nexcess.net/gnu/binutils/binutils-2.34.tar.xz
	https://bigsearcher.com/mirrors/gcc/releases/gcc-9.3.0/gcc-9.3.0.tar.xz

	${LLVMLOC}/llvmorg-9.0.1/clang-9.0.1.src.tar.xz
	${LLVMLOC}/llvmorg-9.0.1/clang-tools-extra-9.0.1.src.tar.xz
	${LLVMLOC}/llvmorg-9.0.1/compiler-rt-9.0.1.src.tar.xz
	${LLVMLOC}/llvmorg-9.0.1/libcxx-9.0.1.src.tar.xz
	${LLVMLOC}/llvmorg-9.0.1/libcxxabi-9.0.1.src.tar.xz
	${LLVMLOC}/llvmorg-9.0.1/lld-9.0.1.src.tar.xz
	${LLVMLOC}/llvmorg-9.0.1/llvm-9.0.1.src.tar.xz

	https://github.com/vim/vim.git
"

rm -rf $BUILD_DIR

mkdir -p $SOURCE_DIR
mkdir -p $BUILD_DIR
mkdir -p ${INSTALL_DIR}/lib
if [ ! -L ${INSTALL_DIR}/lib ]
then
	ln -s lib ${INSTALL_DIR}/lib64
fi
cd ${INSTALL_DIR}
git init .

UPDATE_REPOS=1

for pkg in $PACKAGES
do
	COMMIT=0
	echo "(" $(date +%T) ") " "================================================================="


	case $pkg in
	 http*.git)
		project_name=$(basename $pkg .git)
		repo=${SOURCE_DIR}/gitrepo-${project_name}

		if [ ! -d "$repo" ]
		then
			git clone $pkg $repo
		fi

		cd $repo

		if [ "$UPDATE_REPOS" -eq "1" ]
		then
			git fetch --all
			git pull
		fi

		version=$(git describe --tags | sed -e 's/^[vV]//g')
		name=${project_name}-${version}
		archive_base=${name}.tar.xz
		archive=${SOURCE_DIR}/${name}.tar.xz

		if [ ! -f ${archive} ]
		then
			git archive -9 \
				--prefix=${project_name}-${version}/ \
				--output=${archive} \
				HEAD
		fi
		;;
	 *)
		archive_base=$(basename $pkg)
		archive=${SOURCE_DIR}/${archive_base}

		if [ ! -f $archive ]
		then
			echo "Fetching $pkg..."
			time wget --no-verbose -P $SOURCE_DIR $pkg
		fi

		name=$(get_name $archive $BUILD_DIR)
		;;
	esac

	cd $INSTALL_DIR

	if git tag | grep -q ${name%.src}
	then
		echo "Skipping build of $name"
		continue
	fi

	echo "Unpacking $(basename $archive)..."
	name=$(unpack $archive $BUILD_DIR)
	dir=${BUILD_DIR}/${name}

	cd $dir

	case $name in
	 autogen*|zlib*|gmp*|guile*|mpfr*|mpc*|isl*|binutils*|gcc*|xz*|vim*)
		time build_${name%%-*} $dir
		COMMIT=1
		;;
	 llvm*)
		name=${name%.src}
		mv $dir ${dir%.src}
		dir=${dir%.src}
		cd $dir
		time build_${name%%-*} $dir
		COMMIT=1
		;;
	 *)
		;;
	esac

	if [ "$COMMIT" = 1 ]
	then
		cd ${INSTALL_DIR}
		git add *
		git commit -q -m "$name"
		git tag "$name"
	fi
done

echo "Detected Failures:"
grep FAIL ${BUILD_DIR}/*.log | egrep -v 'FAIL: *0$'
