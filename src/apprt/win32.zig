const std = @import("std");
const Allocator = std.mem.Allocator;
const windows = std.os.windows;
const gl = @import("opengl");

const internal_os = @import("../os/main.zig");
const apprt = @import("../apprt.zig");
const CoreApp = @import("../App.zig");
const CoreSurface = @import("../Surface.zig");
const configpkg = @import("../config.zig");
const renderer = @import("../renderer.zig");
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

// ── WGL / OpenGL types ────────────────────────────────
const HGLRC = *opaque {};

const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: u16,
    nVersion: u16,
    dwFlags: u32,
    iPixelType: u8,
    cColorBits: u8,
    cRedBits: u8,
    cRedShift: u8,
    cGreenBits: u8,
    cGreenShift: u8,
    cBlueBits: u8,
    cBlueShift: u8,
    cAlphaBits: u8,
    cAlphaShift: u8,
    cAccumBits: u8,
    cAccumRedBits: u8,
    cAccumGreenBits: u8,
    cAccumBlueBits: u8,
    cAccumAlphaBits: u8,
    cDepthBits: u8,
    cStencilBits: u8,
    cAuxBuffers: u8,
    iLayerType: u8,
    bReserved: u8,
    dwLayerMask: u32,
    dwVisibleMask: u32,
    dwDamageMask: u32,
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
const GWLP_USERDATA: c_int = -21;
const IDC_ARROW: [*:0]const u16 = @ptrFromInt(32512);
const SWP_NOZORDER: u32 = 0x0004;
const SWP_NOACTIVATE: u32 = 0x0010;
const WM_APP_WAKEUP: u32 = 0x0400;
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2: isize = -4;
const MB_ICONERROR: u32 = 0x00000010;

// ── WGL / Pixel format constants ──────────────────────
const PFD_DRAW_TO_WINDOW: u32 = 0x00000004;
const PFD_SUPPORT_OPENGL: u32 = 0x00000020;
const PFD_DOUBLEBUFFER: u32 = 0x00000001;
const PFD_TYPE_RGBA: u8 = 0;

const WGL_CONTEXT_MAJOR_VERSION_ARB: c_int = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB: c_int = 0x2092;
const WGL_CONTEXT_PROFILE_MASK_ARB: c_int = 0x9126;
const WGL_CONTEXT_CORE_PROFILE_BIT_ARB: c_int = 0x00000001;
const WGL_CONTEXT_FLAGS_ARB: c_int = 0x2094;

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
extern "user32" fn GetDC(?HWND) callconv(.winapi) ?HDC;
extern "user32" fn GetClientRect(HWND, *RECT) callconv(.winapi) BOOL;
extern "user32" fn ValidateRect(?HWND, ?*const RECT) callconv(.winapi) BOOL;
extern "user32" fn MessageBoxW(?HWND, [*:0]const u16, [*:0]const u16, u32) callconv(.winapi) c_int;
extern "user32" fn InvalidateRect(?HWND, ?*const RECT, BOOL) callconv(.winapi) BOOL;

// ── GDI extern functions ──────────────────────────────
extern "gdi32" fn ChoosePixelFormat(HDC, *const PIXELFORMATDESCRIPTOR) callconv(.winapi) c_int;
extern "gdi32" fn SetPixelFormat(HDC, c_int, *const PIXELFORMATDESCRIPTOR) callconv(.winapi) BOOL;
extern "gdi32" fn SwapBuffers(HDC) callconv(.winapi) BOOL;

// ── WGL extern functions ──────────────────────────────
extern "opengl32" fn wglCreateContext(HDC) callconv(.winapi) ?HGLRC;
extern "opengl32" fn wglMakeCurrent(?HDC, ?HGLRC) callconv(.winapi) BOOL;
extern "opengl32" fn wglDeleteContext(HGLRC) callconv(.winapi) BOOL;
extern "opengl32" fn wglGetProcAddress([*:0]const u8) callconv(.winapi) ?*const fn () callconv(.c) void;

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
            if (app) |a| {
                a.renderSurface();
                _ = ValidateRect(hwnd, null);
            } else {
                var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
                _ = BeginPaint(hwnd, &ps);
                _ = EndPaint(hwnd, &ps);
            }
            return 0;
        },
        WM_SIZE => {
            if (app) |a| {
                const width: c_int = @intCast(lparam & 0xFFFF);
                const height: c_int = @intCast((lparam >> 16) & 0xFFFF);
                a.updateViewport(width, height);
            }
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg_type, wparam, lparam),
    }
}

