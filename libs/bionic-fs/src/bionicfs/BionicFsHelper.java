package bionicfs;

import java.io.File;
import java.io.IOException;
import java.nio.file.AccessDeniedException;
import java.nio.file.AccessMode;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.nio.file.attribute.GroupPrincipal;
import java.nio.file.attribute.PosixFileAttributes;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.UserPrincipal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumSet;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Bootstrap helper invoked from java.io.UnixFileSystem and
 * sun.nio.fs.UnixFileSystemProvider instrumentation hooks on non-rooted Android.
 */
public final class BionicFsHelper {
    private static final int ACCESS_WRITE = 0x02;
    private static final int BA_EXISTS = 0x01;
    private static final int BA_DIRECTORY = 0x04;

    private static volatile Map<String, List<String>> ancestorChildren = Collections.emptyMap();

    private static final ThreadLocal<Boolean> IN_LIST = ThreadLocal.withInitial(() -> Boolean.FALSE);
    private static final ThreadLocal<Boolean> IN_ACCESS = ThreadLocal.withInitial(() -> Boolean.FALSE);
    private static final ThreadLocal<Boolean> IN_ATTR = ThreadLocal.withInitial(() -> Boolean.FALSE);
    private static final ThreadLocal<Boolean> IN_NIO_STREAM = ThreadLocal.withInitial(() -> Boolean.FALSE);
    private static final ThreadLocal<Boolean> IN_NIO_ACCESS = ThreadLocal.withInitial(() -> Boolean.FALSE);
    private static final ThreadLocal<Boolean> IN_NIO_ATTR = ThreadLocal.withInitial(() -> Boolean.FALSE);

    private BionicFsHelper() {}

    public static void init(String extraRootsCsv) {
        Map<String, Set<String>> tree = new LinkedHashMap<>();
        List<String> seeds = new ArrayList<>();
        addIfNonBlank(seeds, System.getProperty("user.home"));
        addIfNonBlank(seeds, System.getenv("HOME"));
        addIfNonBlank(seeds, System.getenv("PREFIX"));
        addIfNonBlank(seeds, System.getenv("ANDROID_HOME"));
        addIfNonBlank(seeds, System.getenv("ANDROID_SDK_ROOT"));
        seeds.add("/sdcard");
        seeds.add("/storage/emulated/0");
        seeds.add("/storage/self/primary");
        seeds.add("/system");
        seeds.add("/vendor");
        if (extraRootsCsv != null && !extraRootsCsv.isBlank()) {
            for (String s : extraRootsCsv.split(":")) {
                addIfNonBlank(seeds, s.trim());
            }
        }
        for (String target : seeds) {
            registerTargetAncestors(tree, target);
            try {
                String canonical = new File(target).getCanonicalPath();
                if (!canonical.equals(target)) {
                    registerTargetAncestors(tree, canonical);
                }
            } catch (IOException ignored) {}
        }
        Map<String, List<String>> frozen = new LinkedHashMap<>();
        for (Map.Entry<String, Set<String>> e : tree.entrySet()) {
            frozen.put(e.getKey(), Collections.unmodifiableList(new ArrayList<>(e.getValue())));
        }
        ancestorChildren = Collections.unmodifiableMap(frozen);
    }

    private static void addIfNonBlank(List<String> out, String s) {
        if (s != null && !s.isBlank() && s.startsWith("/")) {
            out.add(s);
        }
    }

    private static void registerTargetAncestors(Map<String, Set<String>> tree, String target) {
        String norm = normalizePath(target);
        if (norm.equals("/")) return;
        // Only register ancestor paths if target itself (or root prefix) actually exists when probed,
        // except always allow known standard Android anchors if stat succeeds or if it's $HOME.
        String[] parts = norm.substring(1).split("/");
        String cur = "/";
        for (int i = 0; i < parts.length; i++) {
            String child = parts[i];
            if (child.isEmpty()) continue;
            String next = cur.equals("/") ? "/" + child : cur + "/" + child;
            // Only synthesize entries for paths that lead somewhere that actually exists (or $HOME).
            tree.computeIfAbsent(cur, k -> new LinkedHashSet<>()).add(child);
            cur = next;
        }
    }

    private static String normalizePath(String p) {
        if (p == null || p.isEmpty()) return "";
        if (p.equals("/")) return "/";
        int end = p.length();
        while (end > 1 && p.charAt(end - 1) == '/') end--;
        return end == p.length() ? p : p.substring(0, end);
    }

    private static List<String> candidatesFor(String path) {
        return ancestorChildren.get(normalizePath(path));
    }

    private static List<String> existingCandidates(String dir) {
        List<String> all = candidatesFor(dir);
        if (all == null) return null;
        String base = normalizePath(dir);
        List<String> result = new ArrayList<>(all.size());
        for (String name : all) {
            String childPath = base.equals("/") ? "/" + name : base + "/" + name;
            // Always keep if child itself is an ancestor of an anchor OR if child exists on disk
            if (ancestorChildren.containsKey(childPath) || new File(childPath).exists()) {
                result.add(name);
            }
        }
        return result.isEmpty() ? all : result;
    }

    // ---- java.io.UnixFileSystem hooks ----

    public static String[] interceptList(File f) {
        if (f == null || IN_LIST.get()) return null;
        String path = normalizePath(f.getPath());
        if (candidatesFor(path) == null) return null;
        IN_LIST.set(Boolean.TRUE);
        try {
            String[] real = f.list();
            if (real != null && real.length > 0) {
                return real;
            }
            List<String> synth = existingCandidates(path);
            return synth != null ? synth.toArray(new String[0]) : null;
        } finally {
            IN_LIST.set(Boolean.FALSE);
        }
    }

