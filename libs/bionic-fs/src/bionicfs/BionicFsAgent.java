package bionicfs;

import java.io.File;
import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassTransform;
import java.lang.classfile.CodeBuilder;
import java.lang.classfile.CodeElement;
import java.lang.classfile.CodeTransform;
import java.lang.classfile.Label;
import java.lang.classfile.MethodModel;
import java.lang.classfile.MethodTransform;
import java.lang.constant.ClassDesc;
import java.lang.constant.ConstantDescs;
import java.lang.constant.MethodTypeDesc;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;
import java.util.Map;
import java.util.Set;
import java.util.function.BiConsumer;
import java.util.jar.JarFile;

/**
 * JDK 25 premain agent that instruments UnixFileSystem and UnixFileSystemProvider
 * so unreadable Android intermediate directories (/, /data, /data/data, /storage/emulated)
 * remain browseable down to $HOME and /sdcard inside Android Studio's file chooser.
 */
public final class BionicFsAgent {
    private static final ClassDesc CD_HELPER = ClassDesc.of("bionicfs.BionicFsHelper");
    private static final ClassDesc CD_FILE = ClassDesc.of("java.io.File");
    private static final ClassDesc CD_STRING_ARR = ClassDesc.ofDescriptor("[Ljava/lang/String;");
    private static final ClassDesc CD_PATH = ClassDesc.of("java.nio.file.Path");
    private static final ClassDesc CD_DIR_STREAM = ClassDesc.of("java.nio.file.DirectoryStream");
    private static final ClassDesc CD_FILTER = ClassDesc.of("java.nio.file.DirectoryStream$Filter");
    private static final ClassDesc CD_ACCESS_MODE_ARR = ClassDesc.ofDescriptor("[Ljava/nio/file/AccessMode;");
    private static final ClassDesc CD_CLASS = ClassDesc.of("java.lang.Class");
    private static final ClassDesc CD_LINK_OPT_ARR = ClassDesc.ofDescriptor("[Ljava/nio/file/LinkOption;");
    private static final ClassDesc CD_BASIC_ATTRS = ClassDesc.of("java.nio.file.attribute.BasicFileAttributes");

    private BionicFsAgent() {}

    public static void premain(String agentArgs, Instrumentation inst) {
        try {
            String envHome = System.getenv("HOME");
            String propHome = System.getProperty("user.home");
            if (envHome != null && envHome.startsWith("/")
                    && (propHome == null || propHome.equals("/") || propHome.equals("?"))) {
                System.setProperty("user.home", envHome);
            }

            Class<?> helperCls = Class.forName("bionicfs.BionicFsHelper", true, BionicFsAgent.class.getClassLoader());
            helperCls.getMethod("init", String.class).invoke(null, agentArgs != null ? agentArgs : "");

            Module javaBase = Object.class.getModule();
            Module bootUnnamed = helperCls.getModule();
            if (!javaBase.canRead(bootUnnamed)) {
                inst.redefineModule(javaBase, Set.of(bootUnnamed), Map.of(), Map.of(), Set.of(), Map.of());
            }

            inst.addTransformer(new Transformer(), true);
            retransformIfLoaded(inst, "java.io.UnixFileSystem");
            retransformIfLoaded(inst, "sun.nio.fs.UnixFileSystemProvider");
        } catch (Throwable t) {
            System.err.println("[bionic-fs-agent] init warning: " + t);
            t.printStackTrace(System.err);
        }
    }

    private static void retransformIfLoaded(Instrumentation inst, String name) {
        for (Class<?> c : inst.getAllLoadedClasses()) {
            if (c.getName().equals(name) && inst.isModifiableClass(c)) {
                try {
                    inst.retransformClasses(c);
                } catch (Throwable t) {
                    System.err.println("[bionic-fs-agent] retransform failed for " + name + ": " + t);
                }
            }
        }
    }

    private static final class Transformer implements ClassFileTransformer {
        @Override
        public byte[] transform(
                Module module, ClassLoader loader, String className,
                Class<?> classBeingRedefined, ProtectionDomain pd, byte[] bytes) {
            if ("java/io/UnixFileSystem".equals(className)) {
                return transformUnixFileSystem(bytes);
            }
            if ("sun/nio/fs/UnixFileSystemProvider".equals(className)) {
                return transformUnixFileSystemProvider(bytes);
            }
            return null;
        }
    }