// ── App ────────────────────────────────────────────────
pub const App = struct {
    pub const must_draw_from_app_thread = true;

    core_app: *CoreApp,
    hwnd: ?HWND,
    h_instance: HINSTANCE,
    dpi: u32,
    hdc: ?HDC,
    hglrc: ?HGLRC,
    wgl_swap_interval: ?*const fn (c_int) callconv(.winapi) BOOL,
    viewport_width: c_int,
    viewport_height: c_int,
    surface: ?*Surface,
    config: ?configpkg.Config,

    pub fn init(
        self: *App,
        core_app: *CoreApp,
        opts: struct {},
    ) !void {
        _ = opts;

        _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

        const h_instance = GetModuleHandleW(null) orelse return error.NoModuleHandle;

        self.* = .{
            .core_app = core_app,
            .hwnd = null,
            .h_instance = h_instance,
            .dpi = 96,
            .hdc = null,
            .hglrc = null,
            .wgl_swap_interval = null,
            .viewport_width = 0,
            .viewport_height = 0,
            .surface = null,
            .config = null,
        };

        const wc = WNDCLASSEXW{
            .cbSize = @sizeOf(WNDCLASSEXW),
            .style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC,
            .lpfnWndProc = wndProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = h_instance,
            .hIcon = null,
            .hCursor = LoadCursorW(null, IDC_ARROW),
            .hbrBackground = null,
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

        self.initOpenGL() catch |err| {
            log.err("OpenGL init failed: {}", .{err});
            showGLError(hwnd);
            return err;
        };

        // Load configuration (user config files + defaults)
        var config = configpkg.Config.load(core_app.alloc) catch |err| blk: {
            log.warn("config load failed, using defaults: {}", .{err});
            break :blk try configpkg.Config.default(core_app.alloc);
        };
        errdefer config.deinit();

        // Create and initialize the terminal surface
        try self.initSurface(&config);
        self.config = config;

        _ = ShowWindow(hwnd, SW_SHOW);
        log.info("window created, DPI={}", .{self.dpi});
    }

    fn initSurface(self: *App, config: *const configpkg.Config) !void {
        const alloc = self.core_app.alloc;

        const surface = try alloc.create(Surface);
        errdefer alloc.destroy(surface);
        surface.* = .{
            .app = self,
            .core_surface = undefined,
        };

        try self.core_app.addSurface(surface);

        surface.core_surface.init(
            alloc,
            config,
            self.core_app,
            self,
            surface,
        ) catch |err| {
            log.err("CoreSurface init failed: {}", .{err});
            self.core_app.deleteSurface(surface);
            return err;
        };

        self.surface = surface;
        log.info("terminal surface initialized", .{});
    }

    fn initOpenGL(self: *App) !void {
        const hwnd = self.hwnd orelse return error.NoWindow;
        const hdc = GetDC(hwnd) orelse return error.NoDeviceContext;

        var pfd = std.mem.zeroes(PIXELFORMATDESCRIPTOR);
        pfd.nSize = @sizeOf(PIXELFORMATDESCRIPTOR);
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cDepthBits = 24;
        pfd.cStencilBits = 8;

        const format = ChoosePixelFormat(hdc, &pfd);
        if (format == 0) return error.ChoosePixelFormatFailed;
        if (SetPixelFormat(hdc, format, &pfd) == 0) return error.SetPixelFormatFailed;

        const legacy_ctx = wglCreateContext(hdc) orelse return error.WglCreateContextFailed;
        if (wglMakeCurrent(hdc, legacy_ctx) == 0) return error.WglMakeCurrentFailed;

        const create_ctx_attribs: ?*const fn (?HDC, ?HGLRC, ?[*]const c_int) callconv(.winapi) ?HGLRC =
            @ptrCast(wglGetProcAddress("wglCreateContextAttribsARB"));

        self.wgl_swap_interval = @ptrCast(wglGetProcAddress("wglSwapIntervalEXT"));

        if (create_ctx_attribs) |createCtx| {
            const attribs = [_]c_int{
                WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                WGL_CONTEXT_MINOR_VERSION_ARB, 3,
                WGL_CONTEXT_PROFILE_MASK_ARB,  WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
                0,
            };

            const modern_ctx = createCtx(hdc, null, &attribs) orelse {
                _ = wglMakeCurrent(null, null);
                _ = wglDeleteContext(legacy_ctx);
                return error.OpenGL43NotSupported;
            };

            _ = wglMakeCurrent(null, null);
            _ = wglDeleteContext(legacy_ctx);

            if (wglMakeCurrent(hdc, modern_ctx) == 0) return error.WglMakeCurrentFailed;
            self.hglrc = modern_ctx;
        } else {
            _ = wglMakeCurrent(null, null);
            _ = wglDeleteContext(legacy_ctx);
            return error.OpenGL43NotSupported;
        }

        self.hdc = hdc;

        const version = gl.glad.load(null) catch return error.GLADLoadFailed;
        const major = gl.glad.versionMajor(@intCast(version));
        const minor = gl.glad.versionMinor(@intCast(version));
        log.info("OpenGL {}.{} loaded via WGL", .{ major, minor });

        if (major < 4 or (major == 4 and minor < 3)) {
            return error.OpenGL43NotSupported;
        }

        if (self.wgl_swap_interval) |setInterval| {
            _ = setInterval(1);
            log.info("VSync enabled", .{});
        }

        var rect: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(self.hwnd.?, &rect);
        self.viewport_width = rect.right - rect.left;
        self.viewport_height = rect.bottom - rect.top;
        gl.viewport(0, 0, self.viewport_width, self.viewport_height) catch {};

        log.info("GL viewport {}x{}", .{ self.viewport_width, self.viewport_height });
    }

    fn showGLError(hwnd: ?HWND) void {
        const msg = std.unicode.utf8ToUtf16LeStringLiteral(
            "Ghostty requires OpenGL 4.3 or later.\r\n\r\nPlease update your graphics drivers.",
        );
        const title = std.unicode.utf8ToUtf16LeStringLiteral("Ghostty \u{2013} Graphics Error");
        _ = MessageBoxW(hwnd, msg, title, MB_ICONERROR);
    }

    fn updateViewport(self: *App, width: c_int, height: c_int) void {
        if (self.hglrc == null) return;
        self.viewport_width = width;
        self.viewport_height = height;
        gl.viewport(0, 0, width, height) catch {};
    }

    fn renderSurface(self: *App) void {
        const hdc = self.hdc orelse return;
        if (self.hglrc == null) return;

        if (self.surface) |s| {
            s.core_surface.renderer.drawFrame(true) catch |err| {
                log.warn("drawFrame failed: {}", .{err});
            };
        } else {
            gl.clearColor(0.1, 0.1, 0.12, 1.0);
            gl.clear(gl.c.GL_COLOR_BUFFER_BIT);
        }
        _ = SwapBuffers(hdc);
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
        if (self.surface) |s| {
            s.core_surface.deinit();
            self.core_app.alloc.destroy(s);
            self.surface = null;
        }
        if (self.config) |*c| {
            c.deinit();
            self.config = null;
        }
        if (self.hglrc) |ctx| {
            _ = wglMakeCurrent(null, null);
            _ = wglDeleteContext(ctx);
            self.hglrc = null;
        }
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
        switch (action) {
            .render => {
                switch (target) {
                    .app => {},
                    .surface => |_| {
                        if (self.hwnd) |hwnd| _ = InvalidateRect(hwnd, null, 0);
                    },
                }
                return true;
            },
            .size_limit,
            .cell_size,
            .initial_size,
            .set_title,
            .mouse_shape,
            .mouse_visibility,
            .renderer_health,
            => {
                _ = value;
                return false;
            },
            else => {
                _ = value;
                log.warn("unimplemented action: {s}", .{@tagName(action)});
                return false;
            },
        }
    }

    pub fn performIpc(
        _: Allocator,
        _: apprt.ipc.Target,
        comptime action: apprt.ipc.Action.Key,
        _: apprt.ipc.Action.Value(action),
    ) !bool {
        return false;
    }

    pub fn redrawInspector(_: *App, _: *Surface) void {}
};

// ── Surface ───────────────────────────────────────────
pub const Surface = struct {
    app: *App,
    core_surface: CoreSurface,

    pub fn deinit(self: *Surface) void {
        self.core_surface.deinit();
    }

    pub fn close(self: *Surface, process_active: bool) void {
        _ = process_active;
        _ = self;
    }

    pub fn core(self: *Surface) *CoreSurface {
        return &self.core_surface;
    }

    pub fn rtApp(self: *Surface) *App {
        return self.app;
    }

    pub fn getTitle(self: *Surface) ?[:0]const u8 {
        _ = self;
        return null;
    }

    pub fn getContentScale(self: *const Surface) !apprt.ContentScale {
        const scale: f32 = @as(f32, @floatFromInt(self.app.dpi)) / 96.0;
        return .{ .x = scale, .y = scale };
    }

    pub fn getSize(self: *const Surface) !apprt.SurfaceSize {
        const a = self.app;
        if (a.hwnd) |hwnd| {
            var rect: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &rect);
            return .{
                .width = @intCast(rect.right - rect.left),
                .height = @intCast(rect.bottom - rect.top),
            };
        }
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
