const std = @import("std");
const builtin = @import("builtin");

const flags = .{"-lctru"};

const Config = struct {
    project_name: []const u8,
    devkitpro_path: []const u8,
    run_path: ?[]const u8 = null,
    console_ip: ?[]const u8 = null,
};

const config: Config = @import("config.zon");
const devkitpro = config.devkitpro_path;
const project_name = config.project_name;

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

    const obj = b.addObject(.{ .name = project_name, .root_module = mod });

    const extension = if (builtin.target.os.tag == .windows) ".exe" else "";
    const elf = b.addSystemCommand(&(.{devkitpro ++ "/devkitARM/bin/arm-none-eabi-gcc" ++ extension}));

    elf.addArg("-g");
    elf.addArg("-march=armv6k");
    elf.addArg("-mtune=mpcore");
    elf.addArg("-mfloat-abi=hard");
    elf.addArg("-mtp=soft");
    elf.addArg("-Wl,-z,noexecstack");
    const map_file = elf.addPrefixedOutputFileArg("-Wl,-Map,", project_name ++ ".map");
    elf.addArg("-specs=" ++ devkitpro ++ "/devkitARM/arm-none-eabi/lib/3dsx.specs");

    elf.addFileArg(obj.getEmittedBin());
    elf.addArgs(&.{
        "-L" ++ devkitpro ++ "/libctru/lib",
        "-L" ++ devkitpro ++ "/portlibs/3ds/lib",
    });
    elf.addArgs(&flags);
    elf.addArg("-o");
    const elf_file = elf.addOutputFileArg(project_name ++ ".elf");

    const dsx = b.addSystemCommand(&.{
        devkitpro ++ "/tools/bin/3dsxtool" ++ extension,
    });
    dsx.addFileArg(elf_file);
    const dsx_file = dsx.addOutputFileArg(project_name ++ ".3dsx");

    const install_dsx = b.addInstallFile(dsx_file, project_name ++ ".3dsx");
    const install_map = b.addInstallFile(map_file, project_name ++ ".map");
    const install_elf = b.addInstallFile(elf_file, project_name ++ ".elf");

    b.default_step.dependOn(&install_dsx.step);
    b.default_step.dependOn(&install_map.step);
    b.default_step.dependOn(&install_elf.step);

    b.default_step.dependOn(&dsx.step);
    dsx.step.dependOn(&elf.step);
    elf.step.dependOn(&obj.step);

    const run_step = b.step("run", "Run in Emulator of choice");
    if (config.run_path) |run_path| {
        const run_executable = b.addSystemCommand(&.{run_path});
        run_executable.addFileArg(dsx_file);

        run_step.dependOn(&dsx.step);
        run_step.dependOn(&run_executable.step);
    } else {
        run_step.fail("Need to set config property run_path to use this option", .{}) catch {};
    }

    const send_step = b.step("send", "Send to 3DS");
    const remote_dbg = b.step("remotedbg", "Send to 3DS and connect GDB");
    if (config.console_ip) |console_ip| {
        const dslink = b.addSystemCommand(&.{ devkitpro ++ "/tools/bin/3dslink" ++ extension, "-a", console_ip });
        dslink.addFileArg(dsx_file);
        send_step.dependOn(&dsx.step);
        send_step.dependOn(&dslink.step);

        const gdb = b.addSystemCommand(&.{devkitpro ++ "/devkitARM/bin/arm-none-eabi-gdb"});
        gdb.addFileArg(elf_file);
        gdb.addArg("-ex");
        gdb.addArg("target remote " ++ console_ip ++ ":4003");

        gdb.step.dependOn(&dslink.step);
        remote_dbg.dependOn(&gdb.step);
    } else {
        send_step.fail("Need to set config property console_ip to use this option", .{}) catch {};
    }
}
