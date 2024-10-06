package flightsim

import "core:math/linalg"

Camera :: struct {
        position: float3,
        direction: float3,
        up: float3,
        yaw: f32,
        pitch: f32,
        sensitivity: f32,
        speed: f32,
        fov: f32,
}

make_camera :: proc(pos: float3, dir: float3, up: float3, sensitivity: f32, speed: f32, fov: f32) -> Camera {
        // NOTE(Jan, 03.10.2024): this function expects fov to be in degrees
        return Camera{
                pos,
                dir,
                up,
                -90,
                0,
                sensitivity,
                speed,
                linalg.to_radians(fov),
        }
}

update :: proc(delta_time: f64, camera: ^Camera, window: Window) {
        if window_has_focus() {
                cursor_pos := get_cursor_pos()
                xpos := cast(f32)cursor_pos.x
                ypos := cast(f32)cursor_pos.y

                // TODO: remove this once proper window resize management is implemented
                window_rect := get_window_rect(window)

                middle_x := window_rect.left + ((window_rect.right - window_rect.left) / 2)
                middle_y := window_rect.top + ((window_rect.bottom - window_rect.top) / 2)

                dx := xpos - cast(f32)middle_x
                dy := ypos - cast(f32)middle_y

                dx *= camera.sensitivity
                dy *= camera.sensitivity

                if dx != 0 || dy != 0 {
                        set_cursor_pos(middle_x, middle_y)
                }

                camera.yaw += dx
                camera.pitch += dy

                if camera.pitch > 89.0 {
                        camera.pitch = 89.0
                } else if camera.pitch < -89.0 {
                        camera.pitch = -89.0
                }

                yaw_rad := -linalg.to_radians(camera.yaw)
                pitch_rad := -linalg.to_radians(camera.pitch)

                camera.direction.x = linalg.cos(yaw_rad) * linalg.cos(pitch_rad)
                camera.direction.y = linalg.sin(pitch_rad)
                camera.direction.z = linalg.sin(yaw_rad) * linalg.cos(pitch_rad)
                camera.direction = linalg.normalize(camera.direction)

                // Handling keyboard input
                add := [3]f32{}
                if is_down('W') {
                        add += camera.direction
                }
                if is_down('S') {
                        add -= camera.direction
                }
                if is_down('A') {
                        add += linalg.normalize(linalg.cross(camera.direction, camera.up))
                }
                if is_down('D') {
                        add -= linalg.normalize(linalg.cross(camera.direction, camera.up))
                }
                f32_delta_time := cast(f32)delta_time
                if (add.x != 0 || add.y != 0 || add.z != 0) { add = linalg.normalize(add) }
                add *= {f32_delta_time * camera.speed, f32_delta_time * camera.speed, f32_delta_time * camera.speed}
                camera.position += add

                update_key_was_down()
        }
}
