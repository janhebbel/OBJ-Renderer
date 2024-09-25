Texture2D texture;
SamplerState texture_sampler {
        Filter = MIN_MAG_MIP_LINEAR;
        AddressU = Wrap;
        AddressV = Wrap;
}

struct Pixel_In {
        float2 tex_coord : TEXCOORD;
        float3 normal : NORMAL;
}

float4 pixel_main(Pixel_In in) {
        return texture.Sample(texture_sampler, in.tex_coord);
}
