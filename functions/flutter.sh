cs_reinstallflutterdeps() {
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