package flightsim

import win32 "core:sys/windows"

@(private="file")
global_running := true
@(private="file")
global_window_has_focus := false

Window :: win32.HWND
Point :: win32.POINT
Rect :: win32.RECT

create_window :: proc(width, height: i32, title: string) -> (Window, bool) {
        hinstance := win32.HINSTANCE(win32.GetModuleHandleW(nil))

        window_class := win32.WNDCLASSW{}
        window_class.style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC
        window_class.lpfnWndProc = main_window_proc
        window_class.hInstance = hinstance
        window_class.hCursor = win32.LoadCursorW(nil, ([^]u16)(rawptr(win32.IDC_ARROW)))
        window_class.lpszClassName = win32.L("CustomWindowClass")

        if win32.RegisterClassW(&window_class) == 0 {
                panic("Failed to register the window class.")
        }
        
        window_style_ex := win32.DWORD(0)
        window_style    := win32.DWORD(
                win32.WS_OVERLAPPED | 
                win32.WS_CAPTION | 
                win32.WS_SYSMENU | 
                win32.WS_MINIMIZEBOX | 
                win32.WS_CLIPCHILDREN | 
                win32.WS_CLIPSIBLINGS)

        rect := win32.RECT{}
        rect.left   = 0
        rect.right  = width
        rect.top    = 0
        rect.bottom = height
        win32.AdjustWindowRectEx(&rect, window_style, false, window_style_ex)

        window := win32.CreateWindowExW(
                window_style_ex, 
                window_class.lpszClassName, 
                win32.utf8_to_wstring(title),
                window_style, 
                win32.CW_USEDEFAULT, 
                win32.CW_USEDEFAULT,
                rect.right - rect.left,
                rect.bottom - rect.top,
                nil, 
                nil, 
                hinstance, 
                nil)

        return window, window != nil
}

main_window_proc :: proc "stdcall" (hwnd: win32.HWND, msg: u32, wparam: win32.WPARAM, lparam: win32.LPARAM) -> int {
        switch msg {
        case win32.WM_ACTIVATEAPP:
                clear_keyboard_state()
                // wparam == win32.TRUE:  window activated 
                // wparam == win32.FALSE: window deactivated
                global_window_has_focus = cast(win32.BOOL)wparam == win32.TRUE
                win32.ShowCursor(global_window_has_focus == false)
                return 0

        case win32.WM_DESTROY, win32.WM_CLOSE, win32.WM_QUIT:
                global_running = false
                return 0
                
        case win32.WM_KEYDOWN, win32.WM_SYSKEYDOWN, win32.WM_KEYUP, win32.WM_SYSKEYUP: 
                key := cast(rune)win32.LOWORD(wparam)
                
                was_down: bool = (lparam & (1 << 30)) != 0
                down: bool = (lparam & (1 << 31)) == 0
                
                if was_down != down {
                        alt_down := (lparam & (1 << 29)) != 0
                        
                        if key == win32.VK_F11 && down {
                                // toggle_fullscreen(window);
                        }
                        
                        if key == win32.VK_F4 && alt_down && down {
                                global_running = false
                        }
                        
                        key_event(key, down)
                }

                return 0
        }
        
        return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
}

process_messages :: proc() {
        message := win32.MSG{}
        for win32.PeekMessageW(&message, nil, 0, 0, win32.PM_REMOVE) {
                win32.TranslateMessage(&message)
                win32.DispatchMessageW(&message)
        }
}

show_window :: proc(window: Window) {
        win32.ShowWindow(window, win32.SW_SHOWNORMAL)
}

is_running :: proc() -> bool {
        return global_running
}

window_has_focus :: proc() -> bool {
        return global_window_has_focus
}

get_cursor_pos :: proc() -> Point {
        cursor_pos := win32.POINT{}
        win32.GetCursorPos(&cursor_pos)
        return cursor_pos
}

get_window_rect :: proc(window: Window) -> Rect {
        window_rect := win32.RECT{}
        win32.GetWindowRect(window, &window_rect)
        return window_rect
}

set_cursor_pos :: proc(x, y: i32) {
        win32.SetCursorPos(x, y)
}

get_client_rect :: proc(window: Window) -> Rect {
        client_rect := win32.RECT{}
        win32.GetClientRect(window, &client_rect)
        return client_rect
}
