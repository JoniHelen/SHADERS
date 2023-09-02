#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

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

TEXTURE2D_X(_NormalMap);
SAMPLER(sampler_NormalMap);

CBUFFER_START(UnityPerMaterial)
float4 _NormalMap_ST;
float4 _Color;
float _MaxDistance;
float _IOR;
float _Scatter;
float _Resolution;
float _MaxSteps;
float _RefineSteps;
float _Thickness;
float _Smoothness;
float _NormalStrength;
float _Depth;
float _Strength;
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
#define RAD_TO_DEG 57.2957795

float2 AngleToDir(float angle) {
    float rad = angle * DEG_TO_RAD;
    return float2(cos(rad), sin(rad));
}

float SizeToFreq(float size) {
    return max((1 - size) * PI, 0.001);
}

void GerstnerWaveAccumulator(inout float3 positionWS, float freq, float s, float2 dir, inout float3 tangentWS, inout float3 bitangentWS) {
    float k = 2 * PI * freq;
    float f = k * (dot(positionWS.xz, dir) - sqrt(9.81 / k) * _Time.y);
    float a = s / k;
    float sf = sin(f), cf = cos(f);
    float ssf = s * sf, scf = s * cf;
    
    tangentWS += float3(1 - dir.x * dir.x * scf, -dir.x * ssf, -dir.x * dir.y * scf);
    bitangentWS += float3(-dir.x * dir.y * scf, -dir.y * ssf, 1 - dir.y * dir.y * scf);
    positionWS += float3(-dir.x * a * sf, a * cf, -dir.y * a * sf);
}

float3 QuadGerstnerWave(float3 position, float4x3 waveParams, out float3 tangentWS, out float3 bitangentWS, out float3 normalWS) {
    tangentWS = 0;
    bitangentWS = 0;
    
    for (int i = 0; i < 4; i++)
        GerstnerWaveAccumulator(position, SizeToFreq(waveParams[i].x), waveParams[i].y, AngleToDir(waveParams[i].z), tangentWS, bitangentWS);
    
    tangentWS = normalize(tangentWS);
    bitangentWS = normalize(bitangentWS);
    normalWS = cross(bitangentWS, tangentWS);
    return position;
}

