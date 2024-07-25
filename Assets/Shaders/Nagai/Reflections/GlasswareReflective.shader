// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// simple reflective glass sampling a cubemap. 
// reflectionprobes generate these maps and are a great tool for whipping up cubemap textures of your scene.
// they should be placed around the position of your object for maximum accuracy.

Shader "GraphicsLearning/GlasswareReflective"
{
    Properties
    {
        [HDR]
        _Color ("Color", Color) = (1,1,1,1)
        _FresnelColor("Fresnel Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _Cubemap ("Cubemap", Cube) = "_Skybox" {}
        _ReflectionMix("Reflection Mix", Range(0,1)) = 0
        _ReflectionGain("Reflection Gain", float) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" 
            "Queue"="Transparent"
        }
        LOD 100

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite On
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile_fwdadd_fullshadows

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 reflectDir : TEXCOORD2;
                float3 worldNormal : NORMAL;
                float3 worldViewDir : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half _ReflectionMix;
            half4 _Color;
            half4 _FresnelColor;
            half _ReflectionGain;

            samplerCUBE _Cubemap;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldViewDir = UnityWorldSpaceViewDir(mul(unity_ObjectToWorld, v.vertex));
                o.worldNormal= UnityObjectToWorldNormal(v.normal);
                // get the reflection vector for sampling the cubemap.
                o.reflectDir = reflect(-o.worldViewDir, o.worldNormal);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                half4 cubemapSample = texCUBE(_Cubemap, i.reflectDir);
                // texCUBElod (tex, half4(coord, lod))
                
                // if our cubemaps have mipmaps, lod here is a float4
                // our .xyz are our reflect dir, and the .w is the mipmap level.
                // good for fuzzier reflections

                UNITY_APPLY_FOG(i.fogCoord, col);
                col.rgb = lerp(col.rgb, cubemapSample.rgb * _ReflectionGain, _ReflectionMix);
                half fresnel = 1-saturate(dot(i.worldNormal, normalize(i.worldViewDir)));
                col.a = saturate(col.a + fresnel);
                return col;
            }
            ENDCG
        }
    }
}
