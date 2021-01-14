#!zsh
set -e # abort if any command fails

MIN_IOS_VERSION=13
MIN_MAC_VERSION=11
PROJ_ROOT=${PWD}
DEPS_ROOT=${PROJ_ROOT}/deps
BUILD_ROOT=${PROJ_ROOT}/build
BUILD_LOG=${PROJ_ROOT}/buildlog.txt
CPU_COUNT=$(sysctl hw.ncpu | awk '{print $2}')

mkdir -p ${BUILD_ROOT}
echo -n > ${BUILD_LOG}

# Terminal colors
RED=`tput setaf 1`
GREEN=`tput setaf 2`
BLUE=`tput setaf 4`
CYAN=`tput setaf 6`
RESET=`tput sgr0`

progress_section() (
  MESSAGE="=== ${1} ==="
  echo ${MESSAGE}
  echo "${CYAN}${MESSAGE}${RESET}" >&3
)

progress_item() (
  MESSAGE="== ${1} =="
  echo ${MESSAGE}
  echo "${BLUE}${MESSAGE}${RESET}" >&3
)

progress_success() (
  MESSAGE="==== ${1} ===="
  echo ${MESSAGE}
  echo "${GREEN}${MESSAGE}${RESET}" >&3
)

progress_error() (
  MESSAGE="** ${1} **"
  echo ${MESSAGE}
  echo "${RED}${MESSAGE}${RESET}" >&3
)

get_dependencies() (
  progress_section "Getting Dependencies"
  git submodule update --init
)

build_init()
{
  LIB_NAME=$1
  TARGET=$2
  SDK=$3
  BITCODE=$4
  VERSION=$5
  SDK_PATH=`xcrun -sdk ${SDK} --show-sdk-path`
  BUILD_ARCH_DIR=${BUILD_ROOT}/${TARGET}
  PREFIX=${BUILD_ARCH_DIR}/${LIB_NAME}

  export CFLAGS="-O3 -isysroot ${SDK_PATH} -target ${TARGET} ${BITCODE} ${VERSION} -Wno-overriding-t-option"
  export CXXFLAGS="-O3 -isysroot ${SDK_PATH} -target ${TARGET} ${BITCODE} ${VERSION} -Wno-overriding-t-option"
  export LDFLAGS="-target ${TARGET} ${BITCODE}"
  export CC="$(xcrun --sdk ${SDK} -f clang) -isysroot ${SDK_PATH} -target ${TARGET} ${BITCODE} ${VERSION}"
  export CXX="$(xcrun --sdk ${SDK} -f clang++) -isysroot ${SDK_PATH} -target ${TARGET} ${BITCODE} ${VERSION}"

  progress_item "${LIB_NAME} ${TARGET}"
}

build_bc_crypto_base()
(
  build_init bc-crypto-base $@

  pushd ${DEPS_ROOT}/bc-crypto-base

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  popd
)

build_bc_bip39()
(
  build_init bc-bip39 $@

  pushd ${DEPS_ROOT}/bc-bip39

  export CFLAGS="${CFLAGS} -I${BUILD_ARCH_DIR}/bc-crypto-base/include"
  export LDFLAGS="${LDFLAGS} -L${BUILD_ARCH_DIR}/bc-crypto-base/lib"

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  popd
)

build_bc_shamir()
(
  build_init bc-shamir $@

  pushd ${DEPS_ROOT}/bc-shamir

  export CFLAGS="${CFLAGS} -I${BUILD_ARCH_DIR}/bc-crypto-base/include"
  export LDFLAGS="${LDFLAGS} -L${BUILD_ARCH_DIR}/bc-crypto-base/lib"

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  popd
)

build_csskr()
(
  build_init bc-sskr $@

  pushd ${DEPS_ROOT}/bc-sskr

  export CFLAGS="${CFLAGS} \
    -I${BUILD_ARCH_DIR}/bc-crypto-base/include \
    -I${BUILD_ARCH_DIR}/bc-shamir/include \
  "

  export LDFLAGS="${LDFLAGS} \
    -L${BUILD_ARCH_DIR}/bc-crypto-base/lib \
    -L${BUILD_ARCH_DIR}/bc-shamir/lib \
  "

  ./configure \
    --host=${TARGET} \
    --prefix=${PREFIX}

  make clean
  make -j${CPU_COUNT}
  make install
  make clean

  popd
)

