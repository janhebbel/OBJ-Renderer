package flightsim

import "core:math/linalg"

float  :: f32
double :: f64

float3 :: [3]float
float4 :: [4]float

float3x3 :: matrix[3, 3]float
float4x4 :: matrix[4, 4]float

cot :: proc(v: float) -> float
{
        return linalg.cos(v) / linalg.sin(v)
}

look_at :: proc(pos: float3, eye: float3, fake_up: float3) -> float4x4
{
        backward := pos - eye
        right := linalg.cross(fake_up, backward)
        up := linalg.cross(backward, right)

        cos1 := linalg.dot(right, pos)
        cos2 := linalg.dot(up, pos)
        cos3 := linalg.dot(backward, pos)

        return float4x4{
                right.x,    right.y,    right.z,    -cos1,
                up.x,       up.y,       up.z,       -cos2,
                backward.x, backward.y, backward.z, -cos3,
                0.0,        0.0,        0.0,        1.0,
        }
}

orthographic :: proc(left, right, bottom, top, near, far: float) -> float4x4
{
        width  := right - left
        height := top - bottom
        depth  := far - near

        m30 := (right + left) / width
        m31 := (top + bottom) / height
        m32 := (far + near)   / depth

        return float4x4{
                2.0 / width, 0.0,        0.0,          -m30,
                0.0,         2 / height, 0.0,          -m31,
                0.0,         0.0,        -2.0 / depth, -m32,
                0.0,         0.0,        0.0,          1.0,
        }
}

perspective :: proc(fov, aspect, near, far: float) -> float4x4
{
        f := cot(0.5 * fov)
        inv_depth := 1.0 / (near - far)

        return float4x4{
                f * aspect, 0.0, 0.0,                      0.0,
                0.0,        f,   0.0,                      0.0,
                0.0,        0.0, (far + near) * inv_depth, 2 * far * near * inv_depth,
                0.0,        0.0, -1.0,                     0.0,
        }
}
