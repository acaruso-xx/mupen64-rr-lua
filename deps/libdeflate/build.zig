const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce position independent code");

    const compression_support = b.option(bool, "compression-support", "Support compression") orelse true;
    const decompression_support = b.option(bool, "decompression-support", "Support decompression") orelse true;
    const zlib_support = b.option(bool, "zlib-support", "Support the zlib format") orelse true;
    const gzip_support = b.option(bool, "gzip-support", "Support the gzip format") orelse true;

    // const freestanding = b.option(bool, "freestanding", "Build a freestanding library") orelse false;
    // const build_gzip = b.option(bool, "build-gzip", "Build the libdeflate-gzip program") orelse true;

    const upstream = b.dependency("libdeflate", .{});

    const lib = b.addLibrary(.{
        .name = "deflate",
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libc = true,
        }),
    });

    lib.root_module.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = &.{
            "lib/arm/cpu_features.c",
            "lib/utils.c",
            "lib/x86/cpu_features.c",
        },
    });

    if (target.result.cpu.arch.isX86()) {
        if (!std.Target.x86.featureSetHas(target.result.cpu.features, .avx512vnni)) {
            lib.root_module.addCMacro("LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_AVX512VNNI", "");
        }

        if (!std.Target.x86.featureSetHas(target.result.cpu.features, .vpclmulqdq)) {
            lib.root_module.addCMacro("LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_VPCLMULQDQ", "");
        }
    }

    if (compression_support) lib.root_module.addCSourceFile(.{
        .file = upstream.path("lib/deflate_compress.c"),
    });

    if (decompression_support) {
        lib.root_module.addCSourceFile(.{
            .file = upstream.path("lib/deflate_decompress.c"),
        });
    }

    if (zlib_support) {
        lib.root_module.addCSourceFile(.{
            .file = upstream.path("lib/zlib_compress.c"),
        });

        if (compression_support) lib.root_module.addCSourceFile(.{
            .file = upstream.path("lib/zlib_compress.c"),
        });

        if (decompression_support) lib.root_module.addCSourceFile(.{
            .file = upstream.path("lib/zlib_decompress.c"),
        });
    }

    if (gzip_support) {
        lib.root_module.addCSourceFile(.{
            .file = upstream.path("lib/crc32.c"),
        });

        if (compression_support) lib.root_module.addCSourceFile(.{
            .file = upstream.path("lib/gzip_compress.c"),
        });

        if (decompression_support) lib.root_module.addCSourceFile(.{
            .file = upstream.path("lib/gzip_decompress.c"),
        });
    }

    lib.installHeader(upstream.path("libdeflate.h"), "libdeflate.h");
    b.installArtifact(lib);
}
