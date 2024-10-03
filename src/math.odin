package flightsim

import "core:math/linalg"

float  :: f32
double :: f64

float3 :: [3]float
float4 :: [4]float

float3x3 :: matrix[3, 3]float
float4x4 :: matrix[4, 4]float

turns_to_rad :: proc(turn: float) -> float {
        return turn * 2 * linalg.PI
}

cot :: proc(v: float) -> float
{
        return linalg.cos(v) / linalg.sin(v)
}

scale :: proc(scale: float3) -> float4x4 {
        return linalg.transpose(linalg.matrix4_scale_f32(scale))
}

float4x4_diag :: proc(diag: float) -> float4x4 {
        return float4x4{
                diag, 0, 0, 0,
                0, diag, 0, 0,
                0, 0, diag, 0,
                0, 0, 0, diag,
        }
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

perspective :: proc(fov, aspect, near, far: float) -> float4x4
{
        f := cot(0.5 * fov)
        depth := far - near

        tmp1 := far / depth
        tmp2 := near * far / depth

        return float4x4{
                f / aspect, 0, 0,     0,
                0,          f, 0,     0,
                0,          0, tmp1,  1,
                0,          0, -tmp2, 0,
        }
}
