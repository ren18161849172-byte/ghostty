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
const input = @import("../input.zig");
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

// ── IME structs ────────────────────────────────────────
const HIMC = *opaque {};
const COMPOSITIONFORM = extern struct {
    dwStyle: u32,
    ptCurrentPos: POINT,
    rcArea: RECT,
};
const CANDIDATEFORM = extern struct {
    dwIndex: u32,
    dwStyle: u32,
    ptCurrentPos: POINT,
    rcArea: RECT,
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
const WM_SETFOCUS: u32 = 0x0007;
const WM_KILLFOCUS: u32 = 0x0008;
const WM_PAINT: u32 = 0x000F;
const WM_CLOSE: u32 = 0x0010;
const WM_KEYDOWN: u32 = 0x0100;
const WM_KEYUP: u32 = 0x0101;
const WM_CHAR: u32 = 0x0102;
const WM_SYSKEYDOWN: u32 = 0x0104;
const WM_SYSKEYUP: u32 = 0x0105;
const WM_NCCREATE: u32 = 0x0081;
const WM_DPICHANGED: u32 = 0x02E0;
// ── Mouse message constants ──────────────────────────
const WM_MOUSEMOVE: u32 = 0x0200;
const WM_LBUTTONDOWN: u32 = 0x0201;
const WM_LBUTTONUP: u32 = 0x0202;
const WM_LBUTTONDBLCLK: u32 = 0x0203;
const WM_RBUTTONDOWN: u32 = 0x0204;
const WM_RBUTTONUP: u32 = 0x0205;
const WM_RBUTTONDBLCLK: u32 = 0x0206;
const WM_MBUTTONDOWN: u32 = 0x0207;
const WM_MBUTTONUP: u32 = 0x0208;
const WM_MOUSEWHEEL: u32 = 0x020A;
const WM_MOUSEHWHEEL: u32 = 0x020E;

const WM_KEYFIRST: u32 = 0x0100;
const WM_KEYLAST: u32 = 0x0109;
const SIZE_MINIMIZED: u32 = 1;

// ── IME message constants ────────────────────────────
const WM_IME_SETCONTEXT: u32 = 0x0281;
const WM_IME_STARTCOMPOSITION: u32 = 0x010D;
const WM_IME_ENDCOMPOSITION: u32 = 0x010E;
const WM_IME_COMPOSITION: u32 = 0x010F;

// ── IME composition flags ──────────────────────────────
const GCS_RESULTSTR: u32 = 0x0800;
const GCS_COMPSTR: u32 = 0x0008;
const CFS_POINT: u32 = 0x0002;
const CFS_FORCE_POSITION: u32 = 0x0020;
const CFS_CANDIDATEPOS: u32 = 0x0040;

// ── Clipboard format constants ────────────────────────
const CF_UNICODETEXT: u32 = 13;
const GHND: u32 = 0x0042;

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

// ── Virtual key constants ─────────────────────────────
const VK_BACK: u16 = 0x08;
const VK_TAB: u16 = 0x09;
const VK_RETURN: u16 = 0x0D;
const VK_SHIFT: u16 = 0x10;
const VK_CONTROL: u16 = 0x11;
const VK_MENU: u16 = 0x12;
const VK_PAUSE: u16 = 0x13;
const VK_CAPITAL: u16 = 0x14;
const VK_ESCAPE: u16 = 0x1B;
const VK_SPACE: u16 = 0x20;
const VK_PRIOR: u16 = 0x21;
const VK_NEXT: u16 = 0x22;
const VK_END: u16 = 0x23;
const VK_HOME: u16 = 0x24;
const VK_LEFT: u16 = 0x25;
const VK_UP: u16 = 0x26;
const VK_RIGHT: u16 = 0x27;
const VK_DOWN: u16 = 0x28;
const VK_SNAPSHOT: u16 = 0x2C;
const VK_INSERT: u16 = 0x2D;
const VK_DELETE: u16 = 0x2E;
const VK_LWIN: u16 = 0x5B;
const VK_RWIN: u16 = 0x5C;
const VK_APPS: u16 = 0x5D;
const VK_NUMPAD0: u16 = 0x60;
const VK_MULTIPLY: u16 = 0x6A;
const VK_ADD: u16 = 0x6B;
const VK_SEPARATOR: u16 = 0x6C;
const VK_SUBTRACT: u16 = 0x6D;
const VK_DECIMAL: u16 = 0x6E;
const VK_DIVIDE: u16 = 0x6F;
const VK_F1: u16 = 0x70;
const VK_NUMLOCK: u16 = 0x90;
const VK_SCROLL: u16 = 0x91;
const VK_LSHIFT: u16 = 0xA0;
const VK_RSHIFT: u16 = 0xA1;
const VK_LCONTROL: u16 = 0xA2;
const VK_RCONTROL: u16 = 0xA3;
const VK_LMENU: u16 = 0xA4;
const VK_RMENU: u16 = 0xA5;
const VK_OEM_1: u16 = 0xBA;
const VK_OEM_PLUS: u16 = 0xBB;
const VK_OEM_COMMA: u16 = 0xBC;
const VK_OEM_MINUS: u16 = 0xBD;
const VK_OEM_PERIOD: u16 = 0xBE;
const VK_OEM_2: u16 = 0xBF;
const VK_OEM_3: u16 = 0xC0;
const VK_OEM_4: u16 = 0xDB;
const VK_OEM_5: u16 = 0xDC;
const VK_OEM_6: u16 = 0xDD;
const VK_OEM_7: u16 = 0xDE;
const VK_OEM_102: u16 = 0xE2;

const MAPVK_VK_TO_CHAR: u32 = 2;

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
extern "user32" fn SetWindowTextW(HWND, [*:0]const u16) callconv(.winapi) BOOL;
extern "user32" fn GetKeyState(c_int) callconv(.winapi) c_short;
extern "user32" fn GetKeyboardState(*[256]u8) callconv(.winapi) BOOL;
extern "user32" fn ToUnicode(u32, u32, *const [256]u8, [*]u16, c_int, u32) callconv(.winapi) c_int;
extern "user32" fn MapVirtualKeyW(u32, u32) callconv(.winapi) u32;

// ── Mouse/clipboard extern functions ──────────────────
extern "user32" fn OpenClipboard(?HWND) callconv(.winapi) BOOL;
extern "user32" fn CloseClipboard() callconv(.winapi) BOOL;
extern "user32" fn GetClipboardData(u32) callconv(.winapi) ?*anyopaque;
extern "user32" fn SetClipboardData(u32, ?*anyopaque) callconv(.winapi) ?*anyopaque;
extern "user32" fn EmptyClipboard() callconv(.winapi) BOOL;
extern "user32" fn IsClipboardFormatAvailable(u32) callconv(.winapi) BOOL;
extern "kernel32" fn GlobalAlloc(u32, usize) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn GlobalLock(?*anyopaque) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn GlobalUnlock(?*anyopaque) callconv(.winapi) BOOL;
extern "kernel32" fn GlobalSize(?*anyopaque) callconv(.winapi) usize;
extern "kernel32" fn GlobalFree(?*anyopaque) callconv(.winapi) ?*anyopaque;
extern "gdi32" fn ChoosePixelFormat(HDC, *const PIXELFORMATDESCRIPTOR) callconv(.winapi) c_int;
extern "gdi32" fn SetPixelFormat(HDC, c_int, *const PIXELFORMATDESCRIPTOR) callconv(.winapi) BOOL;
extern "gdi32" fn SwapBuffers(HDC) callconv(.winapi) BOOL;
extern "gdi32" fn CreateSolidBrush(u32) callconv(.winapi) ?*anyopaque;
extern "user32" fn FillRect(HDC, *const RECT, ?*anyopaque) callconv(.winapi) c_int;
extern "gdi32" fn DeleteObject(?*anyopaque) callconv(.winapi) BOOL;

fn win32CreateSolidBrush(rgb: u32) ?*anyopaque {
    // COLORREF = 0x00BBGGRR
    const r = (rgb >> 16) & 0xFF;
    const g = (rgb >> 8) & 0xFF;
    const b = rgb & 0xFF;
    const colorref = (r) | (g << 8) | (b << 16);
    return CreateSolidBrush(colorref);
}

// ── WGL extern functions ──────────────────────────────
extern "opengl32" fn wglCreateContext(HDC) callconv(.winapi) ?HGLRC;
extern "opengl32" fn wglMakeCurrent(?HDC, ?HGLRC) callconv(.winapi) BOOL;
extern "opengl32" fn wglDeleteContext(HGLRC) callconv(.winapi) BOOL;
extern "opengl32" fn wglGetProcAddress([*:0]const u8) callconv(.winapi) ?*const fn () callconv(.c) void;

// ── IMM32 extern functions ─────────────────────────────
extern "imm32" fn ImmGetContext(?HWND) callconv(.winapi) ?HIMC;
extern "imm32" fn ImmReleaseContext(?HWND, ?HIMC) callconv(.winapi) BOOL;
extern "imm32" fn ImmGetCompositionStringW(?HIMC, u32, ?*anyopaque, u32) callconv(.winapi) i32;
extern "imm32" fn ImmSetCompositionWindow(?HIMC, *const COMPOSITIONFORM) callconv(.winapi) BOOL;
extern "imm32" fn ImmSetCandidateWindow(?HIMC, *const CANDIDATEFORM) callconv(.winapi) BOOL;
extern "imm32" fn ImmGetDefaultIMEWnd(?HWND) callconv(.winapi) ?HWND;
extern "imm32" fn ImmSetOpenStatus(?HIMC, BOOL) callconv(.winapi) BOOL;

// ── Keyboard helpers ──────────────────────────────────

fn vkToKey(vk: u16, extended: bool) input.Key {
    return switch (vk) {
        VK_BACK => .backspace,
        VK_TAB => .tab,
        VK_RETURN => if (extended) .numpad_enter else .enter,
        VK_SHIFT, VK_LSHIFT => .shift_left,
        VK_RSHIFT => .shift_right,
        VK_CONTROL, VK_LCONTROL => .control_left,
        VK_RCONTROL => .control_right,
        VK_MENU, VK_LMENU => .alt_left,
        VK_RMENU => .alt_right,
        VK_PAUSE => .pause,
        VK_CAPITAL => .caps_lock,
        VK_ESCAPE => .escape,
        VK_SPACE => .space,
        VK_PRIOR => .page_up,
        VK_NEXT => .page_down,
        VK_END => .end,
        VK_HOME => .home,
        VK_LEFT => .arrow_left,
        VK_UP => .arrow_up,
        VK_RIGHT => .arrow_right,
        VK_DOWN => .arrow_down,
        VK_SNAPSHOT => .print_screen,
        VK_INSERT => .insert,
        VK_DELETE => .delete,

        // Digits 0-9 (0x30-0x39)
        0x30 => .digit_0,
        0x31 => .digit_1,
        0x32 => .digit_2,
        0x33 => .digit_3,
        0x34 => .digit_4,
        0x35 => .digit_5,
        0x36 => .digit_6,
        0x37 => .digit_7,
        0x38 => .digit_8,
        0x39 => .digit_9,

        // Letters A-Z (0x41-0x5A)
        0x41 => .key_a,
        0x42 => .key_b,
        0x43 => .key_c,
        0x44 => .key_d,
        0x45 => .key_e,
        0x46 => .key_f,
        0x47 => .key_g,
        0x48 => .key_h,
        0x49 => .key_i,
        0x4A => .key_j,
        0x4B => .key_k,
        0x4C => .key_l,
        0x4D => .key_m,
        0x4E => .key_n,
        0x4F => .key_o,
        0x50 => .key_p,
        0x51 => .key_q,
        0x52 => .key_r,
        0x53 => .key_s,
        0x54 => .key_t,
        0x55 => .key_u,
        0x56 => .key_v,
        0x57 => .key_w,
        0x58 => .key_x,
        0x59 => .key_y,
        0x5A => .key_z,

        VK_LWIN => .meta_left,
        VK_RWIN => .meta_right,
        VK_APPS => .context_menu,

        // Numpad
        VK_NUMPAD0 => .numpad_0,
        VK_NUMPAD0 + 1 => .numpad_1,
        VK_NUMPAD0 + 2 => .numpad_2,
        VK_NUMPAD0 + 3 => .numpad_3,
        VK_NUMPAD0 + 4 => .numpad_4,
        VK_NUMPAD0 + 5 => .numpad_5,
        VK_NUMPAD0 + 6 => .numpad_6,
        VK_NUMPAD0 + 7 => .numpad_7,
        VK_NUMPAD0 + 8 => .numpad_8,
        VK_NUMPAD0 + 9 => .numpad_9,
        VK_MULTIPLY => .numpad_multiply,
        VK_ADD => .numpad_add,
        VK_SEPARATOR => .numpad_separator,
        VK_SUBTRACT => .numpad_subtract,
        VK_DECIMAL => .numpad_decimal,
        VK_DIVIDE => .numpad_divide,

        // Function keys F1-F24
        VK_F1 => .f1,
        VK_F1 + 1 => .f2,
        VK_F1 + 2 => .f3,
        VK_F1 + 3 => .f4,
        VK_F1 + 4 => .f5,
        VK_F1 + 5 => .f6,
        VK_F1 + 6 => .f7,
        VK_F1 + 7 => .f8,
        VK_F1 + 8 => .f9,
        VK_F1 + 9 => .f10,
        VK_F1 + 10 => .f11,
        VK_F1 + 11 => .f12,
        VK_F1 + 12 => .f13,
        VK_F1 + 13 => .f14,
        VK_F1 + 14 => .f15,
        VK_F1 + 15 => .f16,
        VK_F1 + 16 => .f17,
        VK_F1 + 17 => .f18,
        VK_F1 + 18 => .f19,
        VK_F1 + 19 => .f20,
        VK_F1 + 20 => .f21,
        VK_F1 + 21 => .f22,
        VK_F1 + 22 => .f23,
        VK_F1 + 23 => .f24,

        VK_NUMLOCK => .num_lock,
        VK_SCROLL => .scroll_lock,

        // OEM keys (US layout mapping)
        VK_OEM_1 => .semicolon,
        VK_OEM_PLUS => .equal,
        VK_OEM_COMMA => .comma,
        VK_OEM_MINUS => .minus,
        VK_OEM_PERIOD => .period,
        VK_OEM_2 => .slash,
        VK_OEM_3 => .backquote,
        VK_OEM_4 => .bracket_left,
        VK_OEM_5 => .backslash,
        VK_OEM_6 => .bracket_right,
        VK_OEM_7 => .quote,
        VK_OEM_102 => .intl_backslash,

        else => .unidentified,
    };
}

fn getMods() input.Mods {
    return .{
        .shift = GetKeyState(VK_SHIFT) < 0,
        .ctrl = GetKeyState(VK_CONTROL) < 0,
        .alt = GetKeyState(VK_MENU) < 0,
        .super = (GetKeyState(VK_LWIN) < 0) or (GetKeyState(VK_RWIN) < 0),
        .caps_lock = (GetKeyState(VK_CAPITAL) & 1) != 0,
        .num_lock = (GetKeyState(VK_NUMLOCK) & 1) != 0,
        .sides = .{
            .shift = if (GetKeyState(VK_RSHIFT) < 0) .right else .left,
            .ctrl = if (GetKeyState(VK_RCONTROL) < 0) .right else .left,
            .alt = if (GetKeyState(VK_RMENU) < 0) .right else .left,
        },
    };
}

const TranslateResult = struct { utf8: [8]u8, len: u3, composing: bool };

fn translateKey(vk: u16, scancode: u16, kb_state: *const [256]u8) TranslateResult {
    var result: TranslateResult = .{
        .utf8 = undefined,
        .len = 0,
        .composing = false,
    };

    var utf16_buf: [4]u16 = undefined;
    const n = ToUnicode(@intCast(vk), @intCast(scancode), kb_state, &utf16_buf, 4, 0);

    if (n > 0) {
        const utf16_slice = utf16_buf[0..@intCast(n)];
        var out_idx: usize = 0;
        var it = std.unicode.Utf16LeIterator.init(utf16_slice);
        while (it.nextCodepoint() catch null) |cp| {
            const cp_len = std.unicode.utf8CodepointSequenceLength(cp) catch break;
            if (out_idx + cp_len > 8) break;
            _ = std.unicode.utf8Encode(cp, result.utf8[out_idx..][0..cp_len]) catch break;
            out_idx += cp_len;
        }
        result.len = @intCast(out_idx);
    } else if (n < 0) {
        result.composing = true;
        // Clear dead key state so it doesn't leak into next ToUnicode call.
        // We handle composition via WM_CHAR fallback if needed.
        _ = ToUnicode(@intCast(vk), @intCast(scancode), kb_state, &utf16_buf, 4, 0);
    }

    return result;
}

fn getUnshiftedCodepoint(vk: u16) u21 {
    const mapped = MapVirtualKeyW(@intCast(vk), MAPVK_VK_TO_CHAR);
    if (mapped == 0) return 0;
    // Bit 31 set means dead key — mask it off
    return @intCast(mapped & 0x7FFFFFFF);
}

// ── Mouse helpers ─────────────────────────────────────

fn mousePosFromLParam(lparam: LPARAM) apprt.CursorPos {
    const x: i16 = @truncate(lparam & 0xFFFF);
    const y: i16 = @truncate((lparam >> 16) & 0xFFFF);
    return .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
}

// HIWORD(wparam) of WM_MOUSEWHEEL/HWHEEL is a SIGNED i16 wheel delta in
// multiples of WHEEL_DELTA (120). We must @bitCast through u16 to preserve
// the sign of negative values — a naive @intCast on the unsigned u32 LO 16
// bits panics for negative deltas (e.g. 0xFF88 → 65416 doesn't fit in i16).
// Returns wheel "ticks": +1.0 per notch up/right, -1.0 per notch down/left.
fn wheelTicks(wparam: WPARAM) f64 {
    const hi: u16 = @truncate((wparam >> 16) & 0xFFFF);
    const delta: i16 = @bitCast(hi);
    return @as(f64, @floatFromInt(delta)) / 120.0;
}

test "wheelTicks: forward scroll one notch" {
    // wparam HIWORD = 120 → +1.0 ticks
    try std.testing.expectEqual(@as(f64, 1.0), wheelTicks(120 << 16));
}

test "wheelTicks: backward scroll one notch (signed handling)" {
    // wparam HIWORD = 0xFF88 (= -120 as i16) → -1.0 ticks.
    // Pre-fix code panicked here because @intCast(i16, 65416) is out of range.
    try std.testing.expectEqual(@as(f64, -1.0), wheelTicks(0xFF88 << 16));
}

test "wheelTicks: zero delta" {
    try std.testing.expectEqual(@as(f64, 0.0), wheelTicks(0));
}

test "wheelTicks: fast scroll multiple notches" {
    try std.testing.expectEqual(@as(f64, 4.0), wheelTicks(480 << 16));
    // -480 as i16 = 0xFE20
    try std.testing.expectEqual(@as(f64, -4.0), wheelTicks(0xFE20 << 16));
}

fn mouseButtonFromMsg(msg: u32) input.MouseButton {
    return switch (msg) {
        WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK => .left,
        WM_RBUTTONDOWN, WM_RBUTTONUP, WM_RBUTTONDBLCLK => .right,
        WM_MBUTTONDOWN, WM_MBUTTONUP => .middle,
        else => .unknown,
    };
}

fn mouseActionFromMsg(msg: u32) input.MouseButtonState {
    return switch (msg) {
        WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN => .press,
        WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP => .release,
        WM_LBUTTONDBLCLK, WM_RBUTTONDBLCLK => .press,
        else => .release,
    };
}

// ── Clipboard helpers ──────────────────────────────────

fn readClipboardUtf8(alloc: Allocator) !?[:0]const u8 {
    if (OpenClipboard(null) == 0) return error.ClipboardOpenFailed;
    defer _ = CloseClipboard();

    if (IsClipboardFormatAvailable(CF_UNICODETEXT) == 0) return null;

    const h_data = GetClipboardData(CF_UNICODETEXT) orelse return null;
    const p_data = GlobalLock(h_data) orelse return null;
    defer _ = GlobalUnlock(h_data);
    const size = GlobalSize(h_data);
    if (size < 2) return null;

    const utf16_ptr: [*]const u16 = @ptrCast(@alignCast(p_data));
    const utf16_len = (size / 2) -| 1; // minus null terminator
    if (utf16_len == 0) return null;
    const utf16_slice = utf16_ptr[0..utf16_len];

    // Manual UTF-16LE to UTF-8 conversion
    var result = try std.ArrayList(u8).initCapacity(alloc, utf16_len * 3);
    errdefer result.deinit(alloc);
    var it = std.unicode.Utf16LeIterator.init(utf16_slice);
    while (it.nextCodepoint() catch null) |cp| {
        var buf: [4]u8 = undefined;
        const cp_len = try std.unicode.utf8Encode(cp, &buf);
        try result.appendSlice(alloc, buf[0..cp_len]);
    }
    return try result.toOwnedSliceSentinel(alloc, 0);
}

fn utf8ToUtf16Le(alloc: Allocator, text: []const u8) ![]const u16 {
    var list = try std.ArrayList(u16).initCapacity(alloc, text.len + 1);
    errdefer list.deinit(alloc);
    var i: usize = 0;
    while (i < text.len) {
        const cp_len = try std.unicode.utf8ByteSequenceLength(text[i]);
        if (i + cp_len > text.len) break;
        const cp = try std.unicode.utf8Decode(text[i .. i + cp_len]);
        i += cp_len;
        // Encode to UTF-16LE (surrogate pairs for codepoints > 0xFFFF)
        if (cp <= 0xFFFF) {
            try list.append(alloc, @intCast(cp));
        } else if (cp <= 0x10FFFF) {
            const adjusted = cp - 0x10000;
            try list.append(alloc, @intCast(0xD800 | (adjusted >> 10)));
            try list.append(alloc, @intCast(0xDC00 | (adjusted & 0x3FF)));
        }
    }
    try list.append(alloc, 0); // null terminator
    return try list.toOwnedSlice(alloc);
}

fn writeClipboardUtf8(text: []const u8) !void {
    if (text.len == 0) return;

    const utf16 = try utf8ToUtf16Le(std.heap.page_allocator, text);
    defer std.heap.page_allocator.free(utf16);

    const data_size: usize = utf16.len * @sizeOf(u16);
    const h_mem = GlobalAlloc(GHND, data_size) orelse return error.OutOfMemory;
    var owns_h_mem = true;
    defer {
        if (owns_h_mem) _ = GlobalFree(h_mem);
    }

    const p_mem = GlobalLock(h_mem) orelse return error.OutOfMemory;
    defer _ = GlobalUnlock(h_mem);
    @memcpy(@as([*]u8, @ptrCast(p_mem))[0..data_size], @as([*]const u8, @ptrCast(utf16.ptr))[0..data_size]);

    if (OpenClipboard(null) == 0) return error.ClipboardOpenFailed;
    defer _ = CloseClipboard();
    _ = EmptyClipboard();
    if (SetClipboardData(CF_UNICODETEXT, h_mem) == null) {
        return error.ClipboardSetFailed;
    }
    // Windows now owns h_mem — don't free
    owns_h_mem = false;
}

// ── IME helpers ────────────────────────────────────────

fn readCompositionString(himc: ?HIMC, flags: u32, alloc: Allocator) ![]u8 {
    const len = ImmGetCompositionStringW(himc, flags, null, 0);
    if (len <= 0) return &[_]u8{};

    // len includes null terminator for some flags
    const byte_len: u32 = @intCast(len);
    const buf_len = if (len > 0) @as(usize, @intCast(len)) else 0;

    const utf16_buf = try alloc.alloc(u8, buf_len);
    defer alloc.free(utf16_buf);

    _ = ImmGetCompositionStringW(himc, flags, utf16_buf.ptr, byte_len);

    const utf16_slice = @as([*]const u16, @ptrCast(@alignCast(utf16_buf.ptr)))[0 .. buf_len / 2];

    var result = try std.ArrayList(u8).initCapacity(alloc, utf16_slice.len * 3);
    errdefer result.deinit(alloc);
    var it = std.unicode.Utf16LeIterator.init(utf16_slice);
    while (it.nextCodepoint() catch null) |cp| {
        var buf: [4]u8 = undefined;
        const cp_len = try std.unicode.utf8Encode(cp, &buf);
        try result.appendSlice(alloc, buf[0..cp_len]);
    }
    return try result.toOwnedSlice(alloc);
}

fn setImePosition(surface: *Surface) void {
    const hwnd = surface.app.hwnd orelse return;
    const himc = ImmGetContext(hwnd) orelse return;
    defer _ = ImmReleaseContext(hwnd, himc);

    const ime_pos = surface.core_surface.imePoint();
    const x: i32 = @intFromFloat(ime_pos.x);
    const y: i32 = @intFromFloat(ime_pos.y);

    var cf: COMPOSITIONFORM = .{
        .dwStyle = CFS_POINT | CFS_FORCE_POSITION,
        .ptCurrentPos = .{ .x = x, .y = y },
        .rcArea = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    };
    _ = ImmSetCompositionWindow(himc, &cf);

    // Position candidate window near cursor too
    var cand: CANDIDATEFORM = .{
        .dwIndex = 0,
        .dwStyle = CFS_CANDIDATEPOS,
        .ptCurrentPos = .{ .x = x, .y = y + 20 },
        .rcArea = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    };
    _ = ImmSetCandidateWindow(himc, &cand);
}

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
                a.updateTabBarHeight();
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
                const wparam_val: u32 = @intCast(wparam & 0xFFFF);
                if (wparam_val == SIZE_MINIMIZED) return 0;
                const width: u32 = @intCast(lparam & 0xFFFF);
                const height: u32 = @intCast((lparam >> 16) & 0xFFFF);
                a.updateViewport(@intCast(width), @intCast(height));
                // Notify ALL tabs of new size (guard against underflow)
                const term_height: u32 = if (height > @as(u32, @intCast(a.tab_bar_height)))
                    height - @as(u32, @intCast(a.tab_bar_height))
                else
                    1;
                for (a.tabs.items) |s| {
                    s.core_surface.sizeCallback(.{
                        .width = width,
                        .height = term_height,
                    }) catch |err| {
                        log.warn("sizeCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_SETFOCUS => {
            if (app) |a| {
                a.window_focused = true;
                // Enable IME for this window
                const himc = ImmGetContext(hwnd);
                if (himc) |h| {
                    _ = ImmSetOpenStatus(h, 1);
                    _ = ImmReleaseContext(hwnd, h);
                }
                if (a.getActiveSurface()) |s| {
                    s.core_surface.focusCallback(true) catch |err| {
                        log.warn("focusCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_KILLFOCUS => {
            if (app) |a| {
                a.window_focused = false;
                if (a.getActiveSurface()) |s| {
                    s.core_surface.focusCallback(false) catch |err| {
                        log.warn("focusCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_KEYDOWN, WM_SYSKEYDOWN => {
            if (app) |a| {
                if (a.handleKeyInput(wparam, lparam, false))
                    return 0;
            }
            return DefWindowProcW(hwnd, msg_type, wparam, lparam);
        },
        WM_KEYUP, WM_SYSKEYUP => {
            if (app) |a| {
                if (a.handleKeyInput(wparam, lparam, true))
                    return 0;
            }
            return DefWindowProcW(hwnd, msg_type, wparam, lparam);
        },
        WM_CHAR => {
            // WM_CHAR is generated by TranslateMessage for dead key composition.
            // We skip TranslateMessage for keyboard messages (see message loop),
            // so this should rarely fire. If it does, ignore it — we handle
            // text via ToUnicode in WM_KEYDOWN.
            return 0;
        },
        // ── Mouse messages ──────────────────────────────
        WM_LBUTTONDOWN => {
            if (app) |a| {
                const pos = mousePosFromLParam(lparam);
                // Check if click is in the tab bar
                if (pos.y < @as(f32, @floatFromInt(a.tab_bar_height))) {
                    // Tab bar click: switch to clicked tab
                    if (a.tabs.items.len > 1) {
                        const tab_w = @as(f32, @floatFromInt(a.viewport_width)) / @as(f32, @floatFromInt(a.tabs.items.len));
                        const clamped_w = @min(tab_w, 200.0);
                        const idx: usize = @intFromFloat(pos.x / clamped_w);
                        if (idx < a.tabs.items.len) a.switchToTab(idx);
                    }
                    return 0;
                }
                // Terminal area: offset Y and forward
                const term_pos = apprt.CursorPos{ .x = pos.x, .y = pos.y - @as(f32, @floatFromInt(a.tab_bar_height)) };
                if (a.getActiveSurface()) |s| {
                    const mods = getMods();
                    s.core_surface.cursorPosCallback(term_pos, mods) catch {};
                    _ = s.core_surface.mouseButtonCallback(.press, .left, mods) catch |err| {
                        log.warn("mouseButtonCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_LBUTTONUP, WM_LBUTTONDBLCLK, WM_MBUTTONDOWN, WM_MBUTTONUP => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    var pos = mousePosFromLParam(lparam);
                    pos.y -= @as(f32, @floatFromInt(a.tab_bar_height));
                    if (pos.y < 0) return 0;
                    const button = mouseButtonFromMsg(msg_type);
                    const action = mouseActionFromMsg(msg_type);
                    const mods = getMods();
                    s.core_surface.cursorPosCallback(pos, mods) catch {};
                    _ = s.core_surface.mouseButtonCallback(action, button, mods) catch |err| {
                        log.warn("mouseButtonCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_RBUTTONUP => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    var pos = mousePosFromLParam(lparam);
                    pos.y -= @as(f32, @floatFromInt(a.tab_bar_height));
                    if (pos.y < 0) return 0;
                    const mods = getMods();
                    s.core_surface.cursorPosCallback(pos, mods) catch {};
                    _ = s.core_surface.mouseButtonCallback(.release, .right, mods) catch |err| {
                        log.warn("mouseButtonCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_RBUTTONDOWN, WM_RBUTTONDBLCLK => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    var pos = mousePosFromLParam(lparam);
                    pos.y -= @as(f32, @floatFromInt(a.tab_bar_height));
                    if (pos.y < 0) return 0;
                    const action = mouseActionFromMsg(msg_type);
                    const mods = getMods();
                    s.core_surface.cursorPosCallback(pos, mods) catch {};
                    _ = s.core_surface.mouseButtonCallback(action, .right, mods) catch |err| {
                        log.warn("mouseButtonCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_MOUSEMOVE => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    var pos = mousePosFromLParam(lparam);
                    pos.y -= @as(f32, @floatFromInt(a.tab_bar_height));
                    if (pos.y < 0) return 0;
                    const mods = getMods();
                    s.core_surface.cursorPosCallback(pos, mods) catch |err| {
                        log.warn("cursorPosCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_MOUSEWHEEL, WM_MOUSEHWHEEL => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    const ticks = wheelTicks(wparam);
                    const xoff: f64 = if (msg_type == WM_MOUSEHWHEEL) ticks else 0.0;
                    const yoff: f64 = if (msg_type == WM_MOUSEWHEEL) ticks else 0.0;
                    s.core_surface.scrollCallback(xoff, yoff, .{}) catch |err| {
                        log.warn("scrollCallback failed: {}", .{err});
                    };
                }
            }
            return 0;
        },
        WM_IME_SETCONTEXT => {
            // When IME wants to show its UI, accept it (return 0).
            // Do NOT call DefWindowProcW — it interferes with IME window creation.
            if ((lparam & 0xC0000000) != 0) return 0; // ISC_SHOWUI flags
            return DefWindowProcW(hwnd, msg_type, wparam, lparam);
        },
        WM_IME_STARTCOMPOSITION => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    setImePosition(s);
                    s.core_surface.preeditCallback(null) catch {};
                }
            }
            return DefWindowProcW(hwnd, msg_type, wparam, lparam);
        },
        WM_IME_COMPOSITION => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    const himc = ImmGetContext(hwnd);
                    defer {
                        if (himc) |h| _ = ImmReleaseContext(hwnd, h);
                    }

                    // Read result string (final committed text)
                    if ((wparam & GCS_RESULTSTR) != 0) {
                        const result_text = readCompositionString(himc, GCS_RESULTSTR, a.core_app.alloc) catch null;
                        if (result_text) |text| {
                            defer a.core_app.alloc.free(text);
                            if (text.len > 0) {
                                // Send committed text as key events with utf8 data
                                _ = s.core_surface.keyCallback(.{
                                    .action = .press,
                                    .key = .unidentified,
                                    .mods = .{},
                                    .utf8 = text,
                                }) catch {};
                            }
                        }
                    }

                    // Read composition string (in-progress preedit)
                    if ((wparam & GCS_COMPSTR) != 0) {
                        const comp_text = readCompositionString(himc, GCS_COMPSTR, a.core_app.alloc) catch null;
                        if (comp_text) |text| {
                            defer a.core_app.alloc.free(text);
                            s.core_surface.preeditCallback(text) catch {};
                        }
                    }

                    // Update IME window position
                    if ((wparam & (GCS_COMPSTR | GCS_RESULTSTR)) != 0) {
                        setImePosition(s);
                    }
                }
            }
            return 0;
        },
        WM_IME_ENDCOMPOSITION => {
            if (app) |a| {
                if (a.getActiveSurface()) |s| {
                    s.core_surface.preeditCallback(null) catch {};
                }
            }
            return DefWindowProcW(hwnd, msg_type, wparam, lparam);
        },
        WM_APP_WAKEUP => {
            if (app) |a| {
                if (a.hwnd) |hw| _ = InvalidateRect(hw, null, 0);
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
    /// Tab bar height in pixels (scaled by DPI), 0 when single tab
    tab_bar_height: c_int,
    /// All tabs (owned Surfaces). Index matches display order.
    tabs: std.ArrayListUnmanaged(*Surface),
    /// Index into tabs for the visible/active tab
    active_tab: usize,
    /// Cached tab titles, one per tab slot (fixed capacity)
    tab_titles: std.ArrayListUnmanaged([:0]const u8),
    window_focused: bool,
    config: ?configpkg.Config,

    fn getActiveSurface(self: *App) ?*Surface {
        if (self.tabs.items.len == 0) return null;
        return self.tabs.items[self.active_tab];
    }

    fn computeTabBarHeight(dpi: u32) c_int {
        return @intFromFloat(@as(f32, @floatFromInt(dpi)) * (30.0 / 96.0));
    }

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
            .tab_bar_height = 0,
            .tabs = .empty,
            .active_tab = 0,
            .tab_titles = .empty,
            .window_focused = false,
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

        // Create initial tab
        try self.createTab(&config);
        self.updateTabBarHeight();
        self.config = config;

        _ = ShowWindow(hwnd, SW_SHOW);
        log.info("window created, DPI={}", .{self.dpi});
    }

    fn createTab(self: *App, config: *const configpkg.Config) !void {
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

        // Allocate title placeholder
        const title = try alloc.dupeZ(u8, "Ghostty");
        errdefer alloc.free(title);

        // Defocus old active tab before switching
        if (self.tabs.items.len > 0) {
            const old_idx = self.active_tab;
            if (old_idx < self.tabs.items.len) {
                self.tabs.items[old_idx].core_surface.focusCallback(false) catch {};
            }
        }

        try self.tabs.append(alloc, surface);
        try self.tab_titles.append(alloc, title);
        self.active_tab = self.tabs.items.len - 1;

        // Update tab bar AND viewport BEFORE notifying surface of size
        self.updateTabBarHeight();
        self.updateViewport(self.viewport_width, self.viewport_height);

        // Notify surface of viewport size with correct tab_bar_height
        if (self.viewport_width > 0 and self.viewport_height > self.tab_bar_height) {
            const term_height: u32 = @intCast(self.viewport_height - self.tab_bar_height);
            surface.core_surface.sizeCallback(.{
                .width = @intCast(self.viewport_width),
                .height = term_height,
            }) catch {};
        }
        if (self.window_focused) {
            surface.core_surface.focusCallback(true) catch {};
        }

        log.info("tab created, total={d}", .{self.tabs.items.len});
    }

    fn closeTab(self: *App, index: usize) void {
        if (index >= self.tabs.items.len) return;
        const alloc = self.core_app.alloc;

        // Remove from lists FIRST — before deinit/destroy triggers
        // WM_KILLFOCUS/DestroyWindow which queries getActiveSurface().
        const surface = self.tabs.items[index];
        const title = self.tab_titles.items[index];
        _ = self.tabs.orderedRemove(index);
        _ = self.tab_titles.orderedRemove(index);

        // Rebalance active_tab before surface destruction
        if (self.tabs.items.len == 0) {
            self.active_tab = 0;
        } else if (index <= self.active_tab and self.active_tab > 0) {
            self.active_tab -= 1;
        }
        if (self.active_tab >= self.tabs.items.len and self.tabs.items.len > 0) {
            self.active_tab = self.tabs.items.len - 1;
        }

        // Now safe to destroy — getActiveSurface() won't return this surface
        surface.core_surface.deinit();
        self.core_app.deleteSurface(surface);
        alloc.destroy(surface);
        alloc.free(title);

        // If last tab, close window
        if (self.tabs.items.len == 0) {
            if (self.hwnd) |hwnd| _ = DestroyWindow(hwnd);
            return;
        }

        self.updateTabBarHeight();
        // Recalculate viewport and notify remaining tabs of new size
        if (self.viewport_width > 0 and self.viewport_height > 0) {
            self.updateViewport(self.viewport_width, self.viewport_height);
            const term_height: u32 = @intCast(@max(1, self.viewport_height - self.tab_bar_height));
            for (self.tabs.items) |tab_surface| {
                tab_surface.core_surface.sizeCallback(.{
                    .width = @intCast(self.viewport_width),
                    .height = term_height,
                }) catch {};
            }
        }

        // Focus the new active tab
        if (self.window_focused) {
            if (self.getActiveSurface()) |s| {
                s.core_surface.focusCallback(true) catch {};
            }
        }
        log.info("tab closed, remaining={d}", .{self.tabs.items.len});
    }

    fn switchTab(self: *App, delta: isize) void {
        if (self.tabs.items.len < 2) return;
        const old_idx = self.active_tab;
        const new_idx = @as(isize, @intCast(self.active_tab)) + delta;
        const len: isize = @intCast(self.tabs.items.len);
        self.active_tab = @intCast(@mod(new_idx, len));
        if (self.active_tab == old_idx) return;
        self.activateTab(old_idx, self.active_tab);
    }

    fn switchToTab(self: *App, index: usize) void {
        if (index >= self.tabs.items.len or index == self.active_tab) return;
        const old_idx = self.active_tab;
        self.active_tab = index;
        self.activateTab(old_idx, self.active_tab);
    }

    fn activateTab(self: *App, old_idx: usize, new_idx: usize) void {
        // Defocus old tab
        if (old_idx < self.tabs.items.len) {
            self.tabs.items[old_idx].core_surface.focusCallback(false) catch {};
        }
        // Focus new tab and update size
        if (new_idx < self.tabs.items.len) {
            const s = self.tabs.items[new_idx];
            if (self.window_focused) {
                s.core_surface.focusCallback(true) catch {};
            }
            if (self.viewport_width > 0 and self.viewport_height > self.tab_bar_height) {
                const term_height: u32 = @intCast(self.viewport_height - self.tab_bar_height);
                s.core_surface.sizeCallback(.{
                    .width = @intCast(self.viewport_width),
                    .height = term_height,
                }) catch {};
            }
            // Update window title
            if (self.hwnd) |hwnd| {
                const title = self.tab_titles.items[new_idx];
                var buf: [256]u16 = undefined;
                const utf16_len = std.unicode.utf8ToUtf16Le(&buf, title) catch 0;
                if (utf16_len < buf.len) {
                    buf[utf16_len] = 0;
                    _ = SetWindowTextW(hwnd, buf[0..utf16_len :0]);
                }
            }
        }
        // Re-render
        if (self.hwnd) |hwnd| _ = InvalidateRect(hwnd, null, 0);
        log.info("tab switched to={d}", .{self.active_tab});
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

    fn updateTabBarHeight(self: *App) void {
        self.tab_bar_height = if (self.tabs.items.len > 1)
            App.computeTabBarHeight(self.dpi)
        else
            0;
    }

    fn updateViewport(self: *App, width: c_int, height: c_int) void {
        if (self.hglrc == null) return;
        self.viewport_width = width;
        self.viewport_height = height;
        // OpenGL viewport: bottom-left origin. (0, 0, w, term_h) fills from
        // screen bottom up to term_h, leaving screen-top tab_bar_height for GDI.
        const term_height = @max(1, height - self.tab_bar_height);
        gl.viewport(0, 0, width, term_height) catch {};
    }

    fn renderSurface(self: *App) void {
        const hdc = self.hdc orelse return;
        if (self.hglrc == null) return;

        // Draw GDI tab bar BEFORE OpenGL. GDI+GL mixing on CS_OWNDC
        // works on most drivers when GDI is drawn first.
        if (self.tabs.items.len > 1) {
            const tab_h = self.tab_bar_height;
            const w = self.viewport_width;

            // Tab bar background
            const bg_brush = win32CreateSolidBrush(0x242428);
            var bg_rect: RECT = .{ .left = 0, .top = 0, .right = w, .bottom = tab_h };
            _ = FillRect(hdc, &bg_rect, bg_brush);
            _ = DeleteObject(bg_brush);

            // Tab buttons
            const tab_count: c_int = @intCast(self.tabs.items.len);
            const tab_w: c_int = @divTrunc(w, tab_count);
            const clamped_w: c_int = @min(tab_w, 200);
            const padding: c_int = 2;

            for (self.tabs.items, 0..) |_, i| {
                const x: c_int = @as(c_int, @intCast(i)) * clamped_w + padding;
                const bw: c_int = @max(1, clamped_w - 2 * padding);
                const bh: c_int = @max(1, tab_h - 2 * padding);
                const is_active = (i == self.active_tab);
                const color: u32 = if (is_active) @as(u32, 0x333340) else @as(u32, 0x26262C);
                const brush = win32CreateSolidBrush(color);
                var rect: RECT = .{ .left = x, .top = padding, .right = x + bw, .bottom = padding + bh };
                _ = FillRect(hdc, &rect, brush);
                _ = DeleteObject(brush);
            }
        }

        // Now render terminal. Use drawFrame(false) to skip internal glClear,
        // which would wipe out the GDI tab bar (glClear ignores viewport).
        const term_h = self.viewport_height - self.tab_bar_height;
        if (self.getActiveSurface()) |s| {
            if (term_h > 0) {
                gl.viewport(0, 0, self.viewport_width, term_h) catch {};
            }
            s.core_surface.renderer.drawFrame(true) catch |err| {
                log.warn("drawFrame failed: {}", .{err});
            };
        } else {
            gl.viewport(0, 0, self.viewport_width, self.viewport_height) catch {};
            gl.clearColor(0.1, 0.1, 0.12, 1.0);
            gl.clear(gl.c.GL_COLOR_BUFFER_BIT);
        }

        _ = SwapBuffers(hdc);
    }

    fn handleKeyInput(self: *App, wparam: WPARAM, lparam: LPARAM, is_release: bool) bool {
        const s = self.getActiveSurface() orelse return false;

        const vk: u16 = @intCast(wparam & 0xFFFF);
        const scancode: u16 = @intCast((lparam >> 16) & 0xFF);
        const extended = ((lparam >> 24) & 1) != 0;
        const was_down = ((lparam >> 30) & 1) != 0;

        const key = vkToKey(vk, extended);
        const mods = getMods();

        // Tab shortcuts (press only)
        if (!is_release and mods.ctrl and !mods.alt and !mods.super) {
            if (mods.shift) {
                if (key == .key_t) { if (self.config) |*c| self.createTab(c) catch {}; return true; }
                if (key == .key_w) { self.closeTab(self.active_tab); return true; }
            }
            if (key == .tab) {
                if (mods.shift) self.switchTab(-1) else self.switchTab(1);
                return true;
            }
            // Ctrl+1..9 to jump to tab
            inline for (.{ .digit_1, .digit_2, .digit_3, .digit_4, .digit_5, .digit_6, .digit_7, .digit_8, .digit_9 }, 0..) |digit_key, idx| {
                if (key == digit_key) { self.switchToTab(idx); return true; }
            }
        }

        if (is_release) {
            const effect = s.core_surface.keyCallback(.{
                .action = .release,
                .key = key,
                .mods = mods,
            }) catch |err| {
                log.warn("keyCallback failed: {}", .{err});
                return false;
            };
            return effect != .ignored;
        }

        const action: input.Action = if (was_down) .repeat else .press;

        var kb_state: [256]u8 = undefined;
        _ = GetKeyboardState(&kb_state);

        const translation = translateKey(vk, scancode, &kb_state);
        const unshifted_cp = getUnshiftedCodepoint(vk);

        var consumed_mods: input.Mods = .{};
        if (translation.len > 0 and mods.shift) {
            consumed_mods.shift = true;
        }

        const effect = s.core_surface.keyCallback(.{
            .action = action,
            .key = key,
            .mods = mods,
            .consumed_mods = consumed_mods,
            .composing = translation.composing,
            .utf8 = translation.utf8[0..translation.len],
            .unshifted_codepoint = unshifted_cp,
        }) catch |err| {
            log.warn("keyCallback failed: {}", .{err});
            return false;
        };

        return effect != .ignored;
    }

    pub fn run(self: *App) !void {
        var msg: MSG = std.mem.zeroes(MSG);
        while (true) {
            const ret = GetMessageW(&msg, null, 0, 0);
            if (ret == 0) break;
            if (ret < 0) return error.GetMessageFailed;

            // Skip TranslateMessage for keyboard messages to avoid
            // interfering with our ToUnicode-based text input in WM_KEYDOWN.
            if (msg.message < WM_KEYFIRST or msg.message > WM_KEYLAST) {
                _ = TranslateMessage(&msg);
            }
            _ = DispatchMessageW(&msg);

            self.core_app.tick(self) catch |err| {
                log.err("core tick failed: {}", .{err});
            };
        }
    }

    pub fn terminate(self: *App) void {
        const alloc = self.core_app.alloc;
        for (self.tabs.items) |s| {
            s.core_surface.deinit();
            alloc.destroy(s);
        }
        for (self.tab_titles.items) |title| alloc.free(title);
        self.tabs.deinit(alloc);
        self.tab_titles.deinit(alloc);
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
            .set_title => {
                switch (target) {
                    .app => {},
                    .surface => |surface_ptr| {
                        if (value.title.len > 0) {
                            // Cache title for the tab
                            for (self.tabs.items, 0..) |tab_surface, i| {
                                if (@intFromPtr(tab_surface) == @intFromPtr(surface_ptr)) {
                                    const old_title = self.tab_titles.items[i];
                                    self.tab_titles.items[i] = self.core_app.alloc.dupeZ(u8, value.title) catch value.title;
                                    if (old_title.len > 0) self.core_app.alloc.free(old_title);
                                    // Update window title if this is the active tab
                                    if (i == self.active_tab) {
                                        if (self.hwnd) |hwnd| {
                                            var buf: [256]u16 = undefined;
                                            const utf16_len = std.unicode.utf8ToUtf16Le(&buf, value.title) catch 0;
                                            if (utf16_len < buf.len) {
                                                buf[utf16_len] = 0;
                                                _ = SetWindowTextW(hwnd, buf[0..utf16_len :0]);
                                            }
                                        }
                                    }
                                    break;
                                }
                            }
                        }
                    },
                }
                return true;
            },
            .close_window => {
                if (self.hwnd) |hwnd| _ = DestroyWindow(hwnd);
                return true;
            },
            .close_tab => {
                switch (target) {
                    .app => {},
                    .surface => |surface_ptr| {
                        for (self.tabs.items, 0..) |tab_surface, i| {
                            if (@intFromPtr(tab_surface) == @intFromPtr(surface_ptr)) {
                                self.closeTab(i);
                                break;
                            }
                        }
                    },
                }
                return true;
            },
            .quit_timer => {
                switch (value) {
                    .start => {
                        if (self.hwnd) |hwnd| _ = DestroyWindow(hwnd);
                    },
                    .stop => {},
                }
                return true;
            },
            .show_child_exited => {
                switch (target) {
                    .app => {
                        if (self.hwnd) |hwnd| _ = DestroyWindow(hwnd);
                    },
                    .surface => |surface_ptr| {
                        for (self.tabs.items, 0..) |tab_surface, i| {
                            if (@intFromPtr(tab_surface) == @intFromPtr(surface_ptr)) {
                                self.closeTab(i);
                                break;
                            }
                        }
                    },
                }
                return true;
            },
            .size_limit,
            .cell_size,
            .initial_size,
            .mouse_shape,
            .mouse_visibility,
            .renderer_health,
            => return false,
            else => {
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
        return clipboard == .standard;
    }

    pub fn clipboardRequest(
        self: *Surface,
        clipboard: apprt.Clipboard,
        request: apprt.ClipboardRequest,
    ) !bool {
        if (clipboard != .standard) return false;

        const alloc = self.app.core_app.alloc;
        const text = readClipboardUtf8(alloc) catch |err| {
            log.warn("clipboard read failed: {}", .{err});
            return false;
        } orelse return false;
        defer alloc.free(text);

        self.core_surface.completeClipboardRequest(request, text, true) catch |err| {
            log.warn("completeClipboardRequest failed: {}", .{err});
            return false;
        };
        return true;
    }

    pub fn setClipboard(
        self: *Surface,
        clipboard: apprt.Clipboard,
        contents: []const apprt.ClipboardContent,
        confirm: bool,
    ) !void {
        _ = self;
        if (clipboard != .standard) return;
        for (contents) |c| {
            if (std.mem.eql(u8, c.mime, "text/plain")) {
                writeClipboardUtf8(c.data) catch |err| {
                    log.warn("clipboard write failed: {}", .{err});
                };
                return;
            }
        }
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
