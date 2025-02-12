const std = @import("std");
const builtin = @import("builtin");

const emulator = "/mnt/c/Program Files/Lime3DS/lime3ds.exe";
const ds_ip = "192.168.1.60";
const flags = .{"-lctru"};
const devkitpro = "/opt/devkitpro";

pub fn build(b: *std.Build) void {
    b.libc_file = "libc.txt";

    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.mpcore },
    } });
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .link_libc = true,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    mod.addIncludePath(.{ .cwd_relative = devkitpro ++ "/libctru/include" });
    mod.addIncludePath(.{ .cwd_relative = devkitpro ++ "/portlibs/3ds/include" });
    mod.addIncludePath(.{ .cwd_relative = devkitpro ++ "/devkitARM/arm-none-eabi/include" });

    const obj = b.addObject(.{ .name = "zig-3ds", .root_module = mod });

    const extension = if (builtin.target.os.tag == .windows) ".exe" else "";
    const elf = b.addSystemCommand(&(.{devkitpro ++ "/devkitARM/bin/arm-none-eabi-gcc" ++ extension}));

    elf.addArg("-g");
    elf.addArg("-march=armv6k");
    elf.addArg("-mtune=mpcore");
    elf.addArg("-mfloat-abi=hard");
    elf.addArg("-mtp=soft");
    const map_file = elf.addPrefixedOutputFileArg("-Wl,-Map,", "zig-3ds.map");
    elf.addArg("-specs=" ++ devkitpro ++ "/devkitARM/arm-none-eabi/lib/3dsx.specs");

    _ = map_file;

    elf.addFileArg(obj.getEmittedBin());
    elf.addArgs(&.{
        "-L" ++ devkitpro ++ "/libctru/lib",
        "-L" ++ devkitpro ++ "/portlibs/3ds/lib",
    });
    elf.addArgs(&flags);
    elf.addArg("-o");
    const elf_file = elf.addOutputFileArg("zig-3ds.elf");

    const dsx = b.addSystemCommand(&.{
        devkitpro ++ "/tools/bin/3dsxtool" ++ extension,
    });
    dsx.addFileArg(elf_file);
    const dsx_file = dsx.addOutputFileArg("zig-3ds.3dsx");

    const install_dsx = b.addInstallFile(dsx_file, "zig-3ds.3dsx");
    const install_elf = b.addInstallFile(elf_file, "zig-3ds.elf");

    b.default_step.dependOn(&install_dsx.step);
    b.default_step.dependOn(&install_elf.step);

    b.default_step.dependOn(&dsx.step);
    dsx.step.dependOn(&elf.step);
    elf.step.dependOn(&obj.step);

    const run_step = b.step("run", "Run in Citra");
    const citra = b.addSystemCommand(&.{emulator});
    citra.addFileArg(dsx_file);

    run_step.dependOn(&dsx.step);
    run_step.dependOn(&citra.step);

    const send_step = b.step("send", "Send to 3DS");
    const link = b.addSystemCommand(&.{ devkitpro ++ "/tools/bin/3dslink" ++ extension, "-a", ds_ip });
    link.addFileArg(dsx_file);
    send_step.dependOn(&dsx.step);
    send_step.dependOn(&link.step);
}
