const std = @import("std");
const Allocator = std.mem.Allocator;

const internal_os = @import("../os/main.zig");
const apprt = @import("../apprt.zig");
const CoreApp = @import("../App.zig");
const CoreSurface = @import("../Surface.zig");
const configpkg = @import("../config.zig");
pub const resourcesDir = internal_os.resourcesDir;

pub const App = struct {
    core_app: *CoreApp,

    pub fn init(
        self: *App,
        core_app: *CoreApp,
        opts: struct {},
    ) !void {
        _ = opts;
        self.* = .{ .core_app = core_app };
    }

    pub fn run(self: *App) !void {
        _ = self;
    }

    pub fn terminate(self: *App) void {
        _ = self;
    }

    pub fn wakeup(self: *App) void {
        _ = self;
    }

    pub fn performAction(
        self: *App,
        target: apprt.Target,
        comptime action: apprt.Action.Key,
        value: apprt.Action.Value(action),
    ) !bool {
        _ = self;
        _ = target;
        _ = value;
        return false;
    }

    pub fn performIpc(
        _: Allocator,
        _: apprt.ipc.Target,
        comptime action: apprt.ipc.Action.Key,
        _: apprt.ipc.Action.Value(action),
    ) !bool {
        return false;
    }
};

pub const Surface = struct {
    pub fn deinit(self: *Surface) void {
        _ = self;
    }

    pub fn close(self: *Surface, process_active: bool) void {
        _ = self;
        _ = process_active;
    }

    pub fn core(self: *Surface) *CoreSurface {
        _ = self;
        unreachable;
    }

    pub fn rtApp(self: *Surface) *App {
        _ = self;
        unreachable;
    }

    pub fn getTitle(self: *Surface) ?[:0]const u8 {
        _ = self;
        return null;
    }

    pub fn getContentScale(self: *const Surface) !apprt.ContentScale {
        _ = self;
        return .{ .x = 1, .y = 1 };
    }

    pub fn getSize(self: *const Surface) !apprt.SurfaceSize {
        _ = self;
        return .{ .width = 800, .height = 600 };
    }

    pub fn getCursorPos(self: *const Surface) !apprt.CursorPos {
        _ = self;
        return .{ .x = 0, .y = 0 };
    }

    pub fn supportsClipboard(self: *const Surface, clipboard: apprt.Clipboard) bool {
        _ = self;
        _ = clipboard;
        return false;
    }

    pub fn clipboardRequest(
        self: *Surface,
        clipboard: apprt.Clipboard,
        request: apprt.ClipboardRequest,
    ) !void {
        _ = self;
        _ = clipboard;
        _ = request;
    }

    pub fn setClipboard(
        self: *Surface,
        clipboard: apprt.Clipboard,
        mime_types: anytype,
    ) void {
        _ = self;
        _ = clipboard;
        _ = mime_types;
    }

    pub fn defaultTermioEnv(self: *Surface) !std.process.EnvMap {
        _ = self;
        return std.process.EnvMap.init(std.heap.page_allocator);
    }

    pub fn handleMessage(self: *Surface, msg: apprt.surface.Message) !void {
        _ = self;
        _ = msg;
    }

    pub fn redrawInspector(self: *Surface) void {
        _ = self;
    }
};
