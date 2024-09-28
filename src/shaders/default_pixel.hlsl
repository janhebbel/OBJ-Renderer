// Texture2D tex;
// SamplerState texture_sampler {
//         Filter = MIN_MAG_MIP_LINEAR;
//         AddressU = Wrap;
//         AddressV = Wrap;
// };

struct Pixel_In {
        float4 position : SV_POSITION;
        float2 tex_coord : TEXCOORD0;
        float3 normal : NORMAL;
};

float4 pixel_main(Pixel_In pixel_in) : SV_TARGET
{
        // return tex.Sample(texture_sampler, pixel_in.tex_coord);
        return float4(1.0f, 1.0f, 1.0f, 1.0f);
}
