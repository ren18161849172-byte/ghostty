const std = @import("std");
const Allocator = std.mem.Allocator;
const windows = std.os.windows;

const internal_os = @import("../os/main.zig");
const apprt = @import("../apprt.zig");
const CoreApp = @import("../App.zig");
const CoreSurface = @import("../Surface.zig");
const configpkg = @import("../config.zig");
pub const resourcesDir = internal_os.resourcesDir;

const log = std.log.scoped(.win32);

// ── Win32 type aliases (available in std) ──────────────
const HWND = windows.HWND;
const HINSTANCE = windows.HINSTANCE;
const HICON = windows.HICON;
const HCURSOR = windows.HCURSOR;
const HBRUSH = windows.HBRUSH;
const HMENU = windows.HMENU;
const HDC = windows.HDC;
const WPARAM = windows.WPARAM;
const LPARAM = windows.LPARAM;
const LRESULT = windows.LRESULT;
const BOOL = windows.BOOL;

const WNDPROC = *const fn (HWND, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT;

// ── Win32 structs (not in std) ─────────────────────────
const POINT = extern struct { x: i32, y: i32 };
const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };

const WNDCLASSEXW = extern struct {
    cbSize: u32,
    style: u32,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int,
    cbWndExtra: c_int,
    hInstance: ?HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?HICON,
};

const MSG = extern struct {
    hwnd: ?HWND,
    message: u32,
    wParam: WPARAM,
    lParam: LPARAM,
    time: u32,
    pt: POINT,
};

const CREATESTRUCTW = extern struct {
    lpCreateParams: ?*anyopaque,
    hInstance: ?HINSTANCE,
    hMenu: ?HMENU,
    hwndParent: ?HWND,
    cy: c_int,
    cx: c_int,
    y: c_int,
    x: c_int,
    style: i32,
    lpszName: ?[*:0]const u16,
    lpszClass: ?[*:0]const u16,
    dwExStyle: u32,
};

const PAINTSTRUCT = extern struct {
    hdc: ?HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]u8,
};

// ── Win32 constants ────────────────────────────────────
const WM_DESTROY: u32 = 0x0002;
const WM_SIZE: u32 = 0x0005;
const WM_PAINT: u32 = 0x000F;
const WM_CLOSE: u32 = 0x0010;
const WM_NCCREATE: u32 = 0x0081;
const WM_DPICHANGED: u32 = 0x02E0;

const WS_OVERLAPPEDWINDOW: u32 = 0x00CF0000;
const CS_HREDRAW: u32 = 0x0002;
const CS_VREDRAW: u32 = 0x0001;
const CS_OWNDC: u32 = 0x0020;
const SW_SHOW: c_int = 5;
const CW_USEDEFAULT: c_int = @bitCast(@as(u32, 0x80000000));
const COLOR_WINDOW: usize = 5;
const GWLP_USERDATA: c_int = -21;
const IDC_ARROW: [*:0]const u16 = @ptrFromInt(32512);
const SWP_NOZORDER: u32 = 0x0004;
const SWP_NOACTIVATE: u32 = 0x0010;
const WM_APP_WAKEUP: u32 = 0x0400;
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2: isize = -4;

const CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyWindow");
const WINDOW_TITLE = std.unicode.utf8ToUtf16LeStringLiteral("Ghostty");

