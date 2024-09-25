cbuffer Matrix_Buffer {
        matrix model;
        matrix view;
        matrix proj;
}

struct Vertex_In {
        float4 position : POSITIION;
        float2 tex_coord : TEXCOORD;
        float3 normal : NORMAL;
}

struct Vertex_Out {
        float4 position SV_POSITION;
        float2 tex_coord : TEXCOORD;
        float3 normal : NORMAL;
}

Vertex_Out default_vertex_shader(Vertex_In in) {
        Vertex_Out out;
        out.position = mul(in.position, model);
        out.position = mul(in.position, view);
        out.position = mul(in.position, proj);
        out.normal = mul(in.normal, (float3x3)model);
        out.tex_coord = in.tex_coord;
        return out;
}
