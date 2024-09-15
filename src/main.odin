package flightsim

import win32 "core:sys/windows"
import d3d "vendor:directx/d3d11"
import "vendor:directx/dxgi"

window_width  :: 1280
window_height :: 720

global_running := true

main :: proc() {
    hinstance := win32.HINSTANCE(win32.GetModuleHandleW(nil))

    window_class := win32.WNDCLASSW{}
    window_class.style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC
    window_class.lpfnWndProc = main_window_proc
    window_class.hInstance = hinstance
    window_class.hCursor = win32.LoadCursorW(nil, win32.MAKEINTRESOURCEW(32512))
    window_class.lpszClassName = win32.L("CustomWindowClass")
    // TODO: WindowClass.hIcon

    if win32.RegisterClassW(&window_class) == 0 {
        panic("Failed to register the window class.")
    }

    window_style    := win32.DWORD(win32.WS_OVERLAPPED | win32.WS_CAPTION | win32.WS_SYSMENU | win32.WS_MINIMIZEBOX)
    window_style_ex := win32.DWORD(0)

    rect := win32.RECT{}
    rect.left   = 0
    rect.right  = window_width
    rect.top    = 0
    rect.bottom = window_height
    win32.AdjustWindowRectEx(&rect, window_style, false, window_style_ex)

    window := win32.CreateWindowExW(window_style_ex, window_class.lpszClassName, win32.L("Flight Sim"),
                                    window_style, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT,
                                    rect.right - rect.left,
                                    rect.bottom - rect.top,
                                    nil, nil, hinstance, nil)

    if window == nil {
        panic("Failed to create a window.")
    }

    // Init D3D11
    
    adapter := dxgi.IAdapter{}
    for i: u32 = 0; d3d.EnumAdapters(i, &adapter) != d3d.DXGI_ERROR_NOT_FOUND; i += 1 {
        
    }
    
    // device := dx11.CreateDevice(
    
    win32.ShowWindow(window, win32.SW_SHOWNORMAL)

    // Game Loop
    for global_running {
        process_messages()
    }

    win32.ExitProcess(0)
}

main_window_proc :: proc "stdcall" (hwnd: win32.HWND, msg: u32, wparam: win32.WPARAM, lparam: win32.LPARAM) -> int {
    switch msg {
    case win32.WM_DESTROY: fallthrough
    case win32.WM_CLOSE: fallthrough
    case win32.WM_QUIT:
        global_running = false
        return 0
        
    case win32.WM_KEYDOWN: fallthrough
    case win32.WM_SYSKEYDOWN: fallthrough
    case win32.WM_KEYUP: fallthrough
    case win32.WM_SYSKEYUP:
	key := win32.LOWORD(wparam)
	
	was_down := (lparam & (1 << 30)) != 0
	down := (lparam & (1 << 31)) == 0
	
	if was_down != down {
	    alt_down := (lparam & (1 << 29)) != 0
	    
	    if key == win32.VK_F11 && down {
		// toggle_fullscreen(window);
	    }
	    
	    if key == win32.VK_F4 && alt_down && down {
		global_running = false
	    }
	    
	    // key_event(key, down);
	}
	
	break
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
