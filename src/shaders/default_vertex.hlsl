cbuffer Matrix_Buffer {
        matrix model;
        matrix view;
        matrix proj;
};

struct Vertex_In {
        float4 position : POSITIION;
        float2 tex_coord : TEXCOORD;
        float3 normal : NORMAL;
};

struct Vertex_Out {
        float4 position : SV_POSITION;
        float2 tex_coord : TEXCOORD;
        float3 normal : NORMAL;
};

Vertex_Out vertex_main(Vertex_In vertex_in)
{
        Vertex_Out vertex_out;
        vertex_out.position = mul(vertex_in.position, model);
        vertex_out.position = mul(vertex_in.position, view);
        vertex_out.position = mul(vertex_in.position, proj);
        vertex_out.normal = mul(vertex_in.normal, (float3x3)model);
        vertex_out.tex_coord = vertex_in.tex_coord;
        return vertex_out;
}