Varyings Vertex(VertexInput IN) {
    Varyings OUT;
    
    float3 positionWS = TransformObjectToWorld(IN.positionOS);
    
    float3 normalWS;
    float3 tangentWS;
    float3 bitangentWS;
    
    float4x3 waveParams = float4x3(
        _Wave_1_Size, _Wave_1_Steepness, _Wave_1_Angle,
        _Wave_2_Size, _Wave_2_Steepness, _Wave_2_Angle,
        _Wave_3_Size, _Wave_3_Steepness, _Wave_3_Angle,
        _Wave_4_Size, _Wave_4_Steepness, _Wave_4_Angle
    );
    
    #if defined(_SIMULATEWAVES_ON)
    positionWS = QuadGerstnerWave(positionWS, waveParams, tangentWS, bitangentWS, normalWS);
    #else
    VertexNormalInputs inputs = GetVertexNormalInputs(IN.normal, IN.tangent);
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

float3 TransformWorldToScreenPos(float3 pos) {
    float4 HClip = TransformWorldToHClip(pos);
    float3 screenPos = HClip.xyz / HClip.w;
    
    #if UNITY_UV_STARTS_AT_TOP
        screenPos.y *= -1;
    #endif
    
    return float3(screenPos.xy * 0.5 + 0.5, screenPos.z);
}

float3 TransformViewToScreenPos(float3 pos) {
    float4 HClip = TransformWViewToHClip(pos);
    float3 screenPos = HClip.xyz / HClip.w;
    
    #if UNITY_UV_STARTS_AT_TOP
        screenPos.y *= -1;
    #endif
    
    return float3(screenPos.xy * 0.5 + 0.5, screenPos.z);
}

float3 TransformScreenToViewPos(float3 pos)
{
    float4 positionCS = ComputeClipSpacePosition(pos.xy, pos.z);
    float4 result = mul(UNITY_MATRIX_I_V, positionCS);
    return result.xyz / result.w;
}

float DepthDifference(float2 uv, float clipDepth)
{
    float depth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    float surface = clipDepth + _Depth;
    return (depth - surface) * _Strength * 0.1;
}

float GetWaterIncidentBlend(float3 i, float3 n) {
    return clamp(0.002 * exp(0.075 * RAD_TO_DEG * acos(dot(-i, n))), 0, 1);
}

float3 SampleSSR(float3 positionWS, float3 normalWS, float clipW)
{
    float3 positionVS = TransformWorldToView(positionWS);
    float3 normalVS = TransformWorldToViewDir(normalWS);
    
    float3 positionFrom = positionVS;
    float3 viewDir = normalize(positionFrom);
    
    float4x3 rays = float4x3(
        refract(viewDir, normalVS, 1 / (_IOR + _Scatter * 0.01)), // Red
        refract(viewDir, normalVS, 1 / _IOR),                     // Green
        refract(viewDir, normalVS, 1 / (_IOR - _Scatter * 0.01)), // Blue
        reflect(viewDir, normalVS)
    );
    
    float4x3 positionTo = float4x3(
        positionFrom, positionFrom,
        positionFrom, positionFrom
    ) + rays * _MaxDistance;
    
    float2 originalUV = TransformViewToScreenPos(positionFrom).xy;
    
    float2 startFrag = originalUV * _ScreenParams.xy;
    float4x2 endFrag = float4x2(
        TransformViewToScreenPos(positionTo[0]).xy * _ScreenParams.xy,
        TransformViewToScreenPos(positionTo[1]).xy * _ScreenParams.xy,
        TransformViewToScreenPos(positionTo[2]).xy * _ScreenParams.xy,
        TransformViewToScreenPos(positionTo[3]).xy * _ScreenParams.xy
    );
    
    positionTo = abs(positionTo);
    float3 positionFromAbs = abs(positionFrom);
    
    float4x2 delta = float4x2(
        endFrag[0] - startFrag,
        endFrag[1] - startFrag,
        endFrag[2] - startFrag,
        endFrag[3] - startFrag
    );
    
    float4 useX = float4(
        abs(delta[0].x) >= abs(delta[0].y) ? 1 : 0,
        abs(delta[1].x) >= abs(delta[1].y) ? 1 : 0,
        abs(delta[2].x) >= abs(delta[2].y) ? 1 : 0,
        abs(delta[3].x) >= abs(delta[3].y) ? 1 : 0
    );
    
    float4 selectedDelta = float4(
        lerp(abs(delta[0].y), abs(delta[0].x), useX[0]) * _Resolution,
        lerp(abs(delta[1].y), abs(delta[1].x), useX[1]) * _Resolution,
        lerp(abs(delta[2].y), abs(delta[2].x), useX[2]) * _Resolution,
        lerp(abs(delta[3].y), abs(delta[3].x), useX[3]) * _Resolution
    );

    float4x2 increment = float4x2(
        delta[0] / max(selectedDelta[0], 0.001),
        delta[1] / max(selectedDelta[1], 0.001),
        delta[2] / max(selectedDelta[2], 0.001),
        delta[3] / max(selectedDelta[3], 0.001)
    );
    
    float4 search0 = 0;
    float4 search1 = 0;
    
    int4 hit0 = 0;
    int4 hit1 = 0;
    
    float4 viewDistance = abs(positionFrom.z);
    float4 depth = _Thickness;
    
    float4x2 currentFrag = float4x2(
        startFrag, startFrag,
        startFrag, startFrag
    );
    
    float4x2 uv;
    float4 sceneDepth;
    
    int i;
    
    [loop]
    for (i = 0; i < _MaxSteps; i++)
    {
        currentFrag = float4x2(
            currentFrag[0] + increment[0] * (1 - hit0[0]),
            currentFrag[1] + increment[1] * (1 - hit0[1]),
            currentFrag[2] + increment[2] * (1 - hit0[2]),
            currentFrag[3] + increment[3] * (1 - hit0[3])
        );
        
        uv = float4x2(
            currentFrag[0] / _ScreenParams.xy,
            currentFrag[1] / _ScreenParams.xy,
            currentFrag[2] / _ScreenParams.xy,
            currentFrag[3] / _ScreenParams.xy
        );
        
        sceneDepth = float4(
            hit0[0] < 1 ? LinearEyeDepth(SampleSceneDepth(uv[0]), _ZBufferParams) : sceneDepth[0],
            hit0[1] < 1 ? LinearEyeDepth(SampleSceneDepth(uv[1]), _ZBufferParams) : sceneDepth[1],
            hit0[2] < 1 ? LinearEyeDepth(SampleSceneDepth(uv[2]), _ZBufferParams) : sceneDepth[2],
            hit0[3] < 1 ? LinearEyeDepth(SampleSceneDepth(uv[3]), _ZBufferParams) : sceneDepth[3]
        );
        
        search1 = float4(
            lerp((currentFrag[0].y - startFrag.y) / delta[0].y, (currentFrag[0].x - startFrag.x) / delta[0].x, useX[0]),
            lerp((currentFrag[1].y - startFrag.y) / delta[1].y, (currentFrag[1].x - startFrag.x) / delta[1].x, useX[1]),
            lerp((currentFrag[2].y - startFrag.y) / delta[2].y, (currentFrag[2].x - startFrag.x) / delta[2].x, useX[2]),
            lerp((currentFrag[3].y - startFrag.y) / delta[3].y, (currentFrag[3].x - startFrag.x) / delta[3].x, useX[3])
        );
        
        search1 = clamp(search1, 0.0, 1.0);
        
        viewDistance = float4(
            positionFromAbs.z * positionTo[0].z / lerp(positionTo[0].z, positionFromAbs.z, search1[0]),
            positionFromAbs.z * positionTo[1].z / lerp(positionTo[1].z, positionFromAbs.z, search1[1]),
            positionFromAbs.z * positionTo[2].z / lerp(positionTo[2].z, positionFromAbs.z, search1[2]),
            positionFromAbs.z * positionTo[3].z / lerp(positionTo[3].z, positionFromAbs.z, search1[3])
        );
        
        depth = sceneDepth - viewDistance;
        
        hit0 = float4(
            (depth[0] > 0 && depth[0] < _Thickness) || hit0[0] != 0 || i >= selectedDelta[0] ? 1 : 0,
            (depth[1] > 0 && depth[1] < _Thickness) || hit0[1] != 0 || i >= selectedDelta[1] ? 1 : 0,
            (depth[2] > 0 && depth[2] < _Thickness) || hit0[2] != 0 || i >= selectedDelta[2] ? 1 : 0,
            (depth[3] > 0 && depth[3] < _Thickness) || hit0[3] != 0 || i >= selectedDelta[3] ? 1 : 0
        );
    
        search0 = float4(
            hit0[0] != 1 ? search1[0] : search0[0],
            hit0[1] != 1 ? search1[1] : search0[1],
            hit0[2] != 1 ? search1[2] : search0[2],
            hit0[3] != 1 ? search1[3] : search0[3]
        );
        
        if (hit0[0] != 0 && hit0[1] != 0 && hit0[2] != 0 && hit0[3] != 0)
            break;
    }
    
    search1 = search0 + ((search1 - search0) / 2);
    
    [unroll(20)]
    for (i = 0; i < _RefineSteps; i++)
    {
        currentFrag = float4x2(
            lerp(startFrag, endFrag[0], search1[0]),
            lerp(startFrag, endFrag[1], search1[1]),
            lerp(startFrag, endFrag[2], search1[2]),
            lerp(startFrag, endFrag[3], search1[3])
        );
        
        uv = float4x2(
            currentFrag[0] / _ScreenParams.xy,
            currentFrag[1] / _ScreenParams.xy,
            currentFrag[2] / _ScreenParams.xy,
            currentFrag[3] / _ScreenParams.xy
        );
        
        sceneDepth = float4(
            LinearEyeDepth(SampleSceneDepth(uv[0]), _ZBufferParams),
            LinearEyeDepth(SampleSceneDepth(uv[1]), _ZBufferParams),
            LinearEyeDepth(SampleSceneDepth(uv[2]), _ZBufferParams),
            LinearEyeDepth(SampleSceneDepth(uv[3]), _ZBufferParams)
        );
        
        viewDistance = float4(
            positionFromAbs.z * positionTo[0].z / lerp(positionTo[0].z, positionFromAbs.z, search1[0]),
            positionFromAbs.z * positionTo[1].z / lerp(positionTo[1].z, positionFromAbs.z, search1[1]),
            positionFromAbs.z * positionTo[2].z / lerp(positionTo[2].z, positionFromAbs.z, search1[2]),
            positionFromAbs.z * positionTo[3].z / lerp(positionTo[3].z, positionFromAbs.z, search1[3])
        );
        
        depth = sceneDepth - viewDistance;
        
        hit1 = float4(
            (depth[0] > 0 && depth[0] < _Thickness) || hit1[0] != 0 ? 1 : 0,
            (depth[1] > 0 && depth[1] < _Thickness) || hit1[1] != 0 ? 1 : 0,
            (depth[2] > 0 && depth[2] < _Thickness) || hit1[2] != 0 ? 1 : 0,
            (depth[3] > 0 && depth[3] < _Thickness) || hit1[3] != 0 ? 1 : 0
        );
    
        float4 temp = search1;
    
        search1 = float4(
            (hit1[0] != 0 ? search0[0] : search1[0]) + ((search1[0] - search0[0]) / 2),
            (hit1[1] != 0 ? search0[1] : search1[1]) + ((search1[1] - search0[1]) / 2),
            (hit1[2] != 0 ? search0[2] : search1[2]) + ((search1[2] - search0[2]) / 2),
            (hit1[3] != 0 ? search0[3] : search1[3]) + ((search1[3] - search0[3]) / 2)
        );
    
        search0 = float4(
            hit1[0] != 1 ? temp[0] : search0[0],
            hit1[1] != 1 ? temp[1] : search0[1],
            hit1[2] != 1 ? temp[2] : search0[2],
            hit1[3] != 1 ? temp[3] : search0[3]
        );
    }

    float4 visibility = hit1 * float4(
        1 - max(dot(-viewDir, rays[0]), 0),
        1 - max(dot(-viewDir, rays[1]), 0),
        1 - max(dot(-viewDir, rays[2]), 0),
        (1 - max(dot(-viewDir, rays[3]), 0)) * GetWaterIncidentBlend(viewDir, normalVS)
    );
    
    visibility = clamp(visibility, 0, 1);
    
    uv = float4x2(
        lerp(originalUV, uv[0], visibility[0]),
        lerp(originalUV, uv[1], visibility[1]),
        lerp(originalUV, uv[2], visibility[2]),
        uv[3]
    );
    
    float3 refractedColor = float3(
        SampleSceneColor(uv[0]).r,
        SampleSceneColor(uv[1]).g,
        SampleSceneColor(uv[2]).b
    );
    refractedColor = lerp(refractedColor, _Color.rgb, clamp(DepthDifference(uv[1], clipW), 0, 0.3));
    
    float3 reflectedColor = SampleSceneColor(uv[3]);
    
    return lerp(refractedColor, reflectedColor, visibility[3]);
}

float3 SampleFakeSSR(float3 positionWS, float3 viewDirWS, float3 normalWS, float clipW)
{
    float3 refractedRayR = refract(viewDirWS, normalWS, 1 / (_IOR + _Scatter));
    float3 refractedRayG = refract(viewDirWS, normalWS, 1 / _IOR);
    float3 refractedRayB = refract(viewDirWS, normalWS, 1 / (_IOR - _Scatter));
    
    float2 originalUV = TransformWorldToScreenPos(positionWS).xy;
    float2 refractedUVR = TransformWorldToScreenPos(positionWS + refractedRayR * 3).xy;
    float2 refractedUVG = TransformWorldToScreenPos(positionWS + refractedRayG * 3).xy;
    float2 refractedUVB = TransformWorldToScreenPos(positionWS + refractedRayB * 3).xy;

    float2 uvDeltaR = refractedUVR - originalUV;
    float2 uvDeltaG = refractedUVG - originalUV;
    float2 uvDeltaB = refractedUVB - originalUV;
    
    uvDeltaR *= saturate(DepthDifference(originalUV + uvDeltaR, clipW));
    uvDeltaG *= saturate(DepthDifference(originalUV + uvDeltaG, clipW));
    uvDeltaB *= saturate(DepthDifference(originalUV + uvDeltaB, clipW));
    
    float3 refractedColor = float3(
        SampleSceneColor(originalUV + uvDeltaR).r,
        SampleSceneColor(originalUV + uvDeltaG).g,
        SampleSceneColor(originalUV + uvDeltaB).b
    );
    
    return lerp(refractedColor, _Color.rgb, clamp(DepthDifference(originalUV + uvDeltaG, clipW), 0, 0.3));
}

float3 NormalBlend(float3 A, float3 B) {
    float3 t = A.xyz + float3(0.0, 0.0, 1.0);
    float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
    return (t / t.z) * dot(t, u) - u;
}

float3 NormalStrength(float3 In, float Strength) {
    return float3(In.rg * Strength, lerp(1, In.b, saturate(Strength)));
}

float4 Fragment(Varyings IN) : SV_Target {
    
    float3 texNormal1 = UnpackNormal(SAMPLE_TEXTURE2D_X(_NormalMap, sampler_NormalMap, _NormalMap_ST.xy * IN.uv + _Time.y * 0.1));
    float3 texNormal2 = UnpackNormal(SAMPLE_TEXTURE2D_X(_NormalMap, sampler_NormalMap, _NormalMap_ST.xy * 0.5 * IN.uv - _Time.y * 0.1 * float2(1, -1)));
    texNormal2 = NormalStrength(NormalBlend(texNormal1, texNormal2), _NormalStrength);
    float3 normalWS = normalize(TransformTangentToWorld(texNormal2, half3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS), true));
    
    float3 viewDir = GetWorldSpaceNormalizeViewDir(IN.positionWS);
    
    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = IN.positionWS;
    lightingInput.positionCS = IN.positionHCS;
    lightingInput.normalWS = normalWS;
    lightingInput.viewDirectionWS = viewDir;
    
    SurfaceData surfaceInput = (SurfaceData)0;
    surfaceInput.albedo = 0;
    #if defined(_SSR_ON)
    surfaceInput.emission = SampleSSR(IN.positionWS, normalWS, IN.positionHCS.w);
    #else
    surfaceInput.emission = SampleFakeSSR(IN.positionWS, viewDir, normalWS, IN.positionHCS.w);
    #endif
    surfaceInput.alpha = 1;
    surfaceInput.smoothness = _Smoothness;

    return UniversalFragmentPBR(lightingInput, surfaceInput);
}