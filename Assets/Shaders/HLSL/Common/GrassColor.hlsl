#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Hashes.hlsl"

struct Gradient {
    int type;
    int colorsLength;
    int alphasLength;
    float4 colors[8];
    float2 alphas[8];
};

Gradient NewGradient(int type, int colorsLength, int alphasLength,
    float4 colors0, float4 colors1, float4 colors2, float4 colors3, float4 colors4, float4 colors5, float4 colors6, float4 colors7,
    float2 alphas0, float2 alphas1, float2 alphas2, float2 alphas3, float2 alphas4, float2 alphas5, float2 alphas6, float2 alphas7)
{
    Gradient output =
    {
        type, colorsLength, alphasLength,
        {colors0, colors1, colors2, colors3, colors4, colors5, colors6, colors7},
        {alphas0, alphas1, alphas2, alphas3, alphas4, alphas5, alphas6, alphas7}
    };
    return output;
}

float2 GradientNoiseDeterministicDir(float2 p) {
    float x;
    Hash_Tchou_2_1_float(p, x);
    return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
}

float GradientNoiseDeterministic(float2 UV, float3 Scale) {
    float2 p = UV * Scale;
    float2 ip = floor(p);
    float2 fp = frac(p);
    float d00 = dot(GradientNoiseDeterministicDir(ip), fp);
    float d01 = dot(GradientNoiseDeterministicDir(ip + float2(0, 1)), fp - float2(0, 1));
    float d10 = dot(GradientNoiseDeterministicDir(ip + float2(1, 0)), fp - float2(1, 0));
    float d11 = dot(GradientNoiseDeterministicDir(ip + float2(1, 1)), fp - float2(1, 1));
    fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
    return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x) + 0.5;
}

float4 SampleGradient(Gradient Gradient, float Time)
{
    float3 color = Gradient.colors[0].rgb;
    [unroll]
    for (int c = 1; c < Gradient.colorsLength; c++)
    {
        float colorPos = saturate((Time - Gradient.colors[c - 1].w) / (Gradient.colors[c].w - Gradient.colors[c - 1].w)) * step(c, Gradient.colorsLength - 1);
        color = lerp(color, Gradient.colors[c].rgb, lerp(colorPos, step(0.01, colorPos), Gradient.type));
    }
    #ifdef UNITY_COLORSPACE_GAMMA
    color = LinearToSRGB(color);
    #endif
    float alpha = Gradient.alphas[0].x;
    [unroll]
    for (int a = 1; a < Gradient.alphasLength; a++)
    {
        float alphaPos = saturate((Time - Gradient.alphas[a - 1].y) / (Gradient.alphas[a].y - Gradient.alphas[a - 1].y)) * step(a, Gradient.alphasLength - 1);
        alpha = lerp(alpha, Gradient.alphas[a].x, lerp(alphaPos, step(0.01, alphaPos), Gradient.type));
    }
    return float4(color, alpha);
}

half3 GrassColorWS(float noiseScale, float3 positionWS) {
    Gradient gradient = NewGradient(0, 3, 2,
        float4(0.05150566, 0.1037736, 0, 0), float4(0.02745098, 0.08627451, 0, 0.5), float4(0.09604739, 0.1803922, 0, 1),
        0, 0, 0, 0, 0,
        float2(1, 0), float2(1, 1),
        0, 0, 0, 0, 0, 0
    );
    
    float noise0 = GradientNoiseDeterministic(positionWS.xz, noiseScale);
    float noise1 = GradientNoiseDeterministic(positionWS.xz, noiseScale * 2);
    float noise2 = GradientNoiseDeterministic(positionWS.xz, noiseScale * 0.5);

    float combined = (noise0 + noise1 + noise2) / 3.0;

    return SampleGradient(gradient, combined).xyz;
}