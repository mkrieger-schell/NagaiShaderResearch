// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// after NagaiOutline generates the outlined render target, this shader
// blends it back onto the main render target via a subtractive blend.
// this naturally provides a variety of outline colors for cheap.

Shader "GraphicsLearning/NagaiOutlineBlend"
{
    Properties
    {
        _MainTex("Tex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "PreviewType"="Plane" }
 
        LOD 100
 
        ZWrite Off
        Pass
        {
        	// the appropriate blend for our color-burned outline
        	// https://docs.unity3d.com/Manual/SL-Blend.html
        	// according to these docs, 
        	// "finalValue = sourceFactor * sourceValue operation destinationFactor * destinationValue"
        	// however, note we're using RevSub here - this is a reversed subtraction
            // so, this would be...
        	// finalValue = (destinationValue * 1) - (source pixel * source pixel's alpha)
        	// we force-write our alpha to 0 on black areas that aren't the outline, so they won't subtract anything at all.
            Blend SrcAlpha One
        	BlendOp RevSub
        	
	        CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
	        
            #include "UnityCG.cginc"
            
            uniform sampler2D _MainTex;
 
			struct v2f
			{
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert( appdata_img v )
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = v.texcoord.xy;
				return o;
			}
           
			half4 frag( v2f i ) : COLOR
			{
				half4 col = tex2D(_MainTex, i.uv);
				return col;
			}
            ENDCG
        }
    }
}