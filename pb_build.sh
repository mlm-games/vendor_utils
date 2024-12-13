#!/bin/bash
# Deleted file notices do not cover here

# Initialize variables
BUILD_START=$(date +"%s")
# Color codes
blue='\033[0;34m'
cyan='\033[0;36m'
green='\e[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'
purple='\e[0;35m'
white='\e[0;37m'

# Build configuration
DATE=$(date +%Y%m%d-%H%M)
VERSION=${VERSION:-3.0.0}
PB_VENDOR=vendor/utils
PB_WORK=$OUT
PB_WORK_DIR=$OUT/zip
RECOVERY_IMG=$OUT/recovery.img
RECOVERY_RAM=$OUT/ramdisk-recovery.cpio
AB_OTA=${AB_OTA_UPDATER:-false}
unset AB_OTA_UPDATER
export PB_DEVICE=$(cut -d'_' -f2-3 <<<$TARGET_PRODUCT)

# Function to log messages
log_msg() {
    echo -e "${2}${1}${nocol}"
}

# Function to check build type
check_build_type() {
    if [ "$PB_OFFICIAL_CH" != "true" ]; then
        PBRP_BUILD_TYPE=UNOFFICIAL
    else
        if python3 $PB_VENDOR/pb_devices.py verify all $PB_DEVICE; then
            PBRP_BUILD_TYPE=OFFICIAL
        else
            log_msg "Error: Device is not OFFICIAL" "$red"
            exit 1
        fi
    fi
}

# Function to set zip name
set_zip_name() {
    if [ "$PB_GO" != "true" ]; then
        ZIP_NAME=PBRP-$PB_DEVICE-$VERSION-$DATE-$PBRP_BUILD_TYPE
    else
        log_msg "PitchBlack Go Variant has been deprecated and removed. Remove PB_GO flag to build normally." "$red"
        exit 1
    fi
}

# Function to prepare work directory
prepare_work_dir() {
    log_msg "**** Making Zip ****" "$red"
    if [ -d "$PB_WORK_DIR" ]; then
        rm -rf "$PB_WORK_DIR"
        rm -rf "$PB_WORK"/*.zip
    fi
    mkdir -p "$PB_WORK_DIR"
}

# Function to copy required files
copy_files() {
    log_msg "**** Copying Tools ****" "$blue"
    cp -R "$PB_VENDOR/PBRP" "$PB_WORK_DIR"

    log_msg "**** Copying Updater Scripts ****" "$green"
    mkdir -p "$PB_WORK_DIR/META-INF/com/google/android"
    cp -R "$PB_VENDOR/updater/update-script" "$PB_WORK_DIR/META-INF/com/google/android/"
    cp -R "$PB_VENDOR/updater/update-binary" "$PB_WORK_DIR/META-INF/com/google/android/"
    cp -R "$PB_VENDOR/updater/awk" "$PB_WORK_DIR/META-INF/"
    
    [ -f "$PB_WORK/recovery/root/sbin/keycheck" ] && \
        cp "$PB_WORK/recovery/root/sbin/keycheck" "$PB_WORK_DIR/META-INF/"

    if [ "$AB_OTA" = "true" ]; then
        sed -i "s|AB_DEVICE=false|AB_DEVICE=true|g" "$PB_WORK_DIR/META-INF/com/google/android/update-binary"
    fi

    log_msg "**** Copying Recovery Image ****" "$cyan"
    mkdir -p "$PB_WORK_DIR/TWRP"
    cp "$PB_VENDOR/updater/magiskboot" "$PB_WORK_DIR"
    cp "$RECOVERY_IMG" "$PB_WORK_DIR/TWRP/"
}

# Function to create zip file
create_zip() {
    log_msg "**** Compressing Files into ZIP ****" "$green"
    cd "$PB_WORK_DIR" || exit 1
    zip -r "${ZIP_NAME}.zip" *
    mv "${ZIP_NAME}.zip" "../${ZIP_NAME}.zip"
}

# Function to display build results
show_build_results() {
    local recovery_size
    local zip_size
    
    recovery_size=$(du -h "${OUT}/recovery.img" | awk '{print $1}')
    zip_size=$(du -h "${PB_WORK}/${ZIP_NAME}.zip" | awk '{print $1}')

    echo -e "${BLINKBLUE}"
    cat "${OUT}/../../../../vendor/utils/.pb.1"
    echo -e "${nocol}"
    echo
    
    log_msg "****************************************************************************************" "$cyan"
    log_msg "* BUILD SUCCESSFUL" "$cyan"
    log_msg "* RECOVERY LOCATION: ${OUT}/recovery.img" "$cyan"
    log_msg "* RECOVERY SIZE: ${recovery_size}" "$purple"
    log_msg "* ZIP LOCATION: ${PB_WORK}/${ZIP_NAME}.zip" "$cyan"
    log_msg "* ZIP SIZE: ${zip_size}" "$purple"
    log_msg "****************************************************************************************" "$cyan"
}

# Main execution
main() {
    # Check if required variables are set
    if [ -z "$OUT" ] || [ -z "$TARGET_PRODUCT" ]; then
        log_msg "Error: Required environment variables are not set" "$red"
        exit 1
    }

    # Run build steps
    check_build_type
    set_zip_name
    prepare_work_dir
    copy_files
    create_zip
    
    BUILD_END=$(date +"%s")
    BUILD_DURATION=$((BUILD_END - BUILD_START))
    
    show_build_results
    
    log_msg "Build completed in $((BUILD_DURATION/60)) minutes and $((BUILD_DURATION%60)) seconds" "$green"
}

# Execute main function
main "$@"
