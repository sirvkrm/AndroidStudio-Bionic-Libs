<div align="center">

# AndroidStudio-Bionic-Libs

**Native ARM64 Android Bionic dependencies enabling desktop Android Studio (`2026.2.1.8+`) to run directly in Termux without PRoot, chroot, or `glibc-runner`**

[![Platform](https://img.shields.io/badge/Platform-Android%20ARM64%20(Termux)-3DDC84?style=flat-square&logo=android&logoColor=white)](https://termux.dev)
[![Architecture](https://img.shields.io/badge/Arch-aarch64%20%7C%20Bionic-2563EB?style=flat-square)](env.sh)
[![Release](https://img.shields.io/github/v/release/sirvkrm/AndroidStudio-Bionic-Libs?style=flat-square&label=Latest%20Release&color=0EA5E9)](https://github.com/sirvkrm/AndroidStudio-Bionic-Libs/releases)
[![Skiko](https://img.shields.io/badge/Skiko-v0.144.5%20(X11%20%2B%20GLX%20%2F%20Software)-7C3AED?style=flat-square)](https://github.com/sirvkrm/skiko-android)
[![License](https://img.shields.io/badge/License-Apache%202.0-64748B?style=flat-square)](https://www.apache.org/licenses/LICENSE-2.0)

</div>

---

## Components (`v2.0.0`)

Every native shared object and binary below is compiled against Android Bionic (`libc.so`, `libm.so`, `libdl.so`) with explicit `SONAME` and Bionic-compatible `RUNPATH` entries (`/system/lib64`, Termux `$PREFIX/lib`, `$ORIGIN`):

| Component | Output Artifact | Upstream Source | Role in Android Studio |
| :--- | :--- | :--- | :--- |
| **`fsnotifier`** | `bin/fsnotifier`<br>`bin/fsnotifier-static` | JetBrains `intellij-community` | Native inotify file-system watcher (prevents IDE file-sync freezes) |
| **`pty4j`** | `lib/pty4j/linux/aarch64/libpty.so` | JetBrains `pty4j` | Embedded IDE terminal subsystem |
| **`libutil`** | `lib/pty4j/linux/aarch64/libutil.so` | Custom Bionic shim | Provides POSIX `login_tty` symbol expected by `pty4j` |
| **`jna`** | `lib/jna/{linux-aarch64,aarch64}/libjnidispatch.so` | `java-native-access/jna` (`7.0.4`) | Java Native Access C bridge aligned with Rabbit 1 `JNA 7.0.4` |
| **`sqlite-jdbc`** | `lib/sqlite/linux-aarch64/libsqlitejdbc.so` | `xerial/sqlite-jdbc` + SQLite | Native SQLite engine for IDE caches & database tools |
| **`skiko`** | `lib/skiko/libskiko-linux-arm64.so` | [`sirvkrm/skiko-android`](https://github.com/sirvkrm/skiko-android) (`bionic-v0.144.5`) | Skiko/Skia Compose UI engine (linked cleanly without `libandroid.so` so host Bionic `layoutlib` loads without conflict) |
| **`bionic-fs`** | `lib/studio-bionic-fs.jar` | Custom JDK 25 `ClassFile` agent | Makes unreadable non-rooted Android parent paths (`/`, `/data`, `/data/data`, `/storage/emulated`) browseable down to `$HOME` and `/sdcard` in Studio's file chooser |

---

## Automated 1-Command Installer (Recommended)

Use the full interactive installer in [**sirvkrm/AndroidStudio-For-Android**](https://github.com/sirvkrm/AndroidStudio-For-Android), which automatically installs **Android Studio Rabbit 1 (`2026.2.1.8`)**, OpenJDK 25, these `v2.0.0` Bionic libraries, Termux `aapt2`, ARM64 SDK/NDK, and the matching AOSP Bionic **Layoutlib** runtime from [**sirvkrm/libandroidruntime-host-bionic**](https://github.com/sirvkrm/libandroidruntime-host-bionic):

```bash
curl -fsSL https://raw.githubusercontent.com/sirvkrm/AndroidStudio-For-Android/main/install.sh | bash
```

---

## Building from Source

`env.sh` automatically detects either native Termux on-device compilation (`clang` / `$PREFIX`) or Linux `x86_64` NDK cross-compilation (`$ANDROID_NDK_ROOT`).

### Build Individual Targets

```bash
./libs/fsnotifier/build.sh
./libs/pty4j/build.sh
./libs/libutil/build.sh
./libs/jna/build.sh
./libs/sqlite-jdbc/build.sh
./libs/skiko/build.sh
./libs/bionic-fs/build.sh   # Requires JDK 25+ javac
```

### Build All & Package Release Archive

```bash
./build-all.sh
```

Output tarball is written to `dist/android-studio-bionic-libs-2026.2.1-aarch64.tar.gz`.

---

## Manual Extraction (Advanced)

If updating an already-extracted Android Studio Rabbit 1 directory manually:

```bash
tar -xzf android-studio-bionic-libs-2026.2.1-aarch64.tar.gz -C ~/android-studio/
cp -f ~/android-studio/lib/skiko/libskiko-linux-arm64.so ~/android-studio/jbr/lib/
cp -f ~/android-studio/lib/pty4j/linux/aarch64/libutil.so "$PREFIX/lib/"
```

Pass `-javaagent:$HOME/android-studio/lib/studio-bionic-fs.jar` in your IDE profile's `studio64.vmoptions` (keep it out of global `_JAVA_OPTIONS` so Gradle daemons remain unaffected).
