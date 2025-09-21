const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("3ds.h");
});

const std = @import("std");
const input = @import("input.zig");

export fn main(_: c_int, _: [*]const [*:0]const u8) void {
    _ = c.aptInit();
    defer c.aptExit();
    c.gfxInitDefault();
    defer c.gfxExit();
    _ = c.consoleInit(c.GFX_TOP, null);

    while (c.aptMainLoop()) {
        input.scan();

        _ = c.printf("hello %d %d : %d %d\n", input.circlepad.dx, input.circlepad.dy, input.touch.x, input.touch.y);

        if (input.keys.pressed.anyOf(&[_]input.Key{ .START, .SELECT })) {
            break;
        }

        c.gfxFlushBuffers();
        c.gfxSwapBuffers();
        c.gspWaitForEvent(c.GSPGPU_EVENT_VBlank0, true);
    }
}
