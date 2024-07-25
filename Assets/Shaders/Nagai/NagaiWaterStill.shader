// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// rather beefy shader for the pool/fountain water in the Nagai demo.
// this effect has several components:
// -use a grabpass to provide transparency, with distortion (similar to NagaiGlass.shader)
// -use a depth sample to create outlines around objects in the water (to mimic surface tension)
// -parallax effect to fake surface undulation
// -sampling cubemap and comparing to to voronoi noise texture and a scrolling sparkle texture to create a stylized reflection,
//		meant to mimic the look of light reflecting off of the ripples in pool water (as well as take inspiration from Hiroshi Nagai's art).

Shader "GraphicsLearning/NagaiWaterStill"
{
	Properties
	{
		_MainTex		("Base Texture", 2D) = "white" {}
		_Cubemap ("Cubemap", Cube) = "_Skybox" {}
		_SparkleTex		("Sparkle Texture", 2D) = "white" {}
		_VoronoiTex		("Voronoi Texture", 2D) = "white" {}
		_SurfaceDistortion("Surface Distortion", 2D) = "white" {}	
		_SurfaceDistortionAmount("Surface Distortion Amount", Range(0, 1)) = 0.27
		_SparkleMix		("Sparkle Threshold", Range(0,1)) = .55
		_Color			("Base Color", Color) = (0.5, 0.5, 0.5, 1)
		_GradColor		("Gradient Color", Color) = (0, 0, 0, 1)
		_Parallax 		("Parallax Strength", Range(-0.1, 0.1)) = 0.025
		_CycleSpeed		("Cycle Speed", Vector) = (1, 1, 0.5, 0.5)
		_ScrollSpeed	("Scroll Speed", Vector) = (2, 2, 0, 0)
		_SparkleScrollSpeed ("Sparkle Scroll Speed", Vector) = (2,2,-2,2)
		_DistanceFactor	("Distance Factor", float) = .075
		_GrabMix		("Grab Mix", Range(0, 1)) = 0.5
		_DepthFade		("Distance Depth Fade", float) = 0
		_EyeFade		("Eye Depth Fade", float) = 0
		_SparkleDepthFade ("Sparkle Depth Fade", float) = 0
		_EyeCol			("Foam Color", Color) = (1, 1, 1, 0.5)
		_DepthSmooth	("Depth Smoothstep Params", Vector) = (0, 1, 0, 1)
		_SparkleSmooth	("Sparkle Smoothstep Params", Vector) = (0, 1, 0, 1)
		_SparkleReflectionCutoff ("Sparkle Reflection Cutoff", Range(0, 1)) = 0
		_SparkleReflectionCeiling ("Sparkle Reflection Ceiling", Range(0, 1)) = 0
		_Refraction		("Refraction", float) = 1
		_GrabTint		("Grab Tint", Color) = (1, 1, 1, 1)
		_Voronoi1		("Voronoi Cell Size", float) = 1
	}
	CGINCLUDE
	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "../Lib/HueSaturationLightness.cginc"

	sampler2D		_MainTex, _SparkleTex, _VoronoiTex;
	float4 			_MainTex_ST, _SparkleTex_ST, _VoronoiTex_ST;
	samplerCUBE _Cubemap;
	half4			_Color, _Color2;
	half4			_ScrollSpeed, _SparkleScrollSpeed, _CycleSpeed;
	half 			_Parallax;
	half4 			_EyeCol;
	half			_DepthFade;
	half 			_EyeFade;
	half4			_GradColor;
	half4 			_DepthSmooth, _SparkleSmooth;
	half4 			_GrabTint;
	half 			_Refraction;
	half			_SparkleMix;
	half			_SparkleDepthFade;
	half			_Voronoi1;
	half			_SparkleReflectionCutoff, _SparkleReflectionCeiling;
	half _DistanceFactor;	
	sampler2D _SurfaceDistortion;
	float4 _SurfaceDistortion_ST;
	float _SurfaceDistortionAmount;
	
	struct appdata
	{
		float4 vertex	: POSITION;
		half3 color		: COLOR;
		float3 normal 	: NORMAL;
		float4 tangent  : TANGENT;
		half2 uv		: TEXCOORD0;
	};

	struct v2f
	{
		float4 pos			: SV_POSITION;
		half3 color			: COLOR;
		half3 worldNormal	: NORMAL;
		half2 uv			: TEXCOORD0;
		half4 worldPos		: TEXCOORD1;
		float4 grabPos		: TEXCOORD2;
		float4 screenPos	: TEXCOORD3;
		float2 distortUV	: TEXCOORD4;
		UNITY_FOG_COORDS(5)
		half3 normal		: TEXCOORD6;
	};
	v2f vert(appdata v)
	{
		v2f o = (v2f)0;
		UNITY_SETUP_INSTANCE_ID(v);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		UNITY_TRANSFER_INSTANCE_ID(v, o);
		// note: this is in clip space - pre-rasterization but post-squinching into homogeneous space
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		o.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex).xyz;
		// note: this is in view space - space relative to the camera, but pre-squinch.
		// "W in Clip space is the same as View Space Z" so sez some documents.
		o.worldNormal = UnityObjectToWorldNormal(v.normal);

		// we cleverly pack the w coordinate of the world pos with the viewspace depth value. this is used later!
		o.worldPos.w = -UnityObjectToViewPos( v.vertex.xyz ).z;
		o.color = v.color;
		o.grabPos = ComputeGrabScreenPos(o.pos);
		o.screenPos= ComputeScreenPos (o.pos);
		o.distortUV = TRANSFORM_TEX(v.uv, _SurfaceDistortion);
		o.normal= v.normal;

		UNITY_TRANSFER_FOG(o, o.pos);
		return o;
	}
	
	float4 WaterUV(v2f i, half3 viewDir, half2 scale, half4 cycle, half2 scroll, half parallax)
	{
		// scale+cycle are amplitude and frequency for sin waves. (cycle.xy is frequency for one axis, cycle.zw is frequency for the other)
		// the parallax here is rather clever - by dividing the xz by the y here, we get a nice faux wave depth effect without actually manipulating vertices.
		
		// similar idea to polar coordinates.
		// a shadertoy example: https://www.shadertoy.com/view/ltfGD7
		float2 a = parallax * viewDir.xz / viewDir.y;

		// standard time offset stuff.
		float2 uv = i.worldPos.xz * scale * 0.1 + scroll * _Time.x;
		float h = sin(uv.x * cycle.z + _Time.x * cycle.x);
		uv += a * h;

		// we're baking two axes of surface distortion into one offset value.
		// (approximating the offset via a single sin call is good enough and saves on perf)
		// the actual value of sin(1) to six decimal places is 0.841471
		// the actual value of cos(1) to six decimal places is 0.540302
		// so, we're simply hardcoding them in instead of computing them.
    	h = sin(0.841471 * uv.x * cycle.z - 0.540302 * uv.y * cycle.w + _Time.x * cycle.y);

		//surface offset + parallax effect.
    	uv += a * h;
		return float4(uv, a * h);
	}
	
	half4 Sparkle(v2f i, half3 viewDir, half scale, half4 cycle, half2 scroll1, half2 scroll2, half parallax)
	{
		// compensate for the parallax effect and distortion or this will look wrong.
		float2 a = parallax * viewDir.xz / viewDir.y;
		half2 distortSample = (tex2D(_MainTex, i.worldPos.xz).xy * 2 - 1) * _SurfaceDistortionAmount + (scroll2 * _Time.x);

		// we scroll in one direction here...
		float2 uv1 = (i.worldPos.xz + distortSample) * scale * 0.1 + scroll1 * (_Time.x);
		float h1 = sin(i.worldPos * cycle.z + -(_Time.x) * cycle.x);
		uv1 += a * h1;
		
		// ...and our actual second noise is a dynamic noise made of the sparkle texture scrolling on top of itself.
		// when you do this at the right speed, the noise appears to animate. neat trick!
		float2 uv2 = (i.worldPos.xz * _SparkleTex_ST.xy * 0.1 + scroll2 * (_Time.x)) + _SparkleTex_ST.zw;
		float h2 = sin(i.worldPos * cycle.z + -(_Time.x) * cycle.x);
		uv2 += a * h2;
		float2 uv3 = (i.worldPos.xz * _SparkleTex_ST.xy * 0.1 - scroll2 * (_Time.x)) - _SparkleTex_ST.zw;
		float h3 = sin(i.worldPos * cycle.z + -(_Time.x) * cycle.x);
		uv3 += a * h3;

		// sample our voronoi and sparkle samples, and mask the latter with the former. bam. we have a shimmery stylized reflection.
		uv1 *= _VoronoiTex_ST.xy + _VoronoiTex_ST.zw;
		half4 sample1 = tex2D(_VoronoiTex, uv1);
		half4 sample2= tex2D(_SparkleTex, uv2);
		half4 sample3= 1-tex2D(_SparkleTex, uv3);
		half4 avg = abs(sample2.r - sample3.g);
		avg = (avg + sample1) / 2;
		
		return step(_SparkleMix, avg);
	}

	ENDCG
	SubShader
	{
		Tags
		{
			"PreviewType" = "Plane"
			"IgnoreProjector" = "True"
		}
		// our grabpass name is the same one as in NagaiGlass.shader - Unity will cache this internally.
		// otherwise it would do 2 separate grabpasses!
		GrabPass {"_DistortGrabPass"}
		Pass
		{
			Tags 
			{ 
				"LightMode" = "ForwardBase" 
				"RenderType" = "Transparent"
				"Queue" = "Transparent"
			}
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile_fwdbase

			sampler2D 		_DistortGrabPass;
			half 			_GrabMix;

			// we're using the actual depth texture here - depthnormals depth is simply too low-res.
			UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
			uniform float4 _CameraDepthTexture_TexelSize;
			
			half4 frag(v2f i) : SV_Target
			{

				float3 viewDir = _WorldSpaceCameraPos.xyz - i.worldPos.xyz;
				float3 normViewDir= normalize(viewDir);
				
				float3 reflectionDir = reflect(-normViewDir, i.worldNormal);
				float4 envSample = texCUBElod(_Cubemap, float4(reflectionDir, 1));

				// distortion from texture and params
				float4 uv1 = WaterUV(i, normViewDir, _MainTex_ST.xy, _CycleSpeed, _ScrollSpeed.xy, _Parallax);

				
				//d ividing by w coordinate corrects for 3D perspective.
				// LinearEyeDepth takes the depth texture value and converts it into world scaled viewspace depth.
				float2 depthUV = i.grabPos.xy / i.grabPos.w;
				float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture,  depthUV));

				// currently unused - this will let things fade as they sink below the water.
				// keeping this in here for future reference.
				// cool trick - the z coordinate of the grabpass position stores the depth value of the last fragment written there!!
				float distanceDepth = saturate(abs((linearDepth - LinearEyeDepth(i.grabPos.z) ) / ( _DepthFade ) ));
				
				half4 col = _Color;
				
				half4 sparkleSample= Sparkle(i, normViewDir, _Voronoi1, _CycleSpeed, _SparkleScrollSpeed.xy, _SparkleScrollSpeed.zw, _Parallax);
				// here's a trick we use to ensure that the sparkles only reflect certain parts of the cubemap.
				// NOTE: the cubemap supplied to this shader must have a black skybox, this is crucial for it to work.
				// we actually calculate the value of a given fragment in HSV color to control our cutoff.
				// this works surprisingly well, especially if you sample the cubemap at a low lod (which in turn means a smaller texture).
				half3 reflection_hsv= RGBToHSV(envSample);
				sparkleSample *= smoothstep(_SparkleReflectionCutoff, _SparkleReflectionCeiling, reflection_hsv.b);

				// remember when we packed the viewspace depth of this fragment into the w value of worldPos?
				// linearDepth and the viewspace depth are in the same space, so this conversion works.
				float sparkleEyeDepth = saturate(abs(((linearDepth) - i.worldPos.w ) / ( _SparkleDepthFade ) ));
				sparkleEyeDepth = smoothstep(_SparkleSmooth.z, _SparkleSmooth.w, sparkleEyeDepth);

				// hardcoded value to have the sparkles appear/disappear as the "sun" (directional light 0) fades in and out.
				// entirely faked, but it looks good.
				float lightColorFalloff= smoothstep(.35, .85, _LightColor0);

				// sample distortion texture, then
				// sample the grabpass with distortion offset.
				half4 samp1 = tex2D(_MainTex, uv1.xy);
				half2 refract = saturate(samp1.rgb) * 2 - 1;
				i.grabPos.xy += refract * _Refraction;
				half3 bgcolor = tex2Dproj(_DistortGrabPass, i.grabPos);
				
				col.rgb = lerp(col, bgcolor.rgb * _GrabTint.rgb, _GrabMix * (1 - col.a));

				// calcualte foam effect based on depth.
				float eyeDepth = saturate(abs((linearDepth - i.worldPos.w ) / ( _EyeFade ) ));
				eyeDepth = 1 - smoothstep(_DepthSmooth.z, _DepthSmooth.w, eyeDepth);
				half3 foamColor = _EyeCol.rgb *= (1 - _EyeCol.a) + _EyeCol.a;
				col.rgb = lerp(col.rgb, foamColor, eyeDepth);

				// finally, the sparkle color...
				// in addition to the light falloff, we also attempt to only make the sparkles appear as if they would when the sun is bouncing off of them.
				// finally, we taper them off as they go into the distance.
				half3 sparkleColor = lerp(0, sparkleSample, sparkleEyeDepth) * lightColorFalloff * (saturate(dot(_WorldSpaceLightPos0, i.worldNormal) * 2 - 1)) * (1-saturate(length(viewDir)*_DistanceFactor));

				col.rgb += sparkleColor;

				UNITY_APPLY_FOG(i.fogCoord, col);
				
				return fixed4(col.rgb, col.a);
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}