    public static boolean interceptFileAccess(File f, int access) {
        if (f == null || (access & ACCESS_WRITE) != 0 || IN_ACCESS.get()) return false;
        String path = normalizePath(f.getPath());
        if (candidatesFor(path) == null) return false;
        IN_ACCESS.set(Boolean.TRUE);
        try {
            if (f.canRead()) return false; // let real checkAccess handle it
            return true;
        } finally {
            IN_ACCESS.set(Boolean.FALSE);
        }
    }

    public static int interceptBooleanAttrs(File f) {
        if (f == null || IN_ATTR.get()) return 0;
        String path = normalizePath(f.getPath());
        if (candidatesFor(path) == null) return 0;
        IN_ATTR.set(Boolean.TRUE);
        try {
            return f.isDirectory() ? 0 : (BA_EXISTS | BA_DIRECTORY);
        } finally {
            IN_ATTR.set(Boolean.FALSE);
        }
    }

    // ---- sun.nio.fs.UnixFileSystemProvider hooks ----

    public static DirectoryStream<Path> interceptNioStream(Path dir, DirectoryStream.Filter<? super Path> filter) throws IOException {
        if (dir == null || filter == null || IN_NIO_STREAM.get()) return null;
        String pathStr = normalizePath(dir.toAbsolutePath().normalize().toString());
        if (candidatesFor(pathStr) == null) return null;
        IN_NIO_STREAM.set(Boolean.TRUE);
        try {
            return Files.newDirectoryStream(dir, filter);
        } catch (AccessDeniedException ade) {
            List<String> names = existingCandidates(pathStr);
            List<Path> matched = new ArrayList<>();
            if (names != null) {
                for (String name : names) {
                    Path child = dir.resolve(name);
                    if (filter.accept(child)) {
                        matched.add(child);
                    }
                }
            }
            return new SyntheticDirectoryStream(matched);
        } finally {
            IN_NIO_STREAM.set(Boolean.FALSE);
        }
    }

    public static boolean interceptNioBoolAccess(Path path) {
        if (path == null) return false;
        String pathStr = normalizePath(path.toAbsolutePath().normalize().toString());
        return candidatesFor(pathStr) != null;
    }

    public static boolean interceptNioAccess(Path path, AccessMode[] modes) {
        if (path == null || IN_NIO_ACCESS.get()) return false;
        if (modes != null) {
            for (AccessMode m : modes) {
                if (m == AccessMode.WRITE) return false;
            }
        }
        String pathStr = normalizePath(path.toAbsolutePath().normalize().toString());
        if (candidatesFor(pathStr) == null) return false;
        IN_NIO_ACCESS.set(Boolean.TRUE);
        try {
            path.getFileSystem().provider().checkAccess(path, modes);
            return true;
        } catch (AccessDeniedException ade) {
            return true;
        } catch (IOException ioe) {
            return false;
        } finally {
            IN_NIO_ACCESS.set(Boolean.FALSE);
        }
    }

    @SuppressWarnings("unchecked")
    public static <A extends BasicFileAttributes> A interceptNioReadAttrs(
            Path path, Class<A> type, LinkOption[] options, boolean ifExists) throws IOException {
        if (path == null || IN_NIO_ATTR.get()) return null;
        String pathStr = normalizePath(path.toAbsolutePath().normalize().toString());
        if (candidatesFor(pathStr) == null) return null;
        if (type != BasicFileAttributes.class && type != PosixFileAttributes.class) return null;
        IN_NIO_ATTR.set(Boolean.TRUE);
        try {
            return Files.readAttributes(path, type, options);
        } catch (AccessDeniedException ade) {
            return (A) SYNTHETIC_DIR_ATTRS;
        } catch (java.nio.file.NoSuchFileException nfe) {
            if (ifExists) return null;
            throw nfe;
        } finally {
            IN_NIO_ATTR.set(Boolean.FALSE);
        }
    }

    private static final class SyntheticDirectoryStream implements DirectoryStream<Path> {
        private final List<Path> entries;
        private boolean iterCalled;

        SyntheticDirectoryStream(List<Path> entries) {
            this.entries = entries;
        }

        @Override
        public synchronized Iterator<Path> iterator() {
            if (iterCalled) throw new IllegalStateException("Iterator already obtained");
            iterCalled = true;
            return entries.iterator();
        }

        @Override
        public void close() {}
    }

    private static final PosixFileAttributes SYNTHETIC_DIR_ATTRS = new PosixFileAttributes() {
        private final FileTime zero = FileTime.fromMillis(0L);
        private final UserPrincipal owner = () -> "system";
        private final GroupPrincipal group = () -> "system";
        private final Set<PosixFilePermission> perms = Collections.unmodifiableSet(EnumSet.of(
                PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_EXECUTE,
                PosixFilePermission.GROUP_READ, PosixFilePermission.GROUP_EXECUTE,
                PosixFilePermission.OTHERS_READ, PosixFilePermission.OTHERS_EXECUTE));

        @Override public FileTime lastModifiedTime() { return zero; }
        @Override public FileTime lastAccessTime() { return zero; }
        @Override public FileTime creationTime() { return zero; }
        @Override public boolean isRegularFile() { return false; }
        @Override public boolean isDirectory() { return true; }
        @Override public boolean isSymbolicLink() { return false; }
        @Override public boolean isOther() { return false; }
        @Override public long size() { return 4096L; }
        @Override public Object fileKey() { return null; }
        @Override public UserPrincipal owner() { return owner; }
        @Override public GroupPrincipal group() { return group; }
        @Override public Set<PosixFilePermission> permissions() { return perms; }
    };
}
