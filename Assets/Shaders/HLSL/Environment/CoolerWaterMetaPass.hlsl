#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

struct VertexInput {
    float3 positionOS : POSITION;
    float2 uv0 :TEXCOORD0;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
    float2 uv :TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 tangentWS : TEXCOORD2;
    float3 bitangentWS : TEXCOORD3;
    float3 positionWS : TEXCOORD4;
};

struct ColorOutput {
    float4 positionWS : COLOR0;
    float4 positionHCS : COLOR1;
    float4 normalWS : COLOR2;
};

TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);

CBUFFER_START(UnityPerMaterial)
float4 _NormalMap_ST;
float _NormalStrength;
float _Wave_1_Size;
float _Wave_1_Steepness;
float _Wave_1_Angle;
float _Wave_2_Size;
float _Wave_2_Steepness;
float _Wave_2_Angle;
float _Wave_3_Size;
float _Wave_3_Steepness;
float _Wave_3_Angle;
float _Wave_4_Size;
float _Wave_4_Steepness;
float _Wave_4_Angle;
CBUFFER_END

#define DEG_TO_RAD 0.0174532925

float2 AngleToDir(const float angle) {
    const float rad = angle * DEG_TO_RAD;
    return float2(cos(rad), sin(rad));
}

float SizeToFreq(const float size) {
    return max((1 - size) * PI, 0.001);
}

// Uses the default trochoidal wave function with relative speed and wave sharpness
void GerstnerWaveAccumulator(inout float3 positionWS, const float freq, const float s, const float2 dir, inout float3 tangentWS, inout float3 bitangentWS) {
    const float k = 2 * PI * freq;
    const float f = k * (dot(positionWS.xz, dir) - sqrt(9.81 / k) * _Time.y);
    const float a = s / k;
    const float sf = sin(f), cf = cos(f);
    const float ssf = s * sf, scf = s * cf;
    
    tangentWS += float3(1 - dir.x * dir.x * scf, -dir.x * ssf, -dir.x * dir.y * scf);
    bitangentWS += float3(-dir.x * dir.y * scf, -dir.y * ssf, 1 - dir.y * dir.y * scf);
    positionWS += float3(-dir.x * a * sf, a * cf, -dir.y * a * sf);
}

// Accumulator for four waves
float3 QuadGerstnerWave(float3 position, const float4x3 waveParams, out float3 tangentWS, out float3 bitangentWS, out float3 normalWS) {
    tangentWS = 0;
    bitangentWS = 0;
    
    for (int i = 0; i < 4; i++)
        GerstnerWaveAccumulator(position, SizeToFreq(waveParams[i].x), waveParams[i].y, AngleToDir(waveParams[i].z), tangentWS, bitangentWS);
    
    tangentWS = normalize(tangentWS);
    bitangentWS = normalize(bitangentWS);
    normalWS = cross(bitangentWS, tangentWS);
    return position;
}

Varyings Vertex(const VertexInput IN) {
    Varyings OUT;
    
    float3 positionWS = TransformObjectToWorld(IN.positionOS);
    float3 normalWS;
    float3 tangentWS;
    float3 bitangentWS;

    // Packed wave parameters
    const float4x3 waveParams = float4x3(
        _Wave_1_Size, _Wave_1_Steepness, _Wave_1_Angle,
        _Wave_2_Size, _Wave_2_Steepness, _Wave_2_Angle,
        _Wave_3_Size, _Wave_3_Steepness, _Wave_3_Angle,
        _Wave_4_Size, _Wave_4_Steepness, _Wave_4_Angle
    );

    // Wave simulation using trochoidal waves
    #if defined(_SIMULATEWAVES_ON)
    positionWS = QuadGerstnerWave(positionWS, waveParams, tangentWS, bitangentWS, normalWS);
    #else
    const VertexNormalInputs inputs = GetVertexNormalInputs(IN.normal, IN.tangent);
    normalWS = inputs.normalWS;
    tangentWS = inputs.tangentWS;
    bitangentWS = inputs.bitangentWS;
    #endif
    
    OUT.positionHCS = TransformWorldToHClip(positionWS);
    OUT.positionWS = positionWS;
    OUT.uv = IN.uv0;

    OUT.normalWS = normalWS;
    OUT.tangentWS = tangentWS;
    OUT.bitangentWS = bitangentWS;

    return OUT;
}

float3 NormalBlend(const float3 A, const float3 B) {
    const float3 t = A.xyz + float3(0.0, 0.0, 1.0);
    const float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
    return (t / t.z) * dot(t, u) - u;
}

float3 NormalStrength(const float3 In, const float Strength) {
    return float3(In.rg * Strength, lerp(1, In.b, saturate(Strength)));
}

ColorOutput Fragment(const Varyings IN) {
    // Sample Normal texture
    const float3 texNormal1 =
        UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, _NormalMap_ST.xy * IN.uv + _Time.y * 0.1));
    float3 texNormal2 =
        UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, _NormalMap_ST.xy * 0.5 * IN.uv - _Time.y * 0.1 * float2(1, -1)));
    
    texNormal2 = NormalStrength(NormalBlend(texNormal1, texNormal2), _NormalStrength);

    // Compute world space normal from texture data
    const float3 normalWS =
        normalize(TransformTangentToWorld(texNormal2, half3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS), true));

    ColorOutput OUT;
    OUT.positionWS = float4(IN.positionWS, 0);
    OUT.positionHCS = IN.positionHCS;
    OUT.normalWS = float4(normalWS, 1);
    return OUT;
}