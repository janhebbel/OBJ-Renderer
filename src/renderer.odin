package flightsim

import d3d "vendor:directx/d3d11"
import dxgi "vendor:directx/dxgi"
import "core:fmt"
import "core:os"
import "base:runtime"

// enable max frame rate
when ODIN_DEBUG {
        present_flags :: dxgi.PRESENT{.ALLOW_TEARING}
} else {
        present_flags :: dxgi.PRESENT{}
}

Direct_3D :: struct {
        device: ^d3d.IDevice,
        dcontext: ^d3d.IDeviceContext,
        swapchain: ^dxgi.ISwapChain1,
        render_target_view: ^d3d.IRenderTargetView,
        depth_stencil_view: ^d3d.IDepthStencilView,
}

Vertex :: struct {
        position: [4]f32,
        uv: [2]f32,
        normal: [3]f32,
}

Render_Group :: struct {
        vertex_array: [dynamic]Vertex,
        index_array: [dynamic]u32,

        input_layout: ^d3d.IInputLayout,
        vertex_shader: ^d3d.IVertexShader,
        pixel_shader: ^d3d.IPixelShader,
        vertex_buffer: ^d3d.IBuffer,
        index_buffer: ^d3d.IBuffer,
        constant_buffer: ^d3d.IBuffer,
        // sampler_state: ^d3d.ISamplerState,
        // texture_view: ^d3d.IShaderResourceView,
}

VS_Constant_Buffer :: struct {
        model: float4x4,
        view:  float4x4,
        proj:  float4x4,
}

