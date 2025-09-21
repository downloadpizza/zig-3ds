const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("3ds.h");
});

pub fn scan() void {
    c.hidScanInput();
    keys.updateState();
    updateCirclePad();
    updateTouch();
}

pub const Key = enum(c_uint) {
    A = c.KEY_A,
    B = c.KEY_B,
    SELECT = c.KEY_SELECT,
    START = c.KEY_START,
    DRIGHT = c.KEY_DRIGHT,
    DLEFT = c.KEY_DLEFT,
    DUP = c.KEY_DUP,
    DDOWN = c.KEY_DDOWN,
    R = c.KEY_R,
    L = c.KEY_L,
    X = c.KEY_X,
    Y = c.KEY_Y,
    ZL = c.KEY_ZL,
    ZR = c.KEY_ZR,
    TOUCH = c.KEY_TOUCH,
    CSTICK_RIGHT = c.KEY_CSTICK_RIGHT,
    CSTICK_LEFT = c.KEY_CSTICK_LEFT,
    CSTICK_UP = c.KEY_CSTICK_UP,
    CSTICK_DOWN = c.KEY_CSTICK_DOWN,
    CPAD_RIGHT = c.KEY_CPAD_RIGHT,
    CPAD_LEFT = c.KEY_CPAD_LEFT,
    CPAD_UP = c.KEY_CPAD_UP,
    CPAD_DOWN = c.KEY_CPAD_DOWN,
    UP = c.KEY_UP,
    DOWN = c.KEY_DOWN,
    LEFT = c.KEY_LEFT,
    RIGHT = c.KEY_RIGHT,
};

pub const keys = struct {
    pub var pressed = KeyState{ .state = 0 };
    pub var released = KeyState{ .state = 0 };
    pub var held = KeyState{ .state = 0 };
    pub var pressedRepeat = KeyState{ .state = 0 };

    fn updateState() void {
        pressed.state = c.hidKeysDown();
        released.state = c.hidKeysUp();
        pressedRepeat.state = c.hidKeysDownRepeat();
        held.state = c.hidKeysHeld();
    }
};

const KeyState = struct {
    state: u32,

    pub fn anyOf(self: *const KeyState, comptime checkKeys: []const Key) bool {
        comptime var keysOr: u32 = 0;
        inline for (checkKeys) |key| {
            keysOr |= @intFromEnum(key);
        }

        return (self.state & keysOr) != 0;
    }

    pub fn allOf(self: *const KeyState, comptime checkKeys: []const Key) bool {
        comptime var keysOr: u32 = 0;
        inline for (checkKeys) |key| {
            keysOr |= @intFromEnum(key);
        }

        return (self.state & keysOr) == keysOr;
    }
};

const CirclePadState = packed struct {
    dx: i16,
    dy: i16,
};

pub var circlepad = CirclePadState{ .dx = 0, .dy = 0 };

fn updateCirclePad() void {
    c.hidCircleRead(@ptrFromInt(@intFromPtr(&circlepad)));
}

const TouchState = packed struct { x: u16, y: u16 };

pub var touch: TouchState align(2) = TouchState{ .x = 0, .y = 0 };

fn updateTouch() void {
    const op: *align(2) anyopaque = &touch;
    c.hidTouchRead(@ptrCast(op));
}
