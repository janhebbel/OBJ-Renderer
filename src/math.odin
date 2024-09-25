package flightsim
// 
// float2 :: distinct [2]f32
// float3 :: distinct [3]f32
// float4 :: distinct [4]f32
// 
// float3x3 :: distinct matrix[3, 3]f32
// float4x4 :: distinct matrix[4, 4]f32
// 
// dot :: proc(v1, v2: float3) -> f32 {
//         return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
// }
// 
// len :: proc(v: float3) -> f32 {
//         return sqrt(dot(v, v))
// }
// 
// normalize :: proc(v: float3) -> float3 {
//         len := len(v)
//         return v / float3{len, len, len}
// }
// 
// cross :: proc(v1, v2: float3) -> float3 {
//         tmp1 := v1.yzx * v2.zxy
//         tmp2 := v1.zxi * v2.yzx
//         return tmp1 - tmp2
// }
// 
// look_at :: proc(pos: float3, eye: float3, fake_up: float3) -> float4x4 {
//         backward := pos - eye
//         right := cross(fake_up, backward)
//         up := cross(backward, right)
// 
//         m := float4x4{
//                 
//         }
// 
//         return m
// }
