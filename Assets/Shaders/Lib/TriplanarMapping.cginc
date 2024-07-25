// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// modified sample from Catlike Coding
// https://catlikecoding.com/unity/tutorials/advanced-rendering/triplanar-mapping/
// license info (MIT-0, okay to redistribute):
// https://catlikecoding.com/unity/tutorials/license/

struct TriplanarUV
{
    float2 x, y, z;
};

TriplanarUV GetTriplanarUV (half3 worldPos, float3 normal)
{
    TriplanarUV triUV;
    triUV.x = worldPos.zy;
    triUV.y = worldPos.xz;
    triUV.z = worldPos.xy;
    if (normal.x < 0) {
        triUV.x.x = -triUV.x.x;
    }
    if (normal.y < 0) {
        triUV.y.x = -triUV.y.x;
    }
    if (normal.z >= 0) {
        triUV.z.x = -triUV.z.x;
    }
    triUV.x.y += 0.5;
    triUV.z.x += 0.5;
    return triUV;
}

float3 GetTriplanarWeights (float3 normal)
{
    float3 triW = abs(normal);
    return triW / (triW.x + triW.y + triW.z);
}

half3 SampleTexTriplanar (sampler2D sample, half3 worldPos, float3 worldNormal)
{
    TriplanarUV triUV = GetTriplanarUV(worldPos, worldNormal);
	
    float3 albedoX = tex2D(sample, triUV.x).rgb;
    float3 albedoY = tex2D(sample, triUV.y).rgb;
    float3 albedoZ = tex2D(sample, triUV.z).rgb;

    half3 weights= GetTriplanarWeights(worldNormal);
	
    return albedoX * weights.x + albedoY * weights.y + albedoZ * weights.z;
}