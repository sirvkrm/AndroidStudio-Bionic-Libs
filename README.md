# AndroidStudio-bionic-libs

Native libraries for Android Studio and the IntelliJ platform compiled natively for **`linux_android` / `linux_arm64_bionic`** (Termux / Android native).

This repository replaces fragile ad-hoc patching with a clean, repeatable build system supporting both **standalone individual library builds** and a unified **Build All** pipeline.

---

## Architecture & Components

| Component | Output Binary / Library | Upstream Source | Purpose in Android Studio |
| :--- | :--- | :--- | :--- |
| **`fsnotifier`** | `bin/fsnotifier`<br>`bin/fsnotifier-static` | JetBrains `intellij-community` | Inotify file system watcher. Prevents IDE freeze & file desync. |
| **`pty4j`** | `lib/pty4j/linux/aarch64/libpty.so` | JetBrains `pty4j` | Embedded terminal emulation subsystem. |
| **`jna`** | `lib/jna/linux-aarch64/libjnidispatch.so` | `java-native-access/jna` | Java Native Access C bridge. |
| **`sqlite-jdbc`**| `lib/sqlite/linux-aarch64/libsqlitejdbc.so` | `xerial/sqlite-jdbc` + SQLite 3.53+ | Native SQLite database engine used by plugins & indexes. |
| **`skiko`** | `lib/skiko/libskiko-linux-arm64.so` | JetBrains `skiko` + `google/skia` | Jetpack Compose / JetBrains UI hardware graphics engine. |

All binaries and shared objects are compiled against Android Bionic `libc.so`, `libm.so`, and `libdl.so` with `SONAME` flags set properly. Linker `RUNPATH` includes `/system/lib64`, `$ORIGIN`, and `/data/data/com.termux/files/usr/lib`.

---

## Compilation Modes

### Method 1: Single Library Compilation
Each library in `libs/` has its own standalone `build.sh` script:

```bash
# Build only fsnotifier
./libs/fsnotifier/build.sh

# Build only pty4j
./libs/pty4j/build.sh

# Build only jna
./libs/jna/build.sh

# Build only sqlite-jdbc
./libs/sqlite-jdbc/build.sh

# Build only skiko
./libs/skiko/build.sh
```

### Method 2: Build All & Package
Builds every native library and creates a ready-to-extract tarball:

```bash
./build-all.sh
```

**Output artifacts in `dist/`:**
```text
dist/
├── bin/
│   ├── fsnotifier            (24 KB, dynamic Bionic)
│   └── fsnotifier-static     (3.4 MB, static fallback)
├── lib/
│   ├── jna/
│   │   └── linux-aarch64/
│   │       └── libjnidispatch.so     (169 KB)
│   ├── pty4j/
│   │   └── linux/aarch64/
│   │       └── libpty.so             (14 KB)
│   ├── skiko/
│   │   └── libskiko-linux-arm64.so   (19 MB)
│   └── sqlite/
│       └── linux-aarch64/
│           └── libsqlitejdbc.so      (1.3 MB)
└── android-studio-bionic-libs-aarch64.tar.gz (~11 MB)
```

---

## Toolchain & Environment Support

The repository auto-detects the build environment via `env.sh`:

1. **Inside Termux (On-Device ARM64):**
   * Uses host Termux `clang`, `llvm-ar`, and `/data/data/com.termux/files/usr` sysroot.
2. **On Linux x86_64 (Cross-Compilation):**
   * Automatically uses Android NDK (default: `/opt/android-ndk/android-ndk-r26d` or `$ANDROID_NDK_ROOT`) with `aarch64-linux-android24-clang`.

---

## Automated 1-Line Installer & Patcher for Termux

Run directly inside Termux to auto-download, patch Android Studio, and configure HomuHomu SDK/NDK:

```bash
curl -sSL https://raw.githubusercontent.com/sirvkrm/AndroidStudio-Bionic-Libs/main/setup-android-studio-bionic.sh | bash
```

Or run locally after cloning:
```bash
./setup-android-studio-bionic.sh
```

---

## Manual Extraction

Extract the release tarball into your Android Studio folder:

```bash
tar -xzf android-studio-bionic-libs-aarch64.tar.gz -C /path/to/android-studio/
```
