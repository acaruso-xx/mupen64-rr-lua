const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce position independent code");

    const use_std_format = b.option(bool, "use-std-format", "Use std::format instead of fmt library") orelse false;
    const wchar_support = b.option(bool, "wchar-support", "Support wchar api") orelse false;

    const upstream = b.dependency("spdlog", .{});

    const lib = b.addLibrary(.{
        .name = "spdlog",
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libcpp = true,
        }),
    });

    if (use_std_format) {
        lib.root_module.addCMacro("SPDLOG_USE_STD_FORMAT", "");
    } else {
        lib.root_module.addCSourceFile(.{
            .file = upstream.path("src/bundled_fmtlib_format.cpp"),
        });
    }

    if (wchar_support) {
        lib.root_module.addCMacro("SPDLOG_WCHAR_TO_UTF8_SUPPORT", "");
    }

    lib.root_module.addCMacro("SPDLOG_COMPILED_LIB", "");

    lib.root_module.addIncludePath(upstream.path("include"));
    lib.root_module.addCSourceFiles(.{
        .root = upstream.path("src"),
        .flags = &.{"-std=c++23"},
        .files = &.{
            "spdlog.cpp",
            "stdout_sinks.cpp",
            "color_sinks.cpp",
            "file_sinks.cpp",
            "async.cpp",
            "cfg.cpp",
        },
    });

    lib.installHeadersDirectory(upstream.path("include"), "", .{});
    b.installArtifact(lib);
}
