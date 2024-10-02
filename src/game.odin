package flightsim

import "core:math/linalg"

Camera :: struct {
        position: float3,
        direction: float3,
        up: float3,
        yaw: f64,
        pitch: f64,
        sensitivity: f64,
        speed: f32,
}

update :: proc(delta_time: f32, camera: ^Camera, window: Window) {
        if window_has_focus() {
                xpos, ypos: f64
                cursor_pos := get_cursor_pos()
                xpos = cast(f64)cursor_pos.x
                ypos = cast(f64)cursor_pos.y

                // TODO: remove this once proper window resize management is implemented
                window_rect := get_window_rect(window)

                middle_x := window_rect.left + ((window_rect.right - window_rect.left) / 2)
                middle_y := window_rect.top + ((window_rect.bottom - window_rect.top) / 2)

                dx := xpos - cast(f64)middle_x
                dy := ypos - cast(f64)middle_y

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

                camera.direction.x = cast(f32)(linalg.cos(yaw_rad) * linalg.cos(pitch_rad))
                camera.direction.y = cast(f32)(linalg.sin(pitch_rad))
                camera.direction.z = cast(f32)(linalg.sin(yaw_rad) * linalg.cos(pitch_rad))
                camera.direction = linalg.normalize(camera.direction)

                // Handling keyboard input
                add := float3{}
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
                if (add.x != 0 || add.y != 0 || add.z != 0) { add = linalg.normalize(add) }
                camera.position += add * {delta_time * camera.speed, delta_time * camera.speed, delta_time * camera.speed}

                update_key_was_down()
        }
}
