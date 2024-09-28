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

look_at :: proc(pos: float3, at: float3, up: float3) -> float4x4
{
        zaxis := linalg.normalize(at - pos)
        xaxis := linalg.normalize(linalg.cross(up, zaxis))
        yaxis := linalg.normalize(linalg.cross(zaxis, xaxis))

        cosx := linalg.dot(xaxis, pos)
        cosy := linalg.dot(yaxis, pos)
        cosz := linalg.dot(zaxis, pos)

        return float4x4{
                xaxis.x, yaxis.x, zaxis.x, 0,
                xaxis.y, yaxis.y, zaxis.y, 0,
                xaxis.z, yaxis.z, zaxis.z, 0,
                -cosx,   -cosy,   -cosz,   1,
        }
}

orthographic :: proc(left, right, bottom, top, near, far: float) -> float4x4
{
        width  := right - left
        height := top - bottom
        depth  := far - near

        tmp1 := -(right + left) / width
        tmp2 := -(top + bottom) / height
        tmp3 := -near / depth

        return float4x4{
                2 / width, 0,          0,          0,
                0,         2 / height, 0,          0,
                0,         0,          1 / depth,  0,
                tmp1,      tmp2,       tmp3,       1,
        }
}

// TODO: Fix this matrix.
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
