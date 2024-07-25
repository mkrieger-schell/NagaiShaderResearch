// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// Oren-Nayar constants and calculations adapted under MIT License from Jordan Stevens's tutorials
// https://www.jordanstevenstechart.com/lighting-models

#ifndef NAGAI_LIGHTING_LIBRARY_INCLUDED
#define NAGAI_LIGHTING_LIBRARY_INCLUDED

#include "UnityCG.cginc"
// we don't use any pbs methods, but the UnityLight struct here is convenient
#include "UnityPBSLighting.cginc"

struct NagaiSurfaceOutput{
    fixed3 Albedo;
    fixed3 Normal;
    fixed3 Emission;
    half Specular;
    fixed Gloss;
    fixed Alpha;
    fixed3 ShadowColor;
    half pattern;
};

half3 DecodeDirectionalLightmapOrenNayar (half3 color, fixed4 lightmapDir, half3 worldNormal, half3 viewDir, half roughness, half diffuseRange, half diffuseFalloff)
{
    // Note that dir is not unit length on purpose. Its length is
    // "directionality", like for the directional specular lightmaps.

    half3 lightDirection= lightmapDir.xyz * 2 - 1 / max(1e-4h, lightmapDir.w);
    
    half NDotL = dot(worldNormal, lightDirection);
    half NDotV = dot(worldNormal, viewDir);
    half LDotV = dot(lightDirection, viewDir);

    // same oren nayar calculations as our main lighting function.
    half roughness2 = roughness * roughness;
    half3 oren_nayar_fraction = roughness2 / (roughness2 + half3(0.33, 0.13, 0.09));
    half3 oren_nayar = half3(1, 0, 0) + (half3(-0.5, 0.17, 0.45) * oren_nayar_fraction);
    half oren_nayar_s = saturate(LDotV) - saturate(NDotL) * saturate(NDotV);
    half3 oren_nayar_product= (oren_nayar.x + (color * oren_nayar.y) + (oren_nayar.z * oren_nayar_s));
    half3 result = color * oren_nayar_product;
    return result;
}

