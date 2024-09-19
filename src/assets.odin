package flightsim

import "core:os"

Vertex :: struct {
    position: [4]f32,
    uv: [2]f32,
    normal: [3]f32,
}

Model :: struct {
    vertex_array: ^Vertex,
    index_array: ^u32,
    vertex_count: i32,
    index_count: i32,
}

load_model :: proc(filename: string) -> (model: Model, success: bool) {
    data := os.read_entire_file_from_filename(filename) or_return
    defer delete(data)
    return obj_parse(data)
}

obj_parse :: proc(data: []u8) -> (model: Model, success: bool) {
    return model, true
}