// TODO: Release things that would leak here.
renderer_init :: proc(window: Window) -> (direct_3d: Direct_3D, err: bool) {
        hr: d3d.HRESULT

        // Create factory.
        factory: ^dxgi.IFactory7
        hr = dxgi.CreateDXGIFactory2(dxgi.CREATE_FACTORY{}, dxgi.IFactory7_UUID, (^rawptr)(&factory))
        if hr != 0 {
                fmt.println("Failed to create a DXGIFactory7.")
                return
        }

        // Select a suitable adapter.
        adapter: ^dxgi.IAdapter4
        hr = factory.EnumAdapterByGpuPreference(factory, 0, .HIGH_PERFORMANCE, dxgi.IAdapter4_UUID, (^rawptr)(&adapter))
        if hr != 0 {
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

        device: ^d3d.IDevice
        imm_context: ^d3d.IDeviceContext
        hr = d3d.CreateDevice(adapter, .UNKNOWN, nil, device_flags, &feature_levels[0], len(feature_levels),
                              d3d.SDK_VERSION, &device, &feature_level, &imm_context)
        if hr != 0 || feature_level != ._11_1 {
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
        swapchain_fullscreen_desc := dxgi.SWAP_CHAIN_FULLSCREEN_DESC{Windowed = true}

        swapchain: ^dxgi.ISwapChain1
        hr = factory.CreateSwapChainForHwnd(factory, device, window, &swapchain_desc, &swapchain_fullscreen_desc, nil, &swapchain)
        if hr != 0 {
                panic("Failed to create a swapchain for the specified window.")
        }

        // Validate swapchain width and height.
        swapchain.GetDesc1(swapchain, &swapchain_desc)
        window_dimensions := get_client_rect(window)
        assert(swapchain_desc.Width == (u32)(window_dimensions.right) && swapchain_desc.Height == (u32)(window_dimensions.bottom))

        // Get backbuffer and create a render target view
        backbuffer: ^d3d.ITexture2D
        hr = swapchain.GetBuffer(swapchain, 0, d3d.ITexture2D_UUID, (^rawptr)(&backbuffer))
        if hr != 0 {
                panic("Failed to get the backbuffer texture from the swap chain.")
        }

        render_target_view: ^d3d.IRenderTargetView
        hr = device.CreateRenderTargetView(device, backbuffer, nil, &render_target_view)
        backbuffer.Release(backbuffer)
        if hr != 0 {
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
        if hr != 0 {
                panic("Failed to create the depth/stencil buffer.")
        }

        // create and set the depth stencil state
        depth_stencil_state_desc := d3d.DEPTH_STENCIL_DESC{}
        depth_stencil_state_desc.DepthEnable = true
        depth_stencil_state_desc.DepthWriteMask = .ALL
        depth_stencil_state_desc.DepthFunc = .LESS

        depth_stencil_state_desc.StencilEnable = true
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
        if hr != 0 {
                panic("Failed to create a depth stencil state.")
        }
        imm_context.OMSetDepthStencilState(imm_context, depth_stencil_state, 1)

        // create the depth stencil view
        depth_stencil_view_desc := d3d.DEPTH_STENCIL_VIEW_DESC{}
        depth_stencil_view_desc.Format = depth_buffer_desc.Format
        depth_stencil_view_desc.ViewDimension = .TEXTURE2D
        depth_stencil_view_desc.Flags = {}
        depth_stencil_view_desc.Texture2D.MipSlice = 0

        depth_stencil_view: ^d3d.IDepthStencilView
        hr = device.CreateDepthStencilView(device, depth_stencil_buffer, &depth_stencil_view_desc, &depth_stencil_view)
        if hr != 0 {
                panic("Failed to create a depth stencil view.")
        }

        // create a rasterizer state for increased customization options
        rasterizer_desc := d3d.RASTERIZER_DESC{}
        rasterizer_desc.FillMode = .WIREFRAME // .WIREFRAME or .SOLID
        rasterizer_desc.CullMode = .BACK // .NONE or .FRONT or .BACK
        rasterizer_desc.FrontCounterClockwise = false
        rasterizer_desc.DepthBias = 0
        rasterizer_desc.DepthBiasClamp = 0.0
        rasterizer_desc.SlopeScaledDepthBias = 0.0
        rasterizer_desc.DepthClipEnable = true
        rasterizer_desc.ScissorEnable = false
        rasterizer_desc.MultisampleEnable = false
        rasterizer_desc.AntialiasedLineEnable = false
        rasterizer_state: ^d3d.IRasterizerState
        hr = device.CreateRasterizerState(device, &rasterizer_desc, &rasterizer_state)    
        if hr != 0 {
                panic("Failed to create a depth stencil view.")
        }

        imm_context.RSSetState(imm_context, rasterizer_state)

        // Create sampler object
        // sampler_desc := d3d.SAMPLER_DESC{}
        // sampler_desc.Filter = .MIN_MAG_MIP_LINEAR
        // sampler_desc.AddressU = .WRAP
        // sampler_desc.AddressV = .WRAP
        // sampler_desc.AddressW = .WRAP
        // hr = device.CreateSamplerState(device, &sampler_desc, &sampler_state)
        // if hr != 0 {
        //         panic("Failed to create a sampler state.")
        // }

        // Create texture
        // texture_desc := d3d.TEXTURE2D_DESC{}
        // texture: ^d3d.ITexture2D
        // hr = device.CreateTexture2D(device, &texture_desc, nil, &texture)
        // hr = device.CreateShaderResourceView(device, 

        direct_3d.device = device
        direct_3d.dcontext = imm_context
        direct_3d.swapchain = swapchain
        direct_3d.render_target_view = render_target_view
        direct_3d.depth_stencil_view = depth_stencil_view

        return direct_3d, true
}

make_render_group :: proc(filename: string, direct_3d: ^Direct_3D) -> (rg: Render_Group, success: bool) {
        data: []u8
        data, success = os.read_entire_file(filename)
        if !success {
                fmt.println("Failed to read file", filename)
                return rg, false
        }
        defer delete(data)

        success = parse_obj(data, &rg.vertex_array, &rg.index_array)
        if !success {
                fmt.println("Failed to parse obj file.")
                return rg, false
        }
        defer delete(rg.vertex_array)
        defer delete(rg.index_array)

        device := direct_3d.device

        // Load compiled shader objects and create vertex and pixel shader
        vs_data, vs_success := os.read_entire_file("default_vertex.cso")
        if !vs_success {
                panic("Failed to read default_vertex.cso!")
        }
        defer delete(vs_data)

        hr: d3d.HRESULT = device.CreateVertexShader(device, cast(rawptr)&vs_data[0], len(vs_data), nil, &rg.vertex_shader)
        if hr != 0 {
                panic("Failed to create a vertex shader.")
        }
        
        ps_data, ps_success := os.read_entire_file("default_pixel.cso")
        if !ps_success {
                panic("Failed to read default_pixel.cso!")
        }
        defer delete(ps_data)

        hr = device.CreatePixelShader(device, cast(rawptr)&ps_data[0], len(ps_data), nil, &rg.pixel_shader)
        if hr != 0 {
                panic("Failed to create a vertex shader.")
        }

        // Create input layout
        input_element_descs := [?]d3d.INPUT_ELEMENT_DESC{
                {"POSITION", 0, .R32G32B32A32_FLOAT, 0, 0, .VERTEX_DATA, 0},
                {"TEXCOORD", 0, .R32G32_FLOAT, 0, d3d.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA, 0},
                {"NORMAL", 0, .R32G32B32_FLOAT, 0, d3d.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA, 0},
        }

        hr = device.CreateInputLayout(device, cast(^d3d.INPUT_ELEMENT_DESC)&input_element_descs, 
                                      cast(u32)len(input_element_descs), (rawptr)(&vs_data[0]), len(vs_data), 
                                      &rg.input_layout)
        if hr != 0 {
                panic("Failed to create an input layout.")
        }

        // Create vertex buffer
        vertex_buffer_desc := d3d.BUFFER_DESC{
                Usage = .DEFAULT,
                ByteWidth = cast(u32)len(rg.vertex_array) * size_of(Vertex),
                BindFlags = {.VERTEX_BUFFER},
                CPUAccessFlags = {},
                MiscFlags = {},
        }

        vertex_data := d3d.SUBRESOURCE_DATA{
                pSysMem = raw_data(rg.vertex_array),
                SysMemPitch = 0,
                SysMemSlicePitch = 0,
        }

        hr = device.CreateBuffer(device, &vertex_buffer_desc, &vertex_data, &rg.vertex_buffer)
        if hr != 0 {
                panic("Failed to create the vertex buffer!")
        }

        // Create index buffer
        index_buffer_desc := d3d.BUFFER_DESC{
                Usage = .DEFAULT,
                ByteWidth = cast(u32)len(rg.index_array) * size_of(u32),
                BindFlags = {.INDEX_BUFFER},
                CPUAccessFlags = {},
                MiscFlags = {},
        }

        index_data := d3d.SUBRESOURCE_DATA{
                pSysMem = &rg.index_array[0],
                SysMemPitch = 0,
                SysMemSlicePitch = 0,
        }

        hr = device.CreateBuffer(device, &index_buffer_desc, &index_data, &rg.index_buffer)
        if hr != 0 {
                panic("Failed to create the index buffer!")
        }

        // Create constant buffer
        constant_buffer_desc := d3d.BUFFER_DESC{
                Usage = .DYNAMIC,
                ByteWidth = size_of(VS_Constant_Buffer),
                BindFlags = {.CONSTANT_BUFFER},
                CPUAccessFlags = {.WRITE},
                MiscFlags = {},
        }

        hr = device.CreateBuffer(device, &constant_buffer_desc, nil, &rg.constant_buffer)
        if hr != 0 {
                panic("Failed to create the constant buffer!")
        }

        return rg, true
}

delete_render_group :: proc(rg: ^Render_Group) {
        return
}

render :: proc(direct_3d: ^Direct_3D, window: Window, rg: ^Render_Group, camera: ^Camera) {
        client_rect := get_client_rect(window)
        width: f32 = cast(f32)(client_rect.right - client_rect.left)
        height: f32 = cast(f32)(client_rect.bottom - client_rect.top)

        viewport := d3d.VIEWPORT{TopLeftX = 0.0, TopLeftY = 0.0,
                                 Width  = width, Height = height,
                                 MinDepth = 0.0, MaxDepth = 1.0}
        direct_3d.dcontext.RSSetViewports(direct_3d.dcontext, 1, &viewport)
        direct_3d.dcontext.OMSetRenderTargets(direct_3d.dcontext, 1, &direct_3d.render_target_view, direct_3d.depth_stencil_view)

        stride: u32 = size_of(Vertex)
        offset: u32 = 0

        direct_3d.dcontext.IASetInputLayout(direct_3d.dcontext, rg.input_layout)
        direct_3d.dcontext.IASetVertexBuffers(direct_3d.dcontext, 0, 1, &rg.vertex_buffer, &stride, &offset)
        direct_3d.dcontext.IASetIndexBuffer(direct_3d.dcontext, rg.index_buffer, .R32_UINT, 0)
        direct_3d.dcontext.IASetPrimitiveTopology(direct_3d.dcontext, .TRIANGLELIST)

        direct_3d.dcontext.VSSetShader(direct_3d.dcontext, rg.vertex_shader, nil, 0)
        direct_3d.dcontext.VSSetConstantBuffers(direct_3d.dcontext, 0, 1, &rg.constant_buffer)

        // Supplying the constant buffer with data
        vs_constant_buffer_data := VS_Constant_Buffer{}
        vs_constant_buffer_data.model = scale({0.1, 0.1, 0.1})
        vs_constant_buffer_data.view = look_at(camera.position, camera.position + camera.direction, camera.up)
        //vs_constant_buffer_data.proj = orthographic(-8, 8, -4.5, 4.5, 0.1, 100.0)
        vs_constant_buffer_data.proj = perspective(1.57, width / height, 0.1, 100)

        mapped_subresource := d3d.MAPPED_SUBRESOURCE{}
        direct_3d.dcontext.Map(direct_3d.dcontext, rg.constant_buffer, 0, .WRITE_DISCARD, {}, &mapped_subresource)
        runtime.mem_copy(mapped_subresource.pData, &vs_constant_buffer_data, size_of(vs_constant_buffer_data))
        direct_3d.dcontext.Unmap(direct_3d.dcontext, rg.constant_buffer, 0)

        direct_3d.dcontext.PSSetShader(direct_3d.dcontext, rg.pixel_shader, nil, 0)
        // direct_3d.dcontext.PSSetShaderResources(direct_3d.dcontext, 0, 1, &texture_view)
        // direct_3d.dcontext.PSSetSamplers(direct_3d.dcontext, 0, 1, &sampler_state)

        clear_color := [?]f32{0.0, 0.0, 0.0, 1.0}
        direct_3d.dcontext.ClearRenderTargetView(direct_3d.dcontext, direct_3d.render_target_view, &clear_color)
        direct_3d.dcontext.ClearDepthStencilView(direct_3d.dcontext, direct_3d.depth_stencil_view, {.DEPTH, .STENCIL}, 1.0, 0)

        direct_3d.dcontext.DrawIndexed(direct_3d.dcontext, cast(u32)len(rg.index_array), 0, 0)

        hr: d3d.HRESULT = direct_3d.swapchain.Present(direct_3d.swapchain, 0, present_flags) // 0 & .ALLOW_TEARING = no vsync
        assert(hr == 0)
}