build_c_libraries()
(
  progress_section "Building C Libraries"

  #             TARGET                      SDK              BITCODE                 VERSION
  ARM_IOS=(     arm64-apple-ios             iphoneos         -fembed-bitcode         -mios-version-min=${MIN_IOS_VERSION})

  X86_CATALYST=(x86_64-apple-ios-macabi     macosx           -fembed-bitcode         -mmacosx-version-min=${MIN_MAC_VERSION})
  ARM_CATALYST=(arm64-apple-ios-macabi      macosx           -fembed-bitcode         -mmacosx-version-min=${MIN_MAC_VERSION})

  X86_IOS_SIM=( x86_64-apple-ios-simulator  iphonesimulator  -fembed-bitcode-marker  -mios-simulator-version-min=${MIN_IOS_VERSION})
  ARM_IOS_SIM=( arm64-apple-ios-simulator   iphonesimulator  -fembed-bitcode-marker  -mios-simulator-version-min=${MIN_IOS_VERSION})

  X86_MAC=(     x86_64-apple-darwin         macosx           -fembed-bitcode         -mmacosx-version-min=${MIN_MAC_VERSION})
  ARM_MAC=(     arm64-apple-darwin          macosx           -fembed-bitcode         -mmacosx-version-min=${MIN_MAC_VERSION})

  build_bc_crypto_base ${ARM_IOS[@]}
  build_bc_crypto_base ${X86_CATALYST[@]}
  build_bc_crypto_base ${ARM_CATALYST[@]}
  build_bc_crypto_base ${X86_IOS_SIM[@]}
  build_bc_crypto_base ${ARM_IOS_SIM[@]}
  build_bc_crypto_base ${X86_MAC[@]}
  build_bc_crypto_base ${ARM_MAC[@]}

  build_bc_bip39 ${ARM_IOS[@]}
  build_bc_bip39 ${X86_CATALYST[@]}
  build_bc_bip39 ${ARM_CATALYST[@]}
  build_bc_bip39 ${X86_IOS_SIM[@]}
  build_bc_bip39 ${ARM_IOS_SIM[@]}
  build_bc_bip39 ${X86_MAC[@]}
  build_bc_bip39 ${ARM_MAC[@]}

  build_bc_shamir ${ARM_IOS[@]}
  build_bc_shamir ${X86_CATALYST[@]}
  build_bc_shamir ${ARM_CATALYST[@]}
  build_bc_shamir ${X86_IOS_SIM[@]}
  build_bc_shamir ${ARM_IOS_SIM[@]}
  build_bc_shamir ${X86_MAC[@]}
  build_bc_shamir ${ARM_MAC[@]}

  build_csskr ${ARM_IOS[@]}
  build_csskr ${X86_CATALYST[@]}
  build_csskr ${ARM_CATALYST[@]}
  build_csskr ${X86_IOS_SIM[@]}
  build_csskr ${ARM_IOS_SIM[@]}
  build_csskr ${X86_MAC[@]}
  build_csskr ${ARM_MAC[@]}
)

