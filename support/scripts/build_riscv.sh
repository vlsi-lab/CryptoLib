#!/bin/bash -i
#
# Convenience script for CryptoLib RISC-V cross-compilation
# Will build in current directory
#
#  ./build_riscv.sh
#

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/env.sh

RISCV_TOOLCHAIN=${RISCV_TOOLCHAIN:?RISCV_TOOLCHAIN must be set (e.g. export RISCV_TOOLCHAIN=/path/to/toolchain/bin)}
RISCV_TRIPLET=${RISCV_TRIPLET:?RISCV_TRIPLET must be set (e.g. export RISCV_TRIPLET=riscv-unknown-elf)}
RISCV_BUILD_DIR=${RISCV_BUILD_DIR:-$BASE_DIR/build/riscv}
SA_IMPL=${SA_IMPL:-internal}
MC_IMPL=${MC_IMPL:-internal}
KEY_IMPL=${KEY_IMPL:-internal}
CRYPTO_IMPL=${CRYPTO_IMPL:-custom}
DEBUG=${DEBUG:-0}
SKIP_INIT=${SKIP_INIT:-0}

RISCV_CC=${RISCV_CC:-$RISCV_TOOLCHAIN/${RISCV_TRIPLET}-gcc}
RISCV_AR=${RISCV_AR:-$RISCV_TOOLCHAIN/${RISCV_TRIPLET}-ar}
RISCV_RANLIB=${RISCV_RANLIB:-$RISCV_TOOLCHAIN/${RISCV_TRIPLET}-ranlib}
RISCV_OBJCOPY=${RISCV_OBJCOPY:-$RISCV_TOOLCHAIN/${RISCV_TRIPLET}-objcopy}
RISCV_OBJDUMP=${RISCV_OBJDUMP:-$RISCV_TOOLCHAIN/${RISCV_TRIPLET}-objdump}

for REQUIRED_TOOL in "$RISCV_CC" "$RISCV_AR" "$RISCV_RANLIB" "$RISCV_OBJCOPY" "$RISCV_OBJDUMP"; do
    if [[ ! -x "$REQUIRED_TOOL" ]]; then
        echo "Missing required RISC-V tool: $REQUIRED_TOOL"
        exit 1
    fi
done

CMAKE_MODULE_FLAGS=()

case "${CRYPTO_IMPL,,}" in
    custom)
        CRYPTO_CUSTOM_PATH_EFFECTIVE=${CRYPTO_CUSTOM_PATH:-$BASE_DIR/src/crypto/custom_stub}
        CMAKE_MODULE_FLAGS+=("-DCRYPTO_CUSTOM=1")
        CMAKE_MODULE_FLAGS+=("-DCRYPTO_CUSTOM_PATH=${CRYPTO_CUSTOM_PATH_EFFECTIVE}")
        ;;
    libgcrypt)
        CMAKE_MODULE_FLAGS+=("-DCRYPTO_LIBGCRYPT=1")
        ;;
    kmc)
        CMAKE_MODULE_FLAGS+=("-DCRYPTO_KMC=1")
        ;;
    wolfssl)
        CMAKE_MODULE_FLAGS+=("-DCRYPTO_WOLFSSL=1")
        ;;
    *)
        echo "Invalid CRYPTO_IMPL '${CRYPTO_IMPL}'. Valid values: custom, libgcrypt, kmc, wolfssl"
        exit 1
        ;;
esac

case "${SA_IMPL,,}" in
    internal)
        CMAKE_MODULE_FLAGS+=("-DSA_INTERNAL=1")
        ;;
    custom)
        CMAKE_MODULE_FLAGS+=("-DSA_CUSTOM=1")
        if [[ -n "${SA_CUSTOM_PATH:-}" ]]; then
            CMAKE_MODULE_FLAGS+=("-DSA_CUSTOM_PATH=${SA_CUSTOM_PATH}")
        fi
        ;;
    mariadb)
        CMAKE_MODULE_FLAGS+=("-DSA_MARIADB=1")
        ;;
    *)
        echo "Invalid SA_IMPL '${SA_IMPL}'. Valid values: internal, custom, mariadb"
        exit 1
        ;;
esac

case "${MC_IMPL,,}" in
    internal)
        CMAKE_MODULE_FLAGS+=("-DMC_INTERNAL=1")
        ;;
    custom)
        CMAKE_MODULE_FLAGS+=("-DMC_CUSTOM=1")
        if [[ -n "${MC_CUSTOM_PATH:-}" ]]; then
            CMAKE_MODULE_FLAGS+=("-DMC_CUSTOM_PATH=${MC_CUSTOM_PATH}")
        fi
        ;;
    disabled)
        CMAKE_MODULE_FLAGS+=("-DMC_DISABLED=1")
        ;;
    *)
        echo "Invalid MC_IMPL '${MC_IMPL}'. Valid values: internal, custom, disabled"
        exit 1
        ;;
esac

case "${KEY_IMPL,,}" in
    internal)
        CMAKE_MODULE_FLAGS+=("-DKEY_INTERNAL=1")
        ;;
    custom)
        CMAKE_MODULE_FLAGS+=("-DKEY_CUSTOM=1")
        if [[ -n "${KEY_CUSTOM_PATH:-}" ]]; then
            CMAKE_MODULE_FLAGS+=("-DKEY_CUSTOM_PATH=${KEY_CUSTOM_PATH}")
        fi
        ;;
    kmc)
        CMAKE_MODULE_FLAGS+=("-DKEY_KMC=1")
        ;;
    *)
        echo "Invalid KEY_IMPL '${KEY_IMPL}'. Valid values: internal, custom, kmc"
        exit 1
        ;;
esac

if [[ "$DEBUG" == "1" ]]; then
    CMAKE_MODULE_FLAGS+=("-DDEBUG=1")
fi

if [[ "$SKIP_INIT" == "1" ]]; then
    CMAKE_MODULE_FLAGS+=("-DSKIP_SA_INIT=1")
    CMAKE_MODULE_FLAGS+=("-DSKIP_KEY_INIT=1")
fi

if [[ -z "$RISCV_BUILD_DIR" || "$RISCV_BUILD_DIR" == "/" ]]; then
    echo "RISCV_BUILD_DIR must not be empty or root"
    exit 1
fi

rm -rf "$RISCV_BUILD_DIR"
mkdir -p "$RISCV_BUILD_DIR" > /dev/null 2>&1

cmake -S "$BASE_DIR" -B "$RISCV_BUILD_DIR" \
    -DCMAKE_SYSTEM_NAME=Generic \
    -DCMAKE_SYSTEM_PROCESSOR=riscv \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_C_COMPILER="$RISCV_CC" \
    -DCMAKE_AR="$RISCV_AR" \
    -DCMAKE_RANLIB="$RISCV_RANLIB" \
    -DCMAKE_OBJCOPY="$RISCV_OBJCOPY" \
    -DCMAKE_OBJDUMP="$RISCV_OBJDUMP" \
    "${CMAKE_MODULE_FLAGS[@]}" && cmake --build "$RISCV_BUILD_DIR"
