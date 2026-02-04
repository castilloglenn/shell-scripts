reinstall_flutter_deps() {
    flutter pub cache clean
    flutter clean
    cd ios
    pod deintegrate
    cd ..
    flutter pub get
    cd ios
    pod install
    cd ..
    flutter pub run build_runner build --delete-conflicting-outputs
}

adb_connect() {
    if [ $# -ne 3 ]; then
        echo "Usage: adb_connect <third_octet> <fourth_octet> <port>"
        return 1
    fi
    addr="192.168.$1.$2:$3"
    adb connect "$addr"
}