build_swift_framework()
(
  FRAMEWORK=$1
  LIBS=$2
  TARGET=$3
  SDK=$4
  PLATFORM_DIR=$5
  CATALYST=$6
  BITCODE=$7
  VERSION=$8
  CONFIGURATION=Debug

  TARGET_ELEMS=("${(@s/-/)TARGET}")
  ARCHS=${TARGET_ELEMS[1]}

  LIBS_NAMES=("${(@s/ /)LIBS}")
  LIBS_PATHS=()
  for e in $LIBS_NAMES; do
    LIBS_PATHS+=\"${BUILD_ROOT}/${TARGET}/${e}/lib\"
  done

  FRAMEWORK_ROOT=${PROJ_ROOT}/${FRAMEWORK}

  PROJECT=${FRAMEWORK_ROOT}/${FRAMEWORK}.xcodeproj
  SCHEME=${FRAMEWORK}
  DEST_DIR=${BUILD_ROOT}/${TARGET}
  FRAMEWORK_DIR_NAME=${FRAMEWORK}.framework
  rm -rf ${DEST_DIR}/${FRAMEWORK_DIR_NAME}

  ARGS=(\
    -project ${PROJECT} \
    -scheme ${SCHEME} \
    -configuration ${CONFIGURATION} \
    -sdk ${SDK} \
    ${VERSION} \
    LIBRARY_SEARCH_PATHS="${LIBS_PATHS}" \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=${ARCHS} \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    SUPPORTS_MACCATALYST=${CATALYST} \
    BITCODE_GENERATION_MODE=${BITCODE} \
    CODE_SIGN_IDENTITY= \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_REQUIRED=NO \
    )

  # (
  #   printf $'\n'
  #   printf " <%s> " $@
  #   printf $'\n'
  #   printf " <%s> " $LIBS_NAMES
  #   printf $'\n'
  #   printf " <%s> " $ARGS
  #   printf $'\n'
  #   printf $'\n'
  # ) >&3
  #   exit 0

  progress_item "${FRAMEWORK} ${TARGET}"

  # This has the complete swift module information
  xcodebuild clean build ${ARGS[@]}

  # This has the complete Bitcode information
  ARCHIVE_PATH=${DEST_DIR}/${FRAMEWORK}.xcarchive
  xcodebuild archive -archivePath ${ARCHIVE_PATH} ${ARGS[@]}

  BUILD_DIR=`xcodebuild ${ARGS[@]} -showBuildSettings | grep -o '\<BUILD_DIR = .*' | cut -d ' ' -f 3`

  if [[ ${PLATFORM_DIR} == NONE ]]
  then
    FRAMEWORK_SOURCE_DIR=${BUILD_DIR}/${CONFIGURATION}
  else
    FRAMEWORK_SOURCE_DIR=${BUILD_DIR}/${CONFIGURATION}-${PLATFORM_DIR}
  fi

  cp -R ${FRAMEWORK_SOURCE_DIR}/${FRAMEWORK_DIR_NAME} ${DEST_DIR}/

  xcodebuild clean ${ARGS[@]}

  # Copy the binary from the framework in the archive to the main framework so we have correct Swift module information
  # **and** complete Bitcode information.
  cp ${ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_DIR_NAME}/${FRAMEWORK} ${DEST_DIR}/${FRAMEWORK_DIR_NAME}/

  # Delete the archive, we no longer need it.
  rm -rf ${ARCHIVE_PATH}

  #echo diff -rq "${FRAMEWORK_SOURCE_DIR}/${FRAMEWORK_DIR_NAME}" "${DEST_DIR}/${FRAMEWORK_DIR_NAME}"
)

