#include "UnityCG.cginc"

sampler2D _MainTex;
sampler2D _BaseTex;
float4 _MainTex_ST;
float4 _BaseTex_ST;
float4 _MainTex_TexelSize;
float4 _BaseTex_TexelSize;

// The soft curve.
// _Curve.x : Threshold
// _Curve.y : SoftThreshold
float3 _Curve;

// Control the up sampler field, must be positive
// The value is 1 means idle sample. Greater means sample larger area.
float _SamplerScale;

struct MutiVertex
{
    float4 vertex : POSITION;
    float2 uvMain : TEXCOORD0;
    float2 uvBase : TEXCOORD1;
};


// Clamp HDR value to a safe range
half3 SafeHDR(half3 c) { return min(c, 65504.0); }
half4 SafeHDR(half4 c) { return min(c, 65504.0); }

// Get the median value in 3 value
half3 Median3(half3 a, half3 b, half3 c)
{
    return a + b + c - max(max(a, b), c) - min(min(a, b), c);
}

// Get the max value in 3 value
half Max3(half a, half b, half c)
{
    return max(max(a, b), c);
}

// Brightness Function
half Brightness(half3 c)
{
    return Max3(c.r, c.g, c.b);
}


v2f_img vert(appdata_img i)
{
    v2f_img o;

    o.pos = UnityObjectToClipPos(i.vertex);
    o.uv = UnityStereoScreenSpaceUVAdjust(i.texcoord, _MainTex_ST);

    return o;
}

MutiVertex vert_muti(appdata_img i)
{
    MutiVertex o;

    o.vertex = UnityObjectToClipPos(i.vertex);
    o.uvMain = UnityStereoScreenSpaceUVAdjust(i.texcoord, _MainTex_ST);
    o.uvBase = o.uvMain;

    return o;
}

half4 frag_prefilter(v2f_img i) : SV_Target
{
    float2 uv = i.uv;

#if ANTI_FLICKER
    float3 d = _MainTex_TexelSize.xyx * float3(1, 1, 0);
    half4 s0 = SafeHDR(tex2D(_MainTex, uv));
    half3 s1 = SafeHDR(tex2D(_MainTex, uv - d.xz)).rgb;
    half3 s2 = SafeHDR(tex2D(_MainTex, uv + d.xz)).rgb;
    half3 s3 = SafeHDR(tex2D(_MainTex, uv - d.yz)).rgb;
    half3 s4 = SafeHDR(tex2D(_MainTex, uv + d.yz)).rgb;
    half3 c = Median3(Median3(s0.rgb, s1, s2), s3, s4); // Roughly get the midient of s1, s2, s3, s4
#else
    half4 s0 = SafeHDR(tex2D(_MainTex, uv));
    half3 c = s0.rgb;
#endif

#if UNITY_COLORSPACE_GAMMA
    c = GammaToLinearSpace(c);
#endif

    half bright = Brightness(c);

    half knee = _Curve.x * _Curve.y;
    half soft = bright - (_Curve.x - knee);
    soft = clamp(soft, 0, 2 * knee);
    soft = soft * soft * 1 / (4 * knee + 0.00001);

    c *= max(soft, bright - _Curve.x) / max(bright, 1e-5);

    return half4(c, 0);
}

half4 frag_downsample(v2f_img i) : SV_Target
{
    float4 d = _MainTex_TexelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0);

    half3 s;

    // Box filter
    half3 s1 = tex2D(_MainTex, i.uv + d.xy).rgb;
    half3 s2 = tex2D(_MainTex, i.uv + d.zy).rgb;
    half3 s3 = tex2D(_MainTex, i.uv + d.xw).rgb;
    half3 s4 = tex2D(_MainTex, i.uv + d.zw).rgb;

#if ANTI_FLICKER
    // ref : http://graphicrants.blogspot.com.br/2013/12/tone-mapping.html
    // Karis's anti-flicker tonemapping
    half s1w = 1.0 / (Brightness(s1) + 1.0);
    half s2w = 1.0 / (Brightness(s2) + 1.0);
    half s3w = 1.0 / (Brightness(s3) + 1.0);
    half s4w = 1.0 / (Brightness(s4) + 1.0);
    s = (s1 * s1w + s2 * s2w + s3 * s3w + s4 * s4w) / (s1w + s2w + s3w + s4w);
#else
    s = (s1 + s2 + s3 + s4) * 0.25;
#endif 
    
    return half4(s, 1.0);
}

half4 frag_upsample(MutiVertex i) : SV_Target
{
    half3 base = tex2D(_BaseTex, i.uvBase);

    float4 d = _MainTex_TexelSize.xyxy * float4(1.0, 1.0, -1.0, 0) * _SamplerScale;

    // 9-tap bilinear unsampler(tent filter)
    half3 s;
    s = tex2D(_MainTex, i.uvMain - d.xy);
    s += tex2D(_MainTex, i.uvMain - d.wy) * 2.0;
    s += tex2D(_MainTex, i.uvMain - d.zy);

    s += tex2D(_MainTex, i.uvMain + d.zw) * 2.0;
    s += tex2D(_MainTex, i.uvMain) * 4.0;
    s += tex2D(_MainTex, i.uvMain + d.xw) * 2.0;

    s += tex2D(_MainTex, i.uvMain + d.zy);
    s += tex2D(_MainTex, i.uvMain + d.wy) * 2.0;
    s += tex2D(_MainTex, i.uvMain + d.xy);
 
    return half4(base + s * 1.0 / 16.0, 1);
}