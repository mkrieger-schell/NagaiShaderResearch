// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// more or less a grabpass demo. 
// a grabpass is builtin's way of getting the color drawn behind the object.
// very useful for transparency effects.

Shader "GraphicsLearning/NagaiGlass"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Tint ("Tint", color) = (1,1,1,1)
        _Refraction("Refraction", float) = 1
        _RefractionTexture("Refraction Texture", 2D) = "white" {}
        _GrabMix("Grab Mix", Range(0,1)) = .5
    }
    CGINCLUDE
        #include "UnityCG.cginc"

        half _Refraction;
        sampler2D _MainTex;
        float4 _MainTex_ST;
        sampler2D _DistortGrabPass;
        half _GrabMix;
        half4 _Tint;
        sampler2D _RefractionTexture;
        float4 _RefractionTexture_ST;
    
    ENDCG
    SubShader
    {
        Tags
        { 
            "RenderType"="Transparent"
            "Queue"="Transparent" 
            "PreviewType"="Plane"
        }
        // Unity caches the pass of this name; if you can, reuse it as much as possible.
        // otherwise, you may end up with tons of unnecessary grab passes internally.
        GrabPass {"_DistortGrabPass"}
        LOD 100

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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 grabPos : TEXCOORD2;
                float2 refractTexUV : TEXCOORD3;
            };


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                // special screen pos computation for grabpasses.
                o.grabPos= ComputeGrabScreenPos(o.vertex);
                o.refractTexUV= TRANSFORM_TEX(v.uv, _RefractionTexture);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float4 refrac = tex2D(_RefractionTexture, i.refractTexUV) * 2 - 1;
                i.grabPos.xy += refrac.xy * _Refraction;
                // sample the grabpass to get the color behind the glass.
                // since it is uv offset by the refraction texture we sampled above,
                // it will appear to be distorted, like a frosted pane of glass.
                half4 bgColor = tex2Dproj(_DistortGrabPass, i.grabPos);
                // controls opacity of the glass.
                col.rgb= lerp(col.rgb, bgColor.rgb, _GrabMix);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