    private static byte[] transformUnixFileSystem(byte[] bytes) {
        ClassFile cf = ClassFile.of();
        return cf.transformClass(cf.parse(bytes), ClassTransform.ofStateful(() -> (cb, ce) -> {
            if (ce instanceof MethodModel mm) {
                String name = mm.methodName().stringValue();
                String desc = mm.methodType().stringValue();
                if ("list".equals(name) && "(Ljava/io/File;)[Ljava/lang/String;".equals(desc)) {
                    cb.transformMethod(mm, prependCode((b, fallback) -> {
                        b.aload(1);
                        b.invokestatic(CD_HELPER, "interceptList", MethodTypeDesc.of(CD_STRING_ARR, CD_FILE));
                        b.dup();
                        b.ifnull(fallback);
                        b.areturn();
                        b.labelBinding(fallback);
                        b.pop();
                    }));
                    return;
                }
                if ("checkAccess".equals(name) && "(Ljava/io/File;I)Z".equals(desc)) {
                    cb.transformMethod(mm, prependCode((b, orig) -> {
                        b.aload(1);
                        b.iload(2);
                        b.invokestatic(CD_HELPER, "interceptFileAccess",
                                MethodTypeDesc.of(ConstantDescs.CD_boolean, CD_FILE, ConstantDescs.CD_int));
                        b.ifeq(orig);
                        b.iconst_1();
                        b.ireturn();
                        b.labelBinding(orig);
                    }));
                    return;
                }
                if ("getBooleanAttributes".equals(name) && "(Ljava/io/File;)I".equals(desc)) {
                    cb.transformMethod(mm, prependCode((b, fallback) -> {
                        b.aload(1);
                        b.invokestatic(CD_HELPER, "interceptBooleanAttrs",
                                MethodTypeDesc.of(ConstantDescs.CD_int, CD_FILE));
                        b.dup();
                        b.ifeq(fallback);
                        b.ireturn();
                        b.labelBinding(fallback);
                        b.pop();
                    }));
                    return;
                }
            }
            cb.accept(ce);
        }));
    }

    private static byte[] transformUnixFileSystemProvider(byte[] bytes) {
        ClassFile cf = ClassFile.of();
        return cf.transformClass(cf.parse(bytes), ClassTransform.ofStateful(() -> (cb, ce) -> {
            if (ce instanceof MethodModel mm) {
                String name = mm.methodName().stringValue();
                String desc = mm.methodType().stringValue();
                if ("newDirectoryStream".equals(name)
                        && "(Ljava/nio/file/Path;Ljava/nio/file/DirectoryStream$Filter;)Ljava/nio/file/DirectoryStream;".equals(desc)) {
                    cb.transformMethod(mm, prependCode((b, fallback) -> {
                        b.aload(1);
                        b.aload(2);
                        b.invokestatic(CD_HELPER, "interceptNioStream",
                                MethodTypeDesc.of(CD_DIR_STREAM, CD_PATH, CD_FILTER));
                        b.dup();
                        b.ifnull(fallback);
                        b.areturn();
                        b.labelBinding(fallback);
                        b.pop();
                    }));
                    return;
                }
                if ("checkAccess".equals(name) && "(Ljava/nio/file/Path;[Ljava/nio/file/AccessMode;)V".equals(desc)) {
                    cb.transformMethod(mm, prependCode((b, orig) -> {
                        b.aload(1);
                        b.aload(2);
                        b.invokestatic(CD_HELPER, "interceptNioAccess",
                                MethodTypeDesc.of(ConstantDescs.CD_boolean, CD_PATH, CD_ACCESS_MODE_ARR));
                        b.ifeq(orig);
                        b.return_();
                        b.labelBinding(orig);
                    }));
                    return;
                }
                if (("isReadable".equals(name) || "isExecutable".equals(name))
                        && "(Ljava/nio/file/Path;)Z".equals(desc)) {
                    cb.transformMethod(mm, prependCode((b, orig) -> {
                        b.aload(1);
                        b.invokestatic(CD_HELPER, "interceptNioBoolAccess",
                                MethodTypeDesc.of(ConstantDescs.CD_boolean, CD_PATH));
                        b.ifeq(orig);
                        b.iconst_1();
                        b.ireturn();
                        b.labelBinding(orig);
                    }));
                    return;
                }
                if ("exists".equals(name) && "(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Z".equals(desc)) {
                    cb.transformMethod(mm, prependCode((b, orig) -> {
                        b.aload(1);
                        b.invokestatic(CD_HELPER, "interceptNioBoolAccess",
                                MethodTypeDesc.of(ConstantDescs.CD_boolean, CD_PATH));
                        b.ifeq(orig);
                        b.iconst_1();
                        b.ireturn();
                        b.labelBinding(orig);
                    }));
                    return;
                }
                if (("readAttributes".equals(name) || "readAttributesIfExists".equals(name))
                        && "(Ljava/nio/file/Path;Ljava/lang/Class;[Ljava/nio/file/LinkOption;)Ljava/nio/file/attribute/BasicFileAttributes;".equals(desc)) {
                    boolean ifExists = "readAttributesIfExists".equals(name);
                    cb.transformMethod(mm, prependCode((b, fallback) -> {
                        b.aload(1);
                        b.aload(2);
                        b.aload(3);
                        if (ifExists) b.iconst_1(); else b.iconst_0();
                        b.invokestatic(CD_HELPER, "interceptNioReadAttrs",
                                MethodTypeDesc.of(CD_BASIC_ATTRS, CD_PATH, CD_CLASS, CD_LINK_OPT_ARR, ConstantDescs.CD_boolean));
                        b.dup();
                        b.ifnull(fallback);
                        b.areturn();
                        b.labelBinding(fallback);
                        b.pop();
                    }));
                    return;
                }
            }
            cb.accept(ce);
        }));
    }

    private static MethodTransform prependCode(BiConsumer<CodeBuilder, Label> injector) {
        return MethodTransform.transformingCode(new CodeTransform() {
            @Override
            public void atStart(CodeBuilder cb) {
                injector.accept(cb, cb.newLabel());
            }

            @Override
            public void accept(CodeBuilder cb, CodeElement el) {
                cb.accept(el);
            }
        });
    }
}