half4 Lighting_Toon_Oren_Nayar(half3 diffColor, UnityLight light, half3 worldPos, half3 lightmapSample, half4 lightmapDir, half3 viewDir, half3 normal,
    half roughness, half diffuseRange, half diffuseFalloff, half shadowTightness,
    half3 highlightIntensity, half3 highlightRange, half hightlightStrength, half highlightCutoff, half4 highlightColor, half highlightBlend,
    half atten, half3 sh, half ambientFactor, float isAdditivePass)
{
    half NDotL = dot(normal, light.dir);
    half NDotV = dot(normal, viewDir);
    half LDotV = dot(light.dir, viewDir);

    // these oren nayar values are approximated but will be fast and efficient
    half roughness2 = roughness * roughness;
    
    //the lower our roughness is, the less this baked roughness coefficient will apply to our final output.
    //my guess is that roughness gets squared simply due to the scale necessary for the output.
    //this magic number is apparently based on the "variance of the Gaussian distribution."
    half3 oren_nayar_fraction = roughness2 / (roughness2 + half3(0.33, 0.13, 0.09));
    
    //unsure as to what these components mean... I'm not a mathematician.
    half3 oren_nayar = half3(1, 0, 0) + (half3(-0.5, 0.17, 0.45) * oren_nayar_fraction);

    //it essentially averages out the two based on the perceive graze of the light.
    half oren_nayar_s = saturate(LDotV) - saturate(NDotL) * saturate(NDotV);

    //as we can see, the above s modifies our z, which makes sense, given it's based on viewdir (into the screen).
    //as for the y, unsure.
    //we spin this off unaffected by ndotl to be used later for grading the ambient light.
    half3 oren_nayar_product= (oren_nayar.x + (diffColor * oren_nayar.y) + (oren_nayar.z * oren_nayar_s));

    half3 NDotLCurved = exp(-pow(diffuseRange*(1 - ((NDotL * .5) + .5)), diffuseFalloff));

    atten= step(.1, atten);
    half gradedAtten= smoothstep(0, shadowTightness, saturate(atten));
    float lightIntensity = smoothstep(0, shadowTightness, NDotL * gradedAtten);

    //TODO: optimize this block
     if(isAdditivePass == 1)
     {
         gradedAtten= atten;
         lightIntensity= saturate(NDotLCurved) * (1-(pow(saturate(atten), 20)));
     }
    
    float3 lightFactor= lightIntensity * light.color;

    //

    //float3 lightComponent= lightFactor * (1-(pow(gradedAtten, 20) * flipper));//lerp(lightFactor, lightIntensity, flipper);
    float3 result = (diffColor * min(lightFactor, NDotLCurved) * oren_nayar_product);// + (lightmapSample * oren_nayar_product);

    //next, the lightmap sampling block. we decode the lightmap direction to apply the same oren-nayar grade as we did above.
    //#if !LIGHTMAP_OFF

    
    //#endif
    
    half distanceCheck= 1;
    //if point light...
    if(isAdditivePass == 1)
    {
        distanceCheck= dot(normal, normalize(light.dir - worldPos)) * .5 + .5;
    }
    
    result *= distanceCheck;

    //add in ambient light and grade along oren nayar product
    result += sh * diffColor * ambientFactor;

    half3 lightmapColor= DecodeDirectionalLightmap(lightmapSample, lightmapDir, normal);
    //half3 lightmapColor= DecodeDirectionalLightmapOrenNayar(lightmapSample, lightmapDir, normal, viewDir, diffTerm, atten, roughness, diffuseRange, diffuseFalloff, shadowTightness);
    //lightmapColor= clamp(.01, .5, lightmapColor);
    //return half4(lightmapColor.rgb, 1);
    //result += diffColor * lightmapColor;
    
    // // Light diffusion depends on the angle between the light direction vector and the surface normal vector
    // // if the angle is more than 90 degrees let it be zero
    half DiffusionFactor = dot(normal,light.dir) * .5 + .5;
    
    //half HybridDot = lerp(NDotL, NDotV, reflectivityMix);
    half3 halfwayVector = normalize(light.dir + viewDir);
                
    // The Angle between the halfway vector and the surface normal determine the amount of specular reflection
    // if the angle is more than 90 degrees let it be zero
    float NormalDotHalfway=dot(normal,halfwayVector);
    // Specular(Relative) Reflection factor
    // you can play with power but Unity default is 48
    float SpecularFactor= pow(NormalDotHalfway,48);
    
    half highlight= smoothstep(
        highlightRange - highlightIntensity,
        highlightRange + highlightIntensity,
        SpecularFactor);
    
    highlight *= DiffusionFactor;
    
    highlight = step(highlightCutoff, highlight);
    
    half lightStrength= max(light.color.r, light.color.g);
    lightStrength= max(lightStrength, light.color.b);
    
    result += ((highlightColor * hightlightStrength) * highlight * lerp(lightStrength, light.color, highlightBlend) * lerp(1, diffColor, highlightBlend)) * gradedAtten;

    return half4(result.xyz, 0);
}

float3 ConstructWorldNormalWithNormalMapSample(float3 tangentToWorldRow1, float3 tangentToWorldRow2, float3 tangentToWorldRow3, half3 normalMapSample)
{
    //first, create the three rows of our matrix.
    //this is a transposed world-to-tangent matrix - to get us from tangent to world!
    float3 ttw0= float3(tangentToWorldRow1.x, tangentToWorldRow2.x, tangentToWorldRow3.x);
    float3 ttw1= float3(tangentToWorldRow1.y, tangentToWorldRow2.y, tangentToWorldRow3.y);
    float3 ttw2= float3(tangentToWorldRow1.z, tangentToWorldRow2.z, tangentToWorldRow3.z);
                
    //we use dot products to reconstruct our world normal.
    float3 worldNormal;
    worldNormal.x= dot(ttw0, normalMapSample);
    worldNormal.y= dot(ttw1, normalMapSample);
    worldNormal.z= dot(ttw2, normalMapSample);
    return normalize(worldNormal);
}

#endif