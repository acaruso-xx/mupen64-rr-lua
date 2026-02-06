const std = @import("std");

const default_target: std.Target.Query = .{
    .os_tag = .windows,
    .cpu_arch = .x86,
};

const flags = &.{
    "-std=c++23",
    "-fasm-blocks",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = default_target });
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce position independent code");

    const dynarec = b.option(bool, "dynarec", "Enable dynamic recompiler") orelse false;
    const enable_win32 = b.option(bool, "win32", "Enable Win32 view and plugins") orelse false;

    const aladdin_md5_dep = b.dependency("aladdin-md5", .{
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .pic = pic,
    });

    const libdeflate_dep = b.dependency("libdeflate", .{
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .pic = pic,
    });

    const core_lib = b.addLibrary(.{
        .name = "Core",
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libcpp = true,
        }),
    });

    core_lib.root_module.addIncludePath(b.path("src/Common/include"));
    core_lib.root_module.addIncludePath(b.path("src/Core/include"));
    core_lib.root_module.addIncludePath(b.path("src/Core"));
    core_lib.root_module.addIncludePath(b.path("vendor/xxhash64"));

    core_lib.root_module.linkLibrary(aladdin_md5_dep.artifact("aladdin-md5"));
    core_lib.root_module.linkLibrary(libdeflate_dep.artifact("deflate"));

    if (optimize == .Debug) core_lib.root_module.addCMacro("_DEBUG", "");

    core_lib.root_module.addCSourceFiles(.{
        .root = b.path("src/Core"),
        .flags = flags,
        .files = &.{
            "Core.cpp",
            "alloc.cpp",
            "cheats.cpp",
            "memory/pif_lut.cpp",
            "memory/dma.cpp",
            "memory/flashram.cpp",
            "memory/memory.cpp",
            "memory/pif.cpp",
            "memory/savestates.cpp",
            "memory/summercart.cpp",
            "memory/tlb.cpp",
            "r4300/debugger.cpp",
            "r4300/pure_interp.cpp",
            "r4300/cop0.cpp",
            "r4300/cop1.cpp",
            "r4300/cop1_d.cpp",
            "r4300/cop1_helpers.cpp",
            "r4300/cop1_l.cpp",
            "r4300/cop1_s.cpp",
            "r4300/cop1_w.cpp",
            "r4300/disasm.cpp",
            "r4300/exception.cpp",
            "r4300/interrupt.cpp",
            "r4300/r4300.cpp",
            "r4300/recomp.cpp",
            "r4300/regimm.cpp",
            "r4300/rom.cpp",
            "r4300/special.cpp",
            "r4300/timers.cpp",
            "r4300/tracelog.cpp",
            "r4300/bc.cpp",

            "r4300/vcr.cpp",
        },
    });

    if (dynarec) {
        core_lib.root_module.addCMacro("MUPEN64RR_ENABLE_DYNAREC", "");
        core_lib.root_module.addCSourceFiles(.{
            .root = b.path("src/Core"),
            .flags = flags,
            .files = &.{
                "r4300/x86/assemble.cpp",
                "r4300/x86/gbc.cpp",
                "r4300/x86/gcop0.cpp",
                "r4300/x86/gcop1.cpp",
                "r4300/x86/gcop1_d.cpp",
                "r4300/x86/gcop1_helpers.cpp",
                "r4300/x86/gcop1_l.cpp",
                "r4300/x86/gcop1_s.cpp",
                "r4300/x86/gcop1_w.cpp",
                "r4300/x86/gr4300.cpp",
                "r4300/x86/gregimm.cpp",
                "r4300/x86/gspecial.cpp",
                "r4300/x86/gtlb.cpp",
                "r4300/x86/regcache.cpp",
                "r4300/x86/rjump.cpp",
            },
        });
    }

    // core_lib.installHeadersDirectory(b.path("src/Core/include"), "", .{});
    b.installArtifact(core_lib);

    {
        const catch2_dep = b.lazyDependency("catch2", .{
            .target = target,
            .optimize = optimize,
        }).?;

        const step = b.step("test", "Run tests");
        const exe = b.addExecutable(.{
            .name = "Core.Tests",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .strip = strip,
                .pic = pic,
                .link_libcpp = true,

                // WTF?
                .imports = &.{
                    .{ .name = "core", .module = core_lib.root_module },
                },
            }),
        });

        exe.root_module.addIncludePath(b.path("src/Common/include"));
        exe.root_module.addIncludePath(b.path("test/Core.Tests"));
        exe.root_module.addIncludePath(b.path("vendor/xxhash64"));

        exe.root_module.linkLibrary(catch2_dep.artifact("Catch2"));
        exe.root_module.linkLibrary(catch2_dep.artifact("Catch2WithMain"));

        // This is a terrible and disgusting hack but it's not my fault the
        // source tree is set up this way. Ideally this test would be located
        // in src/Core.
        exe.root_module.addIncludePath(b.path("src/Core/include"));
        exe.root_module.addIncludePath(b.path("src/Core"));
        exe.root_module.addIncludePath(b.path("src"));
        exe.root_module.linkLibrary(libdeflate_dep.artifact("deflate"));

        exe.root_module.addCSourceFile(.{
            .flags = flags,
            .file = b.path("test/Core.Tests/vcr_tests.cpp"),
        });

        const run = b.addRunArtifact(exe);
        step.dependOn(&run.step);
    }

    _ = enable_win32;
}
