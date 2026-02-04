const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce position independent code");

    const lib = b.addLibrary(.{
        .name = "aladdin-md5",
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libc = true,
        }),
    });

    lib.root_module.addCSourceFile(.{ .file = b.path("md5.c") });

    lib.installHeader(b.path("md5.h"), "md5.h");
    b.installArtifact(lib);
}
