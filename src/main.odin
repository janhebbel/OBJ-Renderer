package flightsim

import "core:fmt"

main :: proc() {
        window, success := create_window(1280, 720, "Errrm")
        if !success {
                fmt.println("Failed to create a window.")
                return
        }

        direct_3d: Direct_3D
        direct_3d, success = renderer_init(window)
        if !success {
                fmt.println("Failed to initialize Direct3D.")
                return
        }

        //
        // Main loop set up
        //
        delta_time, time_last, time_now: f32 = 0.0, 0.0, 0.0

        show_window(window)

        // Load model and store in render group
        render_group: Render_Group
        // model := float4x4_diag(1.0)
        model := scale({0.1, 0.1, 0.1})
        render_group, success = make_render_group("..\\res\\car.obj", &direct_3d, model)
        if !success {
                fmt.println("Failed to create a render group.")
                return
        }
        defer delete_render_group(&render_group)

        // Camera
        camera := make_camera({0, 0, -3}, {0, 0, 1}, {0, 1, 0}, 0.1, 10, 90)

        //
        // Main Loop
        //
        for is_running() {
                // Calculate delta time
                time_last = time_now
                time_now = cast(f32)get_time()
                delta_time = time_now - time_last
                
                process_messages()

                update(delta_time, &camera, window)
                render(&direct_3d, window, &render_group, &camera)
        }
}
