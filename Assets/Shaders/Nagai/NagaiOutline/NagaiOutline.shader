// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// this outline shader entirely circumnavigates the post-processing stack and is much more performant as a result.
// uses a modified Roberts Cross implementation in conjunction with NagaiDepthNormals and variables in supported materials
// to provide outlining with per-material customization.
// the use of depthnormals sacrifices accuracy in the name of speed, and due to its reliance on shader replacement
// is what makes the per-material outline customziation possible.

// OutlineCamera.cs sets up the appropriate blit commandbuffers.

Shader "GraphicsLearning/NagaiOutline"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
    	_DepthSensitivity("Depth Sensitivity", float) = 1
    	_NormalsSensitivity("Normals Sensitivity", float) = 1
    	_BgFade("Background Fade", float) = 1.0
    	_BgColor("Background Color", color) = (1,1,1,1)
	    _SampleDistance("Edge Width", Range(0,10)) = 1
    	_EdgesColor("Edge Color", color) = (0,0,0,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
        LOD 100

        Pass
        {
	        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv[5] : TEXCOORD0;
            	float4 uvAux : TEXCOORD5;
            	float4 worldPos: TEXCOORD6;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half4 _MainTex_TexelSize;
	        
            half _DepthSensitivity;
            half _NormalsSensitivity;
			half4 _BgColor;
			half _BgFade;
			half _SampleDistance;
			half4 _EdgesColor;
	        float4x4 _CameraMV;
	        sampler2D _CameraDepthNormalsTexture;

	        inline half NormalsTest(half4 crossSample1, half4 crossSample2)
	        {
            	// since we are only comparing change here, we don't actually have to decode the normal.
	        	// the normal information is partially encoded in the x and y values of the depthnormals texture,
	        	// which is all we need.
            	half2 diff = abs(crossSample1.xy - crossSample2.xy);
            	half isSameNormal = 1 - step(0.1, diff.x + diff.y) * _NormalsSensitivity;
            	return isSameNormal;
	        }

	        inline half DepthTest(half4 crossSample1, half4 crossSample2)
            {
	        	// standard Roberts Cross depth test. we do need to decode the depth for this.
	        	// note that depthnormals depth is far lower resolution than the dedicated depth texture.
            	half sampleDepth1 = DecodeFloatRG (crossSample1.zw);
				half sampleDepth2 = DecodeFloatRG (crossSample2.zw);
            	half zdiff = abs(sampleDepth1-sampleDepth2);
				half isSameDepth = 1-(saturate(zdiff) * _DepthSensitivity);
            	return isSameDepth;
            }

            v2f vert (appdata v)
            {
				v2f o;

            	o.vertex = UnityObjectToClipPos(v.vertex);
            	o.worldPos= mul(unity_ObjectToWorld, v.vertex);

            	o.uv[0]= TRANSFORM_TEX(v.uv, _MainTex);

				o.uv[1] = o.uv[0] + _MainTex_TexelSize.xy * half2(1,1) * _SampleDistance;
				o.uv[2] = o.uv[0] + _MainTex_TexelSize.xy * half2(-1,-1) * _SampleDistance;
				o.uv[3] = o.uv[0] + _MainTex_TexelSize.xy * half2(-1,1) * _SampleDistance;
				o.uv[4] = o.uv[0] + _MainTex_TexelSize.xy * half2(1,-1) * _SampleDistance;

				return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
            	float4 color = tex2D(_MainTex, i.uv[0]);
            	// we only need normal for the decode macro, we don't actually use it here.
				float3 normal;
            	float depth= 0;
            	DecodeDepthNormal(color, depth, normal);
            	
				half4 sample1 = tex2D(_MainTex, i.uv[1].xy);
				half4 sample2 = tex2D(_MainTex, i.uv[2].xy);
				half4 sample3 = tex2D(_MainTex, i.uv[3].xy);
				half4 sample4 = tex2D(_MainTex, i.uv[4].xy);

				half edge = 1.0;

            	// we do bespoke testing for normal and depth similarity on neighboring samples and average them out.
            	edge *= (NormalsTest(sample1,sample2) + DepthTest(sample1,sample2))/2;
            	edge *= (NormalsTest(sample3,sample4) + DepthTest(sample3,sample4))/2;

            	// note that we lerp to a color with 0 alpha here; this is important once we blend the outline back onto the render target.
				color = lerp(_EdgesColor, half4(1,1,1,0), edge);
            	color = lerp(color, half4(1,1,1,0), ((depth * _BgFade)));

            	return color;
            }
	        
            ENDCG
        }
    }
}
