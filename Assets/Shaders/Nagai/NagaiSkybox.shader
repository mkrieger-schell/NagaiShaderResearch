// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

Shader "GraphicsLearning/NagaiSkybox"
{
    Properties
    {
        _TopColor("Top Color", color) = (0,0,0,1)
        _MiddleColor("Middle Color", color) = (.5, .5, .5, 1)
        _BottomColor("Bottom Color", color) = (1,1,1,1)
        _GradientStart("Gradient Start", float) = 0
        _GradientMid("Gradient Middle", float) = .5
        _GradientEnd("Gradient End", float) = 1
        _MainTex("Texture", 2D) = "white" {}
        _TexScale("Texture Scale", float) = 1
        _NoiseColor("Noise Color", color) = (0,0,0,1)
        _HorizonTextureHeight("Horizon Texture Height", float) = 1
        _Up ("Up", Vector) = (0, 1, 0)
		_Exp ("Exp", Range(0, 16)) = 1
        _Mod ("Mod", float) = 0
    }
    SubShader
    {
        // this is the boilerplate for a skybox material.
        // note the "preview type" tag - this affects your material preview.
        // you can also use "plane" for sprite shaders, etc.
        Tags {
            "RenderType"="Transparent"
            "Queue"="Geometry"
            "PreviewType"="Skybox"
        }
        // we don't have to write to depth, and this is always in the background.
        ZWrite off
        Cull off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos= mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            half4 _BottomColor;
            half4 _MiddleColor;
            half4 _TopColor;
            half _GradientStart;
            half _GradientMid;
            half _GradientEnd;

            float3 _Up;
			float _Exp;
            float _Mod;

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half _TexScale;
            half4 _NoiseColor;
            half _HorizonTextureHeight;

            fixed4 frag (v2f i) : SV_Target
            {
                half blend1= smoothstep(
                    _GradientStart,
                    _GradientMid,
                    i.uv.y
                    );
                half4 col1= lerp(_BottomColor, _MiddleColor, blend1);
                
                half blend2= smoothstep(
                    _GradientMid,
                    _GradientEnd,
                    i.uv.y);
                
                half4 col2= lerp(_MiddleColor, _TopColor, blend2);

                float3 texcoord = normalize(i.uv);
                texcoord = texcoord * .5 + .5;
				float3 up = normalize(_Up);
				float d = dot(texcoord, up);
				float s = sign(d);
				half4 col = half4(lerp(col1.rgb, col2.rgb, (blend1 + blend2) / 2), 1);
                
                // we are essentially re-calculating our UVs along the unit sphere here.
                // the arctangent of normalized x/y (or atan2 x, z) roughly maps longitudinally.
                // note: if we just took the arctangent of x here, our uvs would flip on the negative z side of the unit sphere.
                // the arcsin of normalized y roughly maps latitudinally.
                // magic!!!
                float4 unitSphere = normalize(i.worldPos);
                float2 uv;
                uv.y= asin(unitSphere.y);
                uv.x= atan2(unitSphere.x, unitSphere.z);
                
                half4 sample = tex2D(_MainTex, uv * _TexScale);
                
                sample = sample * _NoiseColor;

                // approximation of an overlay-style blend for bgd texture.
                // this provides a little noise on top of our solid color.
                // yes, this does have a conditional, which are often subjects of scrutiny,
                // but it's right at the end of our shader, so it's not a particularly costly one.
                col.rgb = col.rgb < 0.5 ? (2.0 * col.rgb * sample.rgb) : (1 - 2 * (1 - col.rgb) * (1 - col.rgb));
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                
                return col;
            }
            ENDCG
        }
    }
}