build_swift_frameworks()
(
  progress_section "Building Swift Frameworks"

  #              TARGET                      SDK              PLATFORM_DIR     CATALYST  BITCODE  VERSION
  ARM_IOS=(      arm64-apple-ios             iphoneos         iphoneos         NO        bitcode  IPHONEOS_DEPLOYMENT_TARGET=${MIN_IOS_VERSION})
  X86_CATALYST=( x86_64-apple-ios-macabi     macosx           maccatalyst      YES       bitcode  MACOSX_DEPLOYMENT_TARGET=${MIN_MAC_VERSION})
  ARM_CATALYST=( arm64-apple-ios-macabi      macosx           maccatalyst      YES       bitcode  MACOSX_DEPLOYMENT_TARGET=${MIN_MAC_VERSION})
  X86_IOS_SIM=(  x86_64-apple-ios-simulator  iphonesimulator  iphonesimulator  NO        marker   IPHONEOS_DEPLOYMENT_TARGET=${MIN_IOS_VERSION})
  ARM_IOS_SIM=(  arm64-apple-ios-simulator   iphonesimulator  iphonesimulator  NO        marker   IPHONEOS_DEPLOYMENT_TARGET=${MIN_IOS_VERSION})
  X86_MAC=(      x86_64-apple-darwin         macosx           NONE             NO        bitcode  MACOSX_DEPLOYMENT_TARGET=${MIN_MAC_VERSION})
  ARM_MAC=(      arm64-apple-darwin          macosx           NONE             NO        bitcode  MACOSX_DEPLOYMENT_TARGET=${MIN_MAC_VERSION})

  build_swift_framework CryptoBase "bc-crypto-base" ${ARM_IOS[@]}
  build_swift_framework CryptoBase "bc-crypto-base" ${X86_CATALYST[@]}
  build_swift_framework CryptoBase "bc-crypto-base" ${ARM_CATALYST[@]}
  build_swift_framework CryptoBase "bc-crypto-base" ${X86_IOS_SIM[@]}
  build_swift_framework CryptoBase "bc-crypto-base" ${ARM_IOS_SIM[@]}
  build_swift_framework CryptoBase "bc-crypto-base" ${X86_MAC[@]}
  build_swift_framework CryptoBase "bc-crypto-base" ${ARM_MAC[@]}

  build_swift_framework BIP39 "bc-crypto-base bc-bip39" ${ARM_IOS[@]}
  build_swift_framework BIP39 "bc-crypto-base bc-bip39" ${X86_CATALYST[@]}
  build_swift_framework BIP39 "bc-crypto-base bc-bip39" ${ARM_CATALYST[@]}
  build_swift_framework BIP39 "bc-crypto-base bc-bip39" ${X86_IOS_SIM[@]}
  build_swift_framework BIP39 "bc-crypto-base bc-bip39" ${ARM_IOS_SIM[@]}
  build_swift_framework BIP39 "bc-crypto-base bc-bip39" ${X86_MAC[@]}
  build_swift_framework BIP39 "bc-crypto-base bc-bip39" ${ARM_MAC[@]}

  build_swift_framework Shamir "bc-crypto-base bc-shamir" ${ARM_IOS[@]}
  build_swift_framework Shamir "bc-crypto-base bc-shamir" ${X86_CATALYST[@]}
  build_swift_framework Shamir "bc-crypto-base bc-shamir" ${ARM_CATALYST[@]}
  build_swift_framework Shamir "bc-crypto-base bc-shamir" ${X86_IOS_SIM[@]}
  build_swift_framework Shamir "bc-crypto-base bc-shamir" ${ARM_IOS_SIM[@]}
  build_swift_framework Shamir "bc-crypto-base bc-shamir" ${X86_MAC[@]}
  build_swift_framework Shamir "bc-crypto-base bc-shamir" ${ARM_MAC[@]}

  build_swift_framework SSKR "bc-crypto-base bc-shamir bc-sskr" ${ARM_IOS[@]}
  build_swift_framework SSKR "bc-crypto-base bc-shamir bc-sskr" ${X86_CATALYST[@]}
  build_swift_framework SSKR "bc-crypto-base bc-shamir bc-sskr" ${ARM_CATALYST[@]}
  build_swift_framework SSKR "bc-crypto-base bc-shamir bc-sskr" ${X86_IOS_SIM[@]}
  build_swift_framework SSKR "bc-crypto-base bc-shamir bc-sskr" ${ARM_IOS_SIM[@]}
  build_swift_framework SSKR "bc-crypto-base bc-shamir bc-sskr" ${X86_MAC[@]}
  build_swift_framework SSKR "bc-crypto-base bc-shamir bc-sskr" ${ARM_MAC[@]}
)

