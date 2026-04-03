# Android FFI Build Script for Go
$NDK_PATH = "C:\AndroidSDK\ndk\25.1.8937393"
$TOOLCHAIN = "$NDK_PATH\toolchains\llvm\prebuilt\windows-x86_64\bin"
$OUTPUT_DIR = "..\android\src\main\jniLibs"
$API = "21"

function Build-Arch($goarch, $jni_dir, $cc_name) {
    Write-Host "Building for $goarch ($jni_dir)..." -ForegroundColor Cyan
    
    $env:GOOS = "android"
    $env:GOARCH = $goarch
    $env:CGO_ENABLED = "1"
    $env:CC = "$TOOLCHAIN\$cc_name$API-clang.cmd"

    $target_dir = "$OUTPUT_DIR\$jni_dir"
    if (!(Test-Path $target_dir)) {
        New-Item -ItemType Directory -Path $target_dir -Force | Out-Null
    }

    # Build the shared library
    # We use -buildmode=c-shared to create the .so file
    go build -buildmode=c-shared -ldflags="-s -w" -o "$target_dir\libmygologic.so" .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully built $jni_dir/libmygologic.so" -ForegroundColor Green
        # Remove generated .h file, as Dart FFI does not need it
        if (Test-Path "$target_dir\libmygologic.h") { Remove-Item "$target_dir\libmygologic.h" }
    } else {
        Write-Host "Failed to build $jni_dir" -ForegroundColor Red
    }
}

# Ensure we are in the 'go' directory
if (!(Test-Path "go.mod")) {
    Write-Error "Please run this script from the Go source directory (containing go.mod)"
    exit 1
}

# Build for all main Android architectures
Build-Arch "arm64" "arm64-v8a" "aarch64-linux-android"
Build-Arch "arm"   "armeabi-v7a" "armv7a-linux-androideabi"
Build-Arch "amd64" "x86_64"      "x86_64-linux-android"
Build-Arch "386"   "x86"         "i686-linux-android"

Write-Host "All builds completed!" -ForegroundColor Magenta
