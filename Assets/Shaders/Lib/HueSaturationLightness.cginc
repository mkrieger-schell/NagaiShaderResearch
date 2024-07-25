// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// adapted from HSV conversion code released by Sam Hocevar for lolengine
// released under the public domain, humorously named "WTFPL License"
// code snippet adapted from comments of: https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl
// license info: https://github.com/lolengine/lolengine?tab=WTFPL-1-ov-file#readme

#ifndef HSL_LIBRARY_INCLUDED
#define HSL_LIBRARY_INCLUDED


float3 RGBToHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp( float4( c.bg, K.wz ), float4( c.gb, K.xy ), step( c.b, c.g ) );
    float4 q = lerp( float4( p.xyw, c.r ), float4( c.r, p.yzx ), step( p.x, c.r ) );
    float d = q.x - min( q.w, q.y );
    float e = 1.0e-10;
    return float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

#endif