lipo_swift_framework_variant()
(
  FRAMEWORK=$1
  PLATFORM=$2
  FRAMEWORK_DIR_NAME=${FRAMEWORK}.framework
  PLATFORMFRAMEWORK=${PLATFORM}/${FRAMEWORK_DIR_NAME}
  FRAMEWORK1DIR=${BUILD_ROOT}/arm64-${PLATFORMFRAMEWORK}
  FRAMEWORK2DIR=${BUILD_ROOT}/x86_64-${PLATFORMFRAMEWORK}
  DESTDIR=${BUILD_ROOT}/${PLATFORMFRAMEWORK}

  progress_item "${FRAMEWORK} ${PLATFORM}"

  TRAPZERR() { }
  set +e; FRAMEWORK_LINK=`readlink ${FRAMEWORK1DIR}/${FRAMEWORK}`; set -e
  TRAPZERR() { return $(( 128 + $1 )) }
  ARCHIVE_PATH=${FRAMEWORK_LINK:-$FRAMEWORK}

  FRAMEWORK1ARCHIVE=${FRAMEWORK1DIR}/${ARCHIVE_PATH}
  FRAMEWORK2ARCHIVE=${FRAMEWORK2DIR}/${ARCHIVE_PATH}
  DESTARCHIVE=${DESTDIR}/${ARCHIVE_PATH}

  mkdir -p ${BUILD_ROOT}/${PLATFORM}
  rm -rf ${DESTDIR}
  cp -R ${FRAMEWORK1DIR} ${DESTDIR}
  rm -f ${DESTARCHIVE}
  lipo -create ${FRAMEWORK1ARCHIVE} ${FRAMEWORK2ARCHIVE} -output ${DESTARCHIVE}

  # Merge the Modules directories
  cp -R ${FRAMEWORK2DIR}/Modules/* ${DESTDIR}/Modules
)

lipo_swift_framework()
(
  FRAMEWORK=$1
  lipo_swift_framework_variant ${FRAMEWORK} apple-ios-macabi
  lipo_swift_framework_variant ${FRAMEWORK} apple-ios-simulator
  lipo_swift_framework_variant ${FRAMEWORK} apple-darwin
)

lipo_swift_frameworks()
(
  progress_section "Building fat Swift frameworks"

  lipo_swift_framework CryptoBase
  lipo_swift_framework BIP39
  lipo_swift_framework Shamir
  lipo_swift_framework SSKR
)

build_swift_xcframework()
(
  FRAMEWORK_NAME=$1

  PLATFORM_FRAMEWORK_NAME=${FRAMEWORK_NAME}.framework
  XC_FRAMEWORK_NAME=${FRAMEWORK_NAME}.xcframework
  XC_FRAMEWORK_PATH=${BUILD_ROOT}/${XC_FRAMEWORK_NAME}

  progress_item "${XC_FRAMEWORK_NAME}"

  rm -rf ${XC_FRAMEWORK_PATH}
  xcodebuild -create-xcframework \
  -framework ${BUILD_ROOT}/arm64-apple-ios/${PLATFORM_FRAMEWORK_NAME} \
  -framework ${BUILD_ROOT}/apple-darwin/${PLATFORM_FRAMEWORK_NAME} \
  -framework ${BUILD_ROOT}/apple-ios-macabi/${PLATFORM_FRAMEWORK_NAME} \
  -framework ${BUILD_ROOT}/apple-ios-simulator/${PLATFORM_FRAMEWORK_NAME} \
  -output ${XC_FRAMEWORK_PATH}

  # As of September 22, 2020, the step above is broken:
  # it creates unusable XCFrameworks; missing files like Modules/CryptoBase.swiftmodule/Project/x86_64-apple-ios-simulator.swiftsourceinfo
  # The frameworks we started with were fine. So we're going to brute-force replace the frameworks in the XCFramework with the originials.

  rm -rf ${XC_FRAMEWORK_PATH}/ios-arm64/${PLATFORM_FRAMEWORK_NAME}
  cp -R ${BUILD_ROOT}/arm64-apple-ios/${PLATFORM_FRAMEWORK_NAME} ${XC_FRAMEWORK_PATH}/ios-arm64/

  rm -rf ${XC_FRAMEWORK_PATH}/ios-arm64_x86_64-maccatalyst/${PLATFORM_FRAMEWORK_NAME}
  cp -R ${BUILD_ROOT}/apple-ios-macabi/${PLATFORM_FRAMEWORK_NAME} ${XC_FRAMEWORK_PATH}/ios-arm64_x86_64-maccatalyst/

  rm -rf ${XC_FRAMEWORK_PATH}/ios-arm64_x86_64-simulator/${PLATFORM_FRAMEWORK_NAME}
  cp -R ${BUILD_ROOT}/apple-ios-simulator/${PLATFORM_FRAMEWORK_NAME} ${XC_FRAMEWORK_PATH}/ios-arm64_x86_64-simulator/

  rm -rf ${XC_FRAMEWORK_PATH}/macos-arm64_x86_64/${PLATFORM_FRAMEWORK_NAME}
  cp -R ${BUILD_ROOT}/apple-darwin/${PLATFORM_FRAMEWORK_NAME} ${XC_FRAMEWORK_PATH}/macos-arm64_x86_64/
)

build_swift_xcframeworks()
(
  progress_section "Building Swift XCFrameworks"

  build_swift_xcframework CryptoBase
  build_swift_xcframework BIP39
  build_swift_xcframework Shamir
  build_swift_xcframework SSKR
)

build_all()
(
  CONTEXT=subshell
  get_dependencies
  build_c_libraries
  build_swift_frameworks
  lipo_swift_frameworks
  build_swift_xcframeworks
)

CONTEXT=top

TRAPZERR() {
  if [[ ${CONTEXT} == "top" ]]
  then
    progress_error "Build error."
    echo "Log tail:" >&3
    tail -n 10 ${BUILD_LOG} >&3
  fi

  return $(( 128 + $1 ))
}

TRAPINT() {
  if [[ ${CONTEXT} == "top" ]]
  then
    progress_error "Build stopped."
  fi

  return $(( 128 + $1 ))
}

(
  exec 3>/dev/tty
  build_all
  progress_success "Done!"
) >>&| ${BUILD_LOG}