// ── Win32 extern functions ─────────────────────────────
extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(.winapi) u16;
extern "user32" fn CreateWindowExW(u32, [*:0]const u16, [*:0]const u16, u32, c_int, c_int, c_int, c_int, ?HWND, ?HMENU, ?HINSTANCE, ?*anyopaque) callconv(.winapi) ?HWND;
extern "user32" fn DefWindowProcW(HWND, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn GetMessageW(*MSG, ?HWND, u32, u32) callconv(.winapi) BOOL;
extern "user32" fn TranslateMessage(*const MSG) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageW(*const MSG) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(c_int) callconv(.winapi) void;
extern "user32" fn ShowWindow(HWND, c_int) callconv(.winapi) BOOL;
extern "user32" fn DestroyWindow(HWND) callconv(.winapi) BOOL;
extern "user32" fn PostMessageW(HWND, u32, WPARAM, LPARAM) callconv(.winapi) BOOL;
extern "user32" fn SetWindowLongPtrW(HWND, c_int, isize) callconv(.winapi) isize;
extern "user32" fn GetWindowLongPtrW(HWND, c_int) callconv(.winapi) isize;
extern "user32" fn LoadCursorW(?HINSTANCE, [*:0]const u16) callconv(.winapi) ?HCURSOR;
extern "user32" fn GetDpiForWindow(HWND) callconv(.winapi) u32;
extern "user32" fn SetProcessDpiAwarenessContext(isize) callconv(.winapi) BOOL;
extern "user32" fn SetWindowPos(HWND, ?HWND, c_int, c_int, c_int, c_int, u32) callconv(.winapi) BOOL;
extern "user32" fn BeginPaint(HWND, *PAINTSTRUCT) callconv(.winapi) ?HDC;
extern "user32" fn EndPaint(HWND, *const PAINTSTRUCT) callconv(.winapi) BOOL;
extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(.winapi) ?HINSTANCE;

// ── Window procedure ───────────────────────────────────
fn wndProc(hwnd: HWND, msg_type: u32, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
    const ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA);
    const app: ?*App = if (ptr == 0) null else @ptrFromInt(@as(usize, @bitCast(ptr)));

    switch (msg_type) {
        WM_NCCREATE => {
            const cs: *const CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lparam)));
            if (cs.lpCreateParams) |create_params| {
                _ = SetWindowLongPtrW(hwnd, GWLP_USERDATA, @bitCast(@intFromPtr(create_params)));
            }
            return DefWindowProcW(hwnd, msg_type, wparam, lparam);
        },
        WM_CLOSE => {
            _ = DestroyWindow(hwnd);
            return 0;
        },
        WM_DESTROY => {
            if (app) |a| a.hwnd = null;
            PostQuitMessage(0);
            return 0;
        },
        WM_DPICHANGED => {
            if (app) |a| {
                a.dpi = @truncate(wparam & 0xFFFF);
                const suggested: *const RECT = @ptrFromInt(@as(usize, @bitCast(lparam)));
                _ = SetWindowPos(
                    hwnd,
                    null,
                    suggested.left,
                    suggested.top,
                    suggested.right - suggested.left,
                    suggested.bottom - suggested.top,
                    SWP_NOZORDER | SWP_NOACTIVATE,
                );
                log.info("DPI changed to {}", .{a.dpi});
            }
            return 0;
        },
        WM_PAINT => {
            var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
            _ = BeginPaint(hwnd, &ps);
            _ = EndPaint(hwnd, &ps);
            return 0;
        },
        WM_SIZE => {
            if (app) |_| {
                // Surface resize will be handled in Issue #4+
            }
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg_type, wparam, lparam),
    }
}

// ── App ────────────────────────────────────────────────
pub const App = struct {
    core_app: *CoreApp,
    hwnd: ?HWND,
    h_instance: HINSTANCE,
    dpi: u32,

    pub fn init(
        self: *App,
        core_app: *CoreApp,
        opts: struct {},
    ) !void {
        _ = opts;

        // Per-Monitor V2 DPI awareness (Windows 10 1703+, our minimum is 22H2)
        _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

        const h_instance = GetModuleHandleW(null) orelse return error.NoModuleHandle;

        // Pre-initialize so WndProc can safely access fields during CreateWindowExW
        self.* = .{
            .core_app = core_app,
            .hwnd = null,
            .h_instance = h_instance,
            .dpi = 96,
        };

        const bg_brush: HBRUSH = @ptrFromInt(COLOR_WINDOW + 1);
        const wc = WNDCLASSEXW{
            .cbSize = @sizeOf(WNDCLASSEXW),
            .style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC,
            .lpfnWndProc = wndProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = h_instance,
            .hIcon = null,
            .hCursor = LoadCursorW(null, IDC_ARROW),
            .hbrBackground = bg_brush,
            .lpszMenuName = null,
            .lpszClassName = CLASS_NAME,
            .hIconSm = null,
        };

        if (RegisterClassExW(&wc) == 0) return error.RegisterClassFailed;

        const hwnd = CreateWindowExW(
            0,
            CLASS_NAME,
            WINDOW_TITLE,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            null,
            null,
            h_instance,
            @ptrCast(self),
        ) orelse return error.CreateWindowFailed;

        self.hwnd = hwnd;
        self.dpi = GetDpiForWindow(hwnd);

        _ = ShowWindow(hwnd, SW_SHOW);

        log.info("window created, DPI={}", .{self.dpi});
    }

    pub fn run(self: *App) !void {
        var msg: MSG = std.mem.zeroes(MSG);
        while (true) {
            const ret = GetMessageW(&msg, null, 0, 0);
            if (ret == 0) break;
            if (ret < 0) return error.GetMessageFailed;
            _ = TranslateMessage(&msg);
            _ = DispatchMessageW(&msg);

            self.core_app.tick(self) catch |err| {
                log.err("core tick failed: {}", .{err});
            };
        }
    }

    pub fn terminate(self: *App) void {
        if (self.hwnd) |hwnd| {
            _ = DestroyWindow(hwnd);
            self.hwnd = null;
        }
    }

    pub fn wakeup(self: *App) void {
        if (self.hwnd) |hwnd| {
            _ = PostMessageW(hwnd, WM_APP_WAKEUP, 0, 0);
        }
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
        log.warn("unimplemented action: {s}", .{@tagName(action)});
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

// ── Surface (stub — fleshed out in Issues #4+) ────────
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
    ) !bool {
        _ = self;
        _ = clipboard;
        _ = request;
        return false;
    }

    pub fn setClipboard(
        self: *Surface,
        clipboard: apprt.Clipboard,
        contents: []const apprt.ClipboardContent,
        confirm: bool,
    ) !void {
        _ = self;
        _ = clipboard;
        _ = contents;
        _ = confirm;
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
