package flightsim

import "core:fmt"
import win32 "core:sys/windows"
import d3d "vendor:directx/d3d11"
import "vendor:directx/dxgi"

window_width  :: 1280
window_height :: 720

global_running := true

main :: proc() 
{

        hr: win32.HRESULT
        window: win32.HWND

        //
        // Register a window class and create a window.
        //
        {
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
                window_style    := win32.DWORD(win32.WS_OVERLAPPED | win32.WS_CAPTION | win32.WS_SYSMENU | win32.WS_MINIMIZEBOX | win32.WS_CLIPCHILDREN | win32.WS_CLIPSIBLINGS)

                rect := win32.RECT{}
                rect.left   = 0
                rect.right  = window_width
                rect.top    = 0
                rect.bottom = window_height
                win32.AdjustWindowRectEx(&rect, window_style, false, window_style_ex)

                window = win32.CreateWindowExW(window_style_ex, window_class.lpszClassName, win32.L("Flight Sim"),
                                               window_style, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT,
                                               rect.right - rect.left,
                                               rect.bottom - rect.top,
                                               nil, nil, hinstance, nil)
                if window == nil {
                        panic("Failed to create a window.")
                }
        }

        device: ^d3d.IDevice
        imm_context: ^d3d.IDeviceContext
        swapchain: ^dxgi.ISwapChain1
        render_target_view: ^d3d.IRenderTargetView
        depth_stencil_view: ^d3d.IDepthStencilView

        //
        // Init D3D11
        //
        {
                // Create factory.
                factory: ^dxgi.IFactory7
                hr = dxgi.CreateDXGIFactory2(dxgi.CREATE_FACTORY{}, dxgi.IFactory7_UUID, (^rawptr)(&factory))
                if hr != win32.S_OK {
                        panic("Failed to create a DXGIFactory7.")
                }

                // Select a suitable adapter.
                adapter: ^dxgi.IAdapter4
                hr = factory.EnumAdapterByGpuPreference(factory, 0, .HIGH_PERFORMANCE, dxgi.IAdapter4_UUID, (^rawptr)(&adapter))
                if hr != win32.S_OK {
                        panic("No suitable adapter found.")
                }

                // Get description and print it out.
                desc: dxgi.ADAPTER_DESC3
                adapter.GetDesc3(adapter, &desc)
                fmt.printfln("Selected adapter %s.", desc.Description[:])

                // Create device.
                feature_levels := [?]d3d.FEATURE_LEVEL{._11_1}
                device_flags := d3d.CREATE_DEVICE_FLAGS{.SINGLETHREADED}
                when ODIN_DEBUG {
                        device_flags |= {.DEBUG}
                }

                feature_level: d3d.FEATURE_LEVEL
                hr = d3d.CreateDevice(adapter, .UNKNOWN, nil, device_flags, &feature_levels[0], len(feature_levels),
                                      d3d.SDK_VERSION, &device, &feature_level, &imm_context)
                if hr != win32.S_OK || feature_level != ._11_1 {
                        panic("Failed to create the desired device.")
                }

                // Create swapchain.
                swapchain_desc := dxgi.SWAP_CHAIN_DESC1{}
                swapchain_desc.Width  = 0
                swapchain_desc.Height = 0
                swapchain_desc.Format = .R8G8B8A8_UNORM
                swapchain_desc.SampleDesc = dxgi.SAMPLE_DESC{1, 0}
                swapchain_desc.BufferUsage = {.RENDER_TARGET_OUTPUT}
                swapchain_desc.BufferCount = 2
                swapchain_desc.SwapEffect = .FLIP_SEQUENTIAL
                swapchain_desc.Flags = {.ALLOW_TEARING} // for disabling vsync
                swapchain_fullscreen_desc := dxgi.SWAP_CHAIN_FULLSCREEN_DESC{Windowed = win32.TRUE}
                hr = factory.CreateSwapChainForHwnd(factory, device, window, &swapchain_desc, &swapchain_fullscreen_desc, nil, &swapchain)
                if hr != win32.S_OK {
                        panic("Failed to create a swapchain for the specified window.")
                }

                // Validate swapchain width and height.
                swapchain.GetDesc1(swapchain, &swapchain_desc)
                assert(swapchain_desc.Width == window_width && swapchain_desc.Height == window_height)

                // Get backbuffer and create a render target view
                backbuffer: ^d3d.ITexture2D
                hr = swapchain.GetBuffer(swapchain, 0, d3d.ITexture2D_UUID, (^rawptr)(&backbuffer))
                if hr != win32.S_OK {
                        panic("Failed to get the backbuffer texture from the swap chain.")
                }

                hr = device.CreateRenderTargetView(device, backbuffer, nil, &render_target_view)
                backbuffer.Release(backbuffer)
                if hr != win32.S_OK {
                        panic("Failed to create a render target view of the backbuffer.")
                }

                // Create the depth and stencil buffer and 
                depth_buffer_desc := d3d.TEXTURE2D_DESC{}
                depth_buffer_desc.Width = swapchain_desc.Width
                depth_buffer_desc.Height = swapchain_desc.Height
                depth_buffer_desc.MipLevels = 1
                depth_buffer_desc.ArraySize = 1
                depth_buffer_desc.Format = .D24_UNORM_S8_UINT
                depth_buffer_desc.SampleDesc = dxgi.SAMPLE_DESC{1, 0}
                depth_buffer_desc.Usage = .DEFAULT
                depth_buffer_desc.BindFlags = {.DEPTH_STENCIL}
                depth_buffer_desc.CPUAccessFlags = {}
                depth_buffer_desc.MiscFlags = {}
                depth_stencil_buffer: ^d3d.ITexture2D
                hr = device.CreateTexture2D(device, &depth_buffer_desc, nil, &depth_stencil_buffer)
                if hr != win32.S_OK {
                        panic("Failed to create the depth/stencil buffer.")
                }

                // create and set the depth stencil state
                depth_stencil_state_desc := d3d.DEPTH_STENCIL_DESC{}
                depth_stencil_state_desc.DepthEnable = win32.TRUE
                depth_stencil_state_desc.DepthWriteMask = .ALL
                depth_stencil_state_desc.DepthFunc = .LESS

                depth_stencil_state_desc.StencilEnable = win32.TRUE
                depth_stencil_state_desc.StencilReadMask = 0xFF
                depth_stencil_state_desc.StencilWriteMask = 0xFF

                depth_stencil_state_desc.FrontFace.StencilFailOp = .KEEP
                depth_stencil_state_desc.FrontFace.StencilDepthFailOp = .INCR
                depth_stencil_state_desc.FrontFace.StencilPassOp = .KEEP
                depth_stencil_state_desc.FrontFace.StencilFunc = .ALWAYS

                depth_stencil_state_desc.BackFace.StencilFailOp = .KEEP
                depth_stencil_state_desc.BackFace.StencilDepthFailOp = .DECR
                depth_stencil_state_desc.BackFace.StencilPassOp = .KEEP
                depth_stencil_state_desc.BackFace.StencilFunc = .ALWAYS
                depth_stencil_state: ^d3d.IDepthStencilState
                hr = device.CreateDepthStencilState(device, &depth_stencil_state_desc, &depth_stencil_state)
                if hr != win32.S_OK {
                        panic("Failed to create a depth stencil state.")
                }
                imm_context.OMSetDepthStencilState(imm_context, depth_stencil_state, 1)

                // create the depth stencil view
                depth_stencil_view_desc := d3d.DEPTH_STENCIL_VIEW_DESC{}
                depth_stencil_view_desc.Format = depth_buffer_desc.Format
                depth_stencil_view_desc.ViewDimension = .TEXTURE2D
                depth_stencil_view_desc.Flags = {}
                depth_stencil_view_desc.Texture2D.MipSlice = 0
                hr = device.CreateDepthStencilView(device, depth_stencil_buffer, &depth_stencil_view_desc, &depth_stencil_view)
                if hr != win32.S_OK {
                        panic("Failed to create a depth stencil view.")
                }

                // create a rasterizer state for increased customization options
                rasterizer_desc := d3d.RASTERIZER_DESC{}
                rasterizer_desc.FillMode = .WIREFRAME // .WIREFRAME or .SOLID
                rasterizer_desc.CullMode = .FRONT // .NONE or .FRONT or .BACK
                rasterizer_desc.FrontCounterClockwise = win32.FALSE
                rasterizer_desc.DepthBias = 0
                rasterizer_desc.DepthBiasClamp = 0.0
                rasterizer_desc.SlopeScaledDepthBias = 0.0
                rasterizer_desc.DepthClipEnable = win32.TRUE
                rasterizer_desc.ScissorEnable = win32.FALSE
                rasterizer_desc.MultisampleEnable = win32.FALSE
                rasterizer_desc.AntialiasedLineEnable = win32.FALSE
                rasterizer_state: ^d3d.IRasterizerState
                hr = device.CreateRasterizerState(device, &rasterizer_desc, &rasterizer_state)    
                if hr != win32.S_OK {
                        panic("Failed to create a depth stencil view.")
                }

                imm_context.RSSetState(imm_context, rasterizer_state)
        }
        
        //
        // Main loop set up
        //
        delta_time: f32 = 0.0
        performance_frequency, counter_now, counter_last: win32.LARGE_INTEGER = {}, {}, {}
        win32.QueryPerformanceFrequency(&performance_frequency)
        win32.QueryPerformanceCounter(&counter_last)
        win32.ShowWindow(window, win32.SW_SHOWNORMAL)

        present_flags := dxgi.PRESENT{}
        when ODIN_DEBUG {
                present_flags |= {.ALLOW_TEARING} // for disabling vsync
        }
        
        cube, success := load_model("..\\res\\cube.obj")
        assert(success, "Failed to load model.")
        _ = cube

        //
        // Main Loop
        //
        for global_running {
                // Calculate delta time
                counter_last = counter_now
                win32.QueryPerformanceCounter(&counter_now)
                delta_time = f32(counter_now - counter_last) / f32(performance_frequency)
                
                // Process win32 messages
                message := win32.MSG{}
                for win32.PeekMessageW(&message, nil, 0, 0, win32.PM_REMOVE) {
                        win32.TranslateMessage(&message)
                        win32.DispatchMessageW(&message)
                }

                // Rendering
                ClientRect: win32.RECT
                win32.GetClientRect(window, &ClientRect)
                viewport := d3d.VIEWPORT{TopLeftX = 0.0, TopLeftY = 0.0,
                                         Width  = cast(f32)(ClientRect.right - ClientRect.left),
                                         Height = cast(f32)(ClientRect.bottom - ClientRect.top),
                                         MinDepth = 0.0, MaxDepth = 1.0}
                imm_context.RSSetViewports(imm_context, 1, &viewport)
                imm_context.OMSetRenderTargets(imm_context, 1, &render_target_view, depth_stencil_view)

                clear_color := [?]f32{0.2, 0.2, 0.3, 1.0}
                imm_context.ClearRenderTargetView(imm_context, render_target_view, &clear_color)
                imm_context.ClearDepthStencilView(imm_context, depth_stencil_view, {.DEPTH, .STENCIL}, 1.0, 0)

                hr = swapchain.Present(swapchain, 0, present_flags) // 0 & .ALLOW_TEARING = no vsync
                assert(hr == win32.S_OK)
        }

        win32.ExitProcess(0)
}

main_window_proc :: proc "stdcall" (hwnd: win32.HWND, msg: u32, wparam: win32.WPARAM, lparam: win32.LPARAM) -> int 
{
        switch msg {
        case win32.WM_DESTROY, win32.WM_CLOSE, win32.WM_QUIT:
                global_running = false
                return 0
                
        case win32.WM_KEYDOWN, win32.WM_SYSKEYDOWN, win32.WM_KEYUP, win32.WM_SYSKEYUP: 
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
