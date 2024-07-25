// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// a hasty duplicated material that's pretty much NagaiSurfaceV3 with a couple of differences:
// - a hacky noise texture vertex displacement meant to look vaguely like wind (this was a hasty addition to the demo scene and not done properly)
// - rendertype tags are modified to ensure proper clipping support for outlines generated via the custom depth normals.

Shader "GraphicsLearning/NagaiPalmLeaves"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Main Texture", 2D) = "white" {}
        _WindTex ("Wind Texture", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", float) = 1.0
        _Roughness("Roughness", Range(0,2)) = 0
        _DiffuseRange ("Diffuse Range", float) = 1
        _DiffuseFalloff ("Diffuse Falloff", float) = 1
        _AmbientFactor("Ambient Factor", Range(0,1)) = 1
        _SpecularColor ("Specular Color", color) = (1,1,1,1)
        _SpecularStrength ("Specular Strength", float) = 1
        _SpecularFalloff ("Specular Falloff", float) = 1
        _SpecularRange ("Specular Range", float) = 1
        _SpecularCutoff("Specular Cutoff", Range(0,1)) = 1.0
        _SpecularBlend("Specular Blend", Range(0,1)) = 1
        _ShadowTightness("Shadow Tightness", Range(0,1)) = 0.01
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.0
        _OutlineNormals("Outline Normals", Range(0,1))= 1
        _OutlineDepth("Outline Depth", Range(0,1)) = 1
    }
    
    // what does this CGINCLUDE block do?
    // it's a preprocessor thing that will
    // automatically populate this in 
    // each of our subshaders.
    // You can have multiple vert and frag functions in your CGINCLUDE block,
    // and specify which you desire per pass using #pragma vertex nameOfVertFunc
    CGINCLUDE
        #include "../Lib/NagaiLighting.cginc"
        // this CGInclude is big and beefy and includes just about every helper under the sun.
        #include "UnityStandardCore.cginc"
        #include "../Lib/TriplanarMapping.cginc"
    
        sampler2D _NormalMap;
        float4 _NormalMap_ST;
        sampler2D _WindTex;
        float4 _WindTex_ST;
        half _DiffuseRange;
        half _DiffuseFalloff;
        half _Roughness;
        half _AmbientFactor;
        half4 _SpecularColor;
        half _SpecularStrength;
        half _SpecularRange;
        half _SpecularFalloff;
        half _SpecularCutoff;
        half _SpecularBlend;
        half _ShadowTightness;

        //global value
        sampler2D _NagaiGlobalNoise;

        //global shader variable for fake ambient light.
        half4 _NagaiAmbientLight;

        //global shader variable for fake specular light
        half4 _NagaiDeferredMainLightColor;

        // Unity magic variables for lightmaps.
        // These are currently defined in some include somewhere.
        //sampler2D unity_Lightmap;
        //float4 unity_LightmapST;

        SamplerState samplerunity_LightmapInd;

    
        struct appdata
        {
            //stick with the naming conventions in this struct -
            //lots of unity macros expect them.
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float2 uv1 : TEXCOORD1;
            float3 normal : NORMAL;
            half4 tangent : TANGENT;
        };

        struct v2f
        {
            float4 pos : SV_POSITION;
            float4 uv : TEXCOORD0;
            UNITY_FOG_COORDS(1)
            float4 screenPos : TEXCOORD2;
            //you can pack texcoord channels with arrays!
            float4 tangentToWorldAndPackedData[3] : TEXCOORD3;
            //if we don't calculate sh and just use the unity aggregate variables we can free up this texcoord.
            half3 sh : TEXCOORD6;
            float2 lightmap : TEXCOORD7;
            //this packs light coords into TEXCOORD8
            //and shadow coords into TEXCOORD9
            UNITY_LIGHTING_COORDS(8, 9)
            #ifdef DIRLIGHTMAP_OFF
					float4 lmapFadePos : TEXCOORD10;
			#endif
                half3 lightDir : TEXCOORD11;
            half depth : SV_Depth;
        };

        v2f vert (appdata v)
        {
            v2f o;

            //we cannot use tex2D in the vert function!!
            //we instead must use tex2Dlod. it doesn't have a high of a fidelity as tex2D.
            float4 windUV= 0;
            windUV.xy= TRANSFORM_TEX(v.uv, _WindTex) * _Time.x;
            float4 windSample = tex2Dlod(_WindTex, windUV);

            v.vertex.xyz += windSample.rgb * 1;

            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
            o.uv.zw = TRANSFORM_TEX(v.uv, _NormalMap);
            UNITY_TRANSFER_FOG(o,o.vertex);
            
            // //this call is used to cumulatively build lighting in additive pass. don't forget it!
            UNITY_TRANSFER_LIGHTING(o, v.uv1.xy);
            
            o.screenPos = ComputeScreenPos(o.pos);

            float3 normalWorld = UnityObjectToWorldNormal(v.normal);
            float3 worldPos= mul(unity_ObjectToWorld, v.vertex);

            //we need tangent space information to properly display normal maps.
            float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

            //this builds us a transformation matrix to take this vertex's tangent space and transform it into worldspace.
            //we will use this build a world normal from our normal map to dot against the light for this pass!
            float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);

            o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
            o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
            o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
            
            //we also pack the worldspace vertex pos into the w on these float4s - efficient!
            o.tangentToWorldAndPackedData[0].w= worldPos.x;
            o.tangentToWorldAndPackedData[1].w= worldPos.y;
            o.tangentToWorldAndPackedData[2].w= worldPos.z;

            o.lightmap = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
            
            o.sh= unity_AmbientSky;

            // we calculate the light direction per-vertex since it's just gonna get interpolated from vertex anyway

            // fun fact: you can tell a directional light from a point/spot light just by looking at their values.
            // how? directional lights store their direction in their xyz rather than position, but
            // they also store a 0 in their w coordinate, while point/spot uses a 1.
              float3 lightDir = WorldSpaceLightDir(v.vertex);
              #ifdef USING_DIRECTIONAL_LIGHT
                  lightDir = NormalizePerVertexNormal(lightDir);
              #endif
            
             o.lightDir= lightDir;
            
            return o;
        }
    
    ENDCG
    
    SubShader
    {
        //TODO: potentially modify Shade4PointLights or ShadeVertexLightsFull to use oren nayar coefficient to do multiple lights in one pass?

        Tags 
        { 
            "RenderType"="NagaiTree" 
            "Queue"="Geometry" 
        }

        Pass
        {
            LOD 200
            ZWrite on
            Blend One Zero
        
            Tags
            {
                "LightMode"="ForwardBase"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma target 3.0
            // we need this for when we add an additive light pass,
            // as this allows us to use preprocessor defines which target this pass
            // specifically within our CGINCLUDE
            // basically "only do this if we are in fwd base"
            #pragma multi_compile_fwdbase
            // When lightmaps are used, Unity will never include vertex lights.
            // Their keywords are mutually exclusive. So we don't need a variant with both VERTEXLIGHT_ON and LIGHTMAP_ON at the same time.
            // - catlike coding (https://catlikecoding.com/unity/tutorials/rendering/part-16/)
            #pragma multi_compile _ LIGHTMAP_ON VERTEXLIGHT_ON
            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 c = tex2D (_MainTex, i.uv.xy) * _Color;

                clip(c.a - _Cutoff);

                // unpack worldpos from our packed data.
                float3 worldPos;
                worldPos.x= i.tangentToWorldAndPackedData[0].w;
                worldPos.y= i.tangentToWorldAndPackedData[1].w;
                worldPos.z= i.tangentToWorldAndPackedData[2].w;

                // tangent space normal sampled from normal map.
                half4 normalTex = tex2D (_NormalMap, i.uv.zw);
                // normal unpacking.
                half3 normalTS= UnpackScaleNormal(normalTex, _BumpScale);

                // normal maps store a normal surface in tangent space.
                // if we build a world normal from it using our matrix... we can light it!
                float3 worldNormal= ConstructWorldNormalWithNormalMapSample(
                    i.tangentToWorldAndPackedData[0].xyz,
                    i.tangentToWorldAndPackedData[1].xyz,
                    i.tangentToWorldAndPackedData[2].xyz,
                    normalTS);
                
                // be sure to normalize this, or you will get wonkiness based on where in the world you're looking from.
                half3 worldViewDir = normalize(_WorldSpaceCameraPos - worldPos);

                // mysterious light attenuation macro. internally, has different implementations for point, direction, etc. that get selected contextually via macroguarding.
                // not a big fan of that.
                UNITY_LIGHT_ATTENUATION(atten, i, 0)

                UnityLight light= MainLight();
                
                // currently unused out term.
                half diffuse;

                float3 lightmapSample= 0;
                float4 lightmapDir= 0;

                half sh = unity_AmbientSky;

                #if LIGHTMAP_ON
                    lightmapSample = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmap));
                // does not decode direction, only samples the directional map.
                    lightmapDir = UNITY_SAMPLE_TEX2D(unity_LightmapInd, i.lightmap);
                #endif
                
                c = Lighting_Toon_Oren_Nayar(c, light, worldPos, lightmapSample, lightmapDir, worldViewDir, worldNormal, _Roughness,
                    _DiffuseRange, _DiffuseFalloff, _ShadowTightness, _SpecularFalloff, _SpecularRange,
                    _SpecularStrength, _SpecularCutoff,_SpecularColor, _SpecularBlend, atten, sh, _AmbientFactor, 0);

                half4 noiseSample= 1;
                noiseSample.rgb = SampleTexTriplanar(_NagaiGlobalNoise, worldPos, worldNormal);
                return c * noiseSample;
            }
            
            ENDCG
        }

        Pass
        {
            Tags
            {
                "LightMode"="ForwardAdd"
            }
            
            // forward additive pass - no need to write to zbuffer.
            ZWrite off
            // blend mode
            Blend One One
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma target 3.0
            #pragma multi_compile_fwdadd_fullshadows
			
            fixed4 frag (v2f i) : SV_Target
            {
                // this is largely the same as our base pass frag, with a few omissions.
                
                fixed4 c = tex2D (_MainTex, i.uv.xy) * _Color;

                clip(c.a - _Cutoff);

                float3 worldPos;
                worldPos.x= i.tangentToWorldAndPackedData[0].w;
                worldPos.y= i.tangentToWorldAndPackedData[1].w;
                worldPos.z= i.tangentToWorldAndPackedData[2].w;

                half4 normalTex = tex2D (_NormalMap, i.uv.zw);
                half3 normalTS= UnpackScaleNormal(normalTex, _BumpScale);
                
                float3 worldNormal= ConstructWorldNormalWithNormalMapSample(
                    i.tangentToWorldAndPackedData[0].xyz,
                    i.tangentToWorldAndPackedData[1].xyz,
                    i.tangentToWorldAndPackedData[2].xyz,
                    normalTS);
                
                half3 worldViewDir = normalize(_WorldSpaceCameraPos - worldPos);

                UNITY_LIGHT_ATTENUATION(atten, i, worldPos.xyz)

                // note the use of the bespoke additive macro here.
                UnityLight light= AdditiveLight(i.lightDir, atten);
                
                // currently unused out term.
                half diffuse;

                // note: we pass in 0 for the sh value here because we only want the ambient lighting to be applied in the base pass.
                // same with lightmap, we only need to run that once.
                // we also set the isAdditivePass to 1.
                c = Lighting_Toon_Oren_Nayar(c, light, worldPos, 0, 0, worldViewDir, worldNormal, _Roughness,
                    _DiffuseRange, _DiffuseFalloff, _ShadowTightness, _SpecularFalloff, _SpecularRange,
                    _SpecularStrength, _SpecularCutoff,_SpecularColor, _SpecularBlend, atten, 0, _AmbientFactor, 1);
                
                return c;
            }
            
            ENDCG        
        }

        Pass
        {
            // fairly standard shadowcaster pass.
            // currently does nothing different than the fallback, especially with clip commented out,
            // but serves as a good example of how to define one.
            Name "ShadowCaster"
            Tags{ "LightMode" = "ShadowCaster" }
            Offset 1, 1
 
            Fog{ Mode Off }
            ZWrite On ZTest LEqual Cull Off
 
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
 
            struct shadowv2f
            {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD0;
                float3 wpos : TEXCOORD1;
                float3 vpos : TEXCOORD2;
            };
         
            struct Input {
                float3 worldPos;
            };

            shadowv2f vert(appdata_base v)
            {
                shadowv2f o;
                TRANSFER_SHADOW_CASTER(o)
                    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                // we cannot use tex2D in the vert function!!
                // we instead must use tex2Dlod. it doesn't have a high of a fidelity as tex2D.
                float4 windUV= 0;
                windUV.xy= TRANSFORM_TEX(v.texcoord, _WindTex) * _Time.x;
                float4 windSample = tex2Dlod(_WindTex, windUV);

                v.vertex.xyz += windSample.rgb * 1;
                o.pos = UnityObjectToClipPos(v.vertex);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.wpos = worldPos;
                o.vpos = v.vertex.xyz;
                return o;
            }
 
            float4 frag(shadowv2f i) : SV_TARGET
            {
                fixed4 c = tex2D (_MainTex, i.uv.xy);
                // note - clip here is currently commented out for stylistic reasons.
                //clip(c.a - .8);
         
                SHADOW_CASTER_FRAGMENT(i)
            }
        ENDCG
 
        }
    }
}