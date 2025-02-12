const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("3ds.h");
});

const std = @import("std");

fn isPressed(kDown: u32, keys: u32) bool {
    return (kDown & keys) == keys;
}

export fn main(_: c_int, _: [*]const [*:0]const u8) void {
    _ = c.aptInit();
    defer c.aptExit();
    c.gfxInitDefault();
    defer c.gfxExit();
    _ = c.consoleInit(c.GFX_TOP, null);

    while (c.aptMainLoop()) {
        c.scanKeys();
        _ = c.printf("hello\n");

        const kDown: u32 = c.keysDown();

        if (isPressed(kDown, c.KEY_START)) {
            break;
        }

        c.gfxFlushBuffers();
        c.gfxSwapBuffers();
        c.gspWaitForEvent(c.GSPGPU_EVENT_VBlank0, true);
    }
}
