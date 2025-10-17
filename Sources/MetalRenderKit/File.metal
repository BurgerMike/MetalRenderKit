//
//  File.metal
//  MetalRenderKit
//
//  Created by Miguel Carlos Elizondo Mrtinez on 17/10/25.
//

#include <metal_stdlib>
using namespace metal;

struct MRFrameUniforms {
    float4x4 viewProj;
    float3   lightDir; float _pad0;
    float4   lightColInt;
    float3   camPos;   float _pad1;
};
struct MRModelUniforms {
    float4x4 model;
    float3   baseColor;
    float    metallic;
    float    roughness;
    float2   _pad2;
};
struct VIn { float3 pos [[attribute(0)]], nrm [[attribute(1)]]; float2 uv [[attribute(2)]]; };
struct VOut { float4 pos [[position]]; float3 nrmW; float3 posW; float3 col; float roughness; };

inline float3x3 upperLeft3x3(float4x4 m){ return float3x3(m[0].xyz, m[1].xyz, m[2].xyz); }
inline float3x3 inverse3x3(float3x3 a){
    float a00=a[0][0], a01=a[0][1], a02=a[0][2];
    float a10=a[1][0], a11=a[1][1], a12=a[1][2];
    float a20=a[2][0], a21=a[2][1], a22=a[2][2];
    float c00=(a11*a22-a12*a21), c01=-(a10*a22-a12*a20), c02=(a10*a21-a11*a20);
    float c10=-(a01*a22-a02*a21), c11=(a00*a22-a02*a20), c12=-(a00*a21-a01*a20);
    float c20=(a01*a12-a02*a11), c21=-(a00*a12-a02*a10), c22=(a00*a11-a01*a10);
    float det=a00*c00+a01*c01+a02*c02, invDet=1.0/det;
    return invDet*float3x3(float3(c00,c10,c20), float3(c01,c11,c21), float3(c02,c12,c22));
}

vertex VOut mr_v_main(VIn in [[stage_in]],
                      constant MRFrameUniforms& F [[buffer(3)]],
                      constant MRModelUniforms& M [[buffer(4)]]) {
    VOut o;
    float4 pw = M.model * float4(in.pos,1);
    o.pos = F.viewProj * pw;
    float3x3 N = transpose(inverse3x3(upperLeft3x3(M.model)));
    o.nrmW = normalize(N * in.nrm);
    o.posW = pw.xyz/pw.w;
    o.col  = M.baseColor;
    o.roughness = M.roughness;
    return o;
}

fragment float4 mr_f_main(VOut in [[stage_in]],
                          constant MRFrameUniforms& F [[buffer(1)]],
                          constant MRModelUniforms& M [[buffer(0)]]) {
    float3 N = normalize(in.nrmW);
    float3 L = normalize(-F.lightDir);
    float3 V = normalize(F.camPos - in.posW);
    float3 H = normalize(L + V);
    float ndl = clamp(dot(N,L),0.0,1.0);
    float ndh = clamp(dot(N,H),0.0,1.0);
    float specPow = mix(4.0, 64.0, 1.0 - clamp(in.roughness,0.0,1.0));
    float3 kd = in.col * ndl;
    float ks = pow(ndh, specPow);
    float3 lit = F.lightColInt.rgb * (kd + 0.2 * ks);
    return float4(lit, 1.0);
}


