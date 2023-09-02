#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_PositionWS);
SAMPLER(sampler_PositionWS);

TEXTURE2D(_PositionHCS);
SAMPLER(sampler_PositionHCS);

TEXTURE2D(_NormalWS);
SAMPLER(sampler_NormalWS);

TEXTURE2D(_DepthMipChain);

RW_TEXTURE2D(float4, _Light) : register(u2);

StructuredBuffer<int4> _DepthPyramidOffsetsAndLimits;

#define SSR_TRACE_EPS 0.000488281f // 2^-11, should be good up to 4K

CBUFFER_START(UnityPerMaterial)
float4 _NormalMap_ST;
int _MipCount;
float _MaxDistance;
float _IOR;
float _Scatter;
float _Resolution;
float _MaxSteps;
float _RefineSteps;
float _Depth;
float _Strength;
float _Thickness;
CBUFFER_END

#define RAD_TO_DEG 57.2957795

float3 TransformWorldToScreenPos(const float3 pos) {
    float4 HClip = mul(UNITY_MATRIX_VP, float4(pos, 1.0));
    float3 screenPos = HClip.xyz / HClip.w;
    
    #if UNITY_UV_STARTS_AT_TOP
        screenPos.y *= -1;
    #endif
    
    return float3(screenPos.xy * 0.5 + 0.5, Linear01Depth(screenPos.z, _ZBufferParams));
}

float3 TransformViewToScreenPos(const float3 pos) {
    float4 HClip = mul(UNITY_MATRIX_P, float4(pos, 1.0));
    float3 screenPos = HClip.xyz / HClip.w;

    #if UNITY_UV_STARTS_AT_TOP
        screenPos.y *= -1;
    #endif
    
    return float3(screenPos.xy * 0.5 + 0.5, Linear01Depth(screenPos.z, _ZBufferParams));
}

float DepthDifference(const float2 uv, const float clipDepth)
{
    const float depth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    const float surface = clipDepth + _Depth;
    return (depth - surface) * _Strength * 0.1;
}

float DepthDifferenceRaw(const float2 uv, const float clipDepth)
{
    const float depth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    const float surface = clipDepth;
    return depth - surface;
}

float GetWaterIncidentBlend(const float3 i, const float3 n) {
    return clamp(0.002 * exp(0.075 * RAD_TO_DEG * acos(dot(-i, n))), 0, 1);
}

void ComputeRefractionAndReflectionDir(const float3 ndcWithZ, out float2x3 dirNDC, out float2 maxDistance)
{
    const float3 positionWS = SAMPLE_TEXTURE2D(_PositionWS, sampler_PositionWS, ndcWithZ.xy);
    const float3 normalWS = SAMPLE_TEXTURE2D(_NormalWS, sampler_NormalWS, ndcWithZ.xy);
    
    const float3 viewDir = normalize(positionWS - _WorldSpaceCameraPos);

    float4 refractionEndPosHCS = TransformWorldToHClip(positionWS + refract(viewDir, normalWS, 1 / _IOR));
    refractionEndPosHCS *= rcp(refractionEndPosHCS.w);
    refractionEndPosHCS.z = Linear01Depth(refractionEndPosHCS.z, _ZBufferParams);

    float4 reflectionEndPosHCS = TransformWorldToHClip(positionWS + reflect(viewDir, normalWS));
    reflectionEndPosHCS *= rcp(reflectionEndPosHCS.w);
    reflectionEndPosHCS.z = Linear01Depth(reflectionEndPosHCS.z, _ZBufferParams);

    float4 startPosHCS = TransformWorldToHClip(positionWS);
    startPosHCS *= rcp(startPosHCS.w);
    startPosHCS.z = Linear01Depth(startPosHCS.z, _ZBufferParams);

    const float3 refractionDirHCS = normalize(refractionEndPosHCS.xyz - startPosHCS.xyz);
    const float3 reflectionDirHCS = normalize(reflectionEndPosHCS.xyz - startPosHCS.xyz);
    
    dirNDC = float2x3(
        float3(refractionDirHCS.xy * float2(0.5,
            #if UNITY_UV_STARTS_AT_TOP
            -0.5
            #else
            0.5
            #endif
        ), refractionDirHCS.z),
        float3(reflectionDirHCS.xy * float2(0.5,
            #if UNITY_UV_STARTS_AT_TOP
            -0.5
            #else
            0.5
            #endif
        ), reflectionDirHCS.z)
    );
    
    // Compute the maximum distance to trace before the ray goes outside of the visible area.
    maxDistance.x = dirNDC[0].x >= 0 ? (1 - ndcWithZ.x) / dirNDC[0].x : -ndcWithZ.x / dirNDC[0].x;
    maxDistance.x = min(maxDistance.x, dirNDC[0].y < 0 ? -ndcWithZ.y / dirNDC[0].y : (1 - ndcWithZ.y) / dirNDC[0].y);
    maxDistance.x = min(maxDistance.x, dirNDC[0].z < 0 ? -ndcWithZ.z / dirNDC[0].z : (1 - ndcWithZ.z) / dirNDC[0].z);

    maxDistance.y = dirNDC[1].x >= 0 ? (1 - ndcWithZ.x) / dirNDC[1].x : -ndcWithZ.x / dirNDC[1].x;
    maxDistance.y = min(maxDistance.y, dirNDC[1].y < 0 ? -ndcWithZ.y / dirNDC[1].y : (1 - ndcWithZ.y) / dirNDC[1].y);
    maxDistance.y = min(maxDistance.y, dirNDC[1].z < 0 ? -ndcWithZ.z / dirNDC[1].z : (1 - ndcWithZ.z) / dirNDC[1].z);
}

float3 IntersectCellBoundary(const float3 o, const float3 d, const float2 cell, const float2 cellCount, const float2 crossStep, const float2 crossOffset)
{
    const float2 delta = ((cell + crossStep) / cellCount + crossOffset - o.xy) / d.xy;
    const float t = min(delta.x, delta.y);
    return o + d * t;
}

float SampleQuadTree(const float2 uv, int level)
{
    return Linear01Depth(
        LOAD_TEXTURE2D(_DepthMipChain,
            _DepthPyramidOffsetsAndLimits[level].xy + floor(uv * _DepthPyramidOffsetsAndLimits[level].zw)
        ),
    _ZBufferParams
    );
}

bool CrossedCellBoundary(const float2 oldIdx, const float2 newIdx)
{
    return !(oldIdx.x == newIdx.x && oldIdx.y == newIdx.y);
}

float FindIntersection_HiZ(const float3 ndcWithZ, const float3 reflDir, const float maxDistance, out float3 intersection)
{
    const int maxLevel = _MipCount - 1;
	
    float2 crossStep = float2(reflDir.x >= 0 ? 1 : -1, reflDir.y >= 0 ? 1 : -1);
    const float2 crossOffset = crossStep * SSR_TRACE_EPS;
    crossStep = saturate(crossStep);
    
    float3 ray = ndcWithZ;
    const float minZ = ray.z;
    const float maxZ = ray.z + reflDir.z * maxDistance;
    const float deltaZ = maxZ - minZ;

    const float3 o = ray;
    const float3 d = reflDir * maxDistance;
	
    const int startLevel = 0;
    const int stopLevel = 0;
    const float2 startCellCount = _DepthPyramidOffsetsAndLimits[startLevel].zw;
    
    ray = IntersectCellBoundary(o, d, floor(ray.xy * startCellCount), startCellCount, crossStep, crossOffset);
    
    int level = startLevel;
    uint iter = 0;
    const bool isBackwardRay = reflDir.z < 0;
    const float rayDir = isBackwardRay ? -1 : 1;

    [loop]
    while(level >= stopLevel && ray.z * rayDir <= maxZ * rayDir && iter < 1000)
    {
        const float2 cellCount = _DepthPyramidOffsetsAndLimits[level].zw;
        const float2 oldCellIdx = floor(ray.xy * cellCount);
        
        const float cellMinZ = SampleQuadTree(ray.xy, level);
        const float3 tmpRay = cellMinZ > ray.z && !isBackwardRay ? o + d * ((cellMinZ - minZ) / deltaZ) : ray;
        
        const float2 newCellIdx = floor(tmpRay.xy * cellCount);

        const float thickness = level == 0 ? ray.z - cellMinZ : 0;
        const bool crossed = (isBackwardRay && cellMinZ > ray.z) || thickness > _Thickness * 0.01 || CrossedCellBoundary(oldCellIdx, newCellIdx);
        ray = crossed ? IntersectCellBoundary(o, d, oldCellIdx, cellCount, crossStep, crossOffset) : tmpRay;
        level = crossed ? min((float)maxLevel, level + 1.0f) : level - 1;
        
        ++iter;
    }
    intersection = ray;
    return level <= stopLevel ? 1 : 0;
}

void SampleSSR(const float2 uv, out float4 UVRG, out float2 blendFactor)
{
    float3 positionWS = SAMPLE_TEXTURE2D(_PositionWS, sampler_PositionWS, uv).xyz;
    float3 ndcWithZ = ComputeNormalizedDeviceCoordinatesWithZ(positionWS, UNITY_MATRIX_VP);
    ndcWithZ.z = Linear01Depth(ndcWithZ.z, _ZBufferParams);
    float2x3 dirNDC;
    float2 maxTraceDistance = 0;
    // Compute the refraction vector, the reflection vector, maxTraceDistance of this sample in texture space.
    ComputeRefractionAndReflectionDir(ndcWithZ, dirNDC, maxTraceDistance);
        
    // Find intersection in texture space by tracing the reflection ray
    float3 intersectionRefraction;
    float3 intersectionReflection;
    FindIntersection_HiZ(ndcWithZ, dirNDC[0], maxTraceDistance.x, intersectionRefraction);
    blendFactor.y = FindIntersection_HiZ(ndcWithZ, dirNDC[1], maxTraceDistance.y, intersectionReflection);
    float3 refractionPosWS = ComputeWorldSpacePosition(intersectionRefraction.xy, intersectionRefraction.z, UNITY_MATRIX_I_VP);
    blendFactor.x = length(refractionPosWS - positionWS);
    UVRG = float4(intersectionRefraction.xy, intersectionReflection.xy);
}
/*
void SampleSSR(const float2 originalUV, out float4 UVRG, out float blendFactor)
{
    const float3 positionWS = SAMPLE_TEXTURE2D(_PositionWS, sampler_PositionWS, originalUV).xyz;
    const float3 normalWS = SAMPLE_TEXTURE2D(_NormalWS, sampler_NormalWS, originalUV).xyz;
    
    const float3 positionVS = TransformWorldToView(positionWS);
    const float3 normalVS = TransformWorldToViewDir(normalWS);
    
    const float3 positionFrom = positionVS;
    const float3 viewDir = normalize(positionFrom);
    
    const Light mainLight = GetMainLight();
    
    const float3x3 rays = float3x3(
        refract(viewDir, normalVS, 1 / _IOR),
        refract(TransformWorldToViewDir(mainLight.direction), normalVS, 1 / _IOR),
        reflect(viewDir, normalVS)
    );
    
    float3x3 positionTo = float3x3(
        positionFrom, positionFrom,
        positionFrom
    ) + rays * _MaxDistance;
    
    const float2 startFrag = originalUV * _ScreenParams.xy;
    const float3x2 endFrag = float3x2(
        TransformViewToScreenPos(positionTo[0]).xy * _ScreenParams.xy,
        TransformViewToScreenPos(positionTo[1]).xy * _ScreenParams.xy,
        TransformViewToScreenPos(positionTo[2]).xy * _ScreenParams.xy
    );
    
    positionTo = abs(positionTo);
    const float3 positionFromAbs = abs(positionFrom);
    
    const float3x2 delta = float3x2(
        endFrag[0] - startFrag,
        endFrag[1] - startFrag,
        endFrag[2] - startFrag
    );
    
    const float3 useX = float3(
        abs(delta[0].x) >= abs(delta[0].y) ? 1 : 0,
        abs(delta[1].x) >= abs(delta[1].y) ? 1 : 0,
        abs(delta[2].x) >= abs(delta[2].y) ? 1 : 0
    );
    
    const float3 selectedDelta = float3(
        lerp(abs(delta[0].y), abs(delta[0].x), useX[0]) * _Resolution,
        lerp(abs(delta[1].y), abs(delta[1].x), useX[1]) * _Resolution,
        lerp(abs(delta[2].y), abs(delta[2].x), useX[2]) * _Resolution
    );

    const float3x2 increment = float3x2(
        delta[0] / max(selectedDelta[0], 0.001),
        delta[1] / max(selectedDelta[1], 0.001),
        delta[2] / max(selectedDelta[2], 0.001)
    );
    
    float3 search0 = 0;
    float3 search1 = 0;
    
    int3 hit0 = 0;
    int3 hit1 = 0;
    
    float3 viewDistance;
    
    float3 depth;
    
    float3x2 currentFrag = float3x2(
        startFrag, startFrag, startFrag
    );
    
    float3x2 uv;
    float3 sceneDepth;
    
    int i;
    
    [loop]
    for (i = 0; i < _MaxSteps; i++)
    {
        currentFrag = float3x2(
            currentFrag[0] + increment[0] * (1 - hit0[0]),
            currentFrag[1] + increment[1] * (1 - hit0[1]),
            currentFrag[2] + increment[2] * (1 - hit0[2])
        );
        
        uv = float3x2(
            currentFrag[0] / _ScreenParams.xy,
            currentFrag[1] / _ScreenParams.xy,
            currentFrag[2] / _ScreenParams.xy
        );
        
        sceneDepth = float3(
            hit0[0] < 1 ? LinearEyeDepth(SampleSceneDepth(uv[0]), _ZBufferParams) : sceneDepth[0],
            hit0[1] < 1 ? LinearEyeDepth(SampleSceneDepth(uv[1]), _ZBufferParams) : sceneDepth[1],
            hit0[2] < 1 ? LinearEyeDepth(SampleSceneDepth(uv[2]), _ZBufferParams) : sceneDepth[2]
        );
        
        search1 = float3(
            lerp((currentFrag[0].y - startFrag.y) / delta[0].y, (currentFrag[0].x - startFrag.x) / delta[0].x, useX[0]),
            lerp((currentFrag[1].y - startFrag.y) / delta[1].y, (currentFrag[1].x - startFrag.x) / delta[1].x, useX[1]),
            lerp((currentFrag[2].y - startFrag.y) / delta[2].y, (currentFrag[2].x - startFrag.x) / delta[2].x, useX[2])
        );
        
        search1 = clamp(search1, 0.0, 1.0);
        
        viewDistance = float3(
            positionFromAbs.z * positionTo[0].z / lerp(positionTo[0].z, positionFromAbs.z, search1[0]),
            positionFromAbs.z * positionTo[1].z / lerp(positionTo[1].z, positionFromAbs.z, search1[1]),
            positionFromAbs.z * positionTo[2].z / lerp(positionTo[2].z, positionFromAbs.z, search1[2])
        );
        
        depth = sceneDepth - viewDistance;
        
        hit0 = float3(
            (depth[0] > 0 && depth[0] < _Thickness) || hit0[0] != 0 || i >= selectedDelta[0] ? 1 : 0,
            (depth[1] > 0 && depth[1] < _Thickness) || hit0[1] != 0 || i >= selectedDelta[1] ? 1 : 0,
            (depth[2] > 0 && depth[2] < _Thickness) || hit0[2] != 0 || i >= selectedDelta[2] ? 1 : 0
        );
    
        search0 = float3(
            hit0[0] != 1 ? search1[0] : search0[0],
            hit0[1] != 1 ? search1[1] : search0[1],
            hit0[2] != 1 ? search1[2] : search0[2]
        );
        
        if (hit0[0] != 0 && hit0[1] != 0 && hit0[2] != 0)
            break;
    }
    
    search1 = search0 + (search1 - search0) / 2;
    
    [unroll(20)]
    for (i = 0; i < _RefineSteps; i++)
    {
        currentFrag = float3x2(
            lerp(startFrag, endFrag[0], search1[0]),
            lerp(startFrag, endFrag[1], search1[1]),
            lerp(startFrag, endFrag[2], search1[2])
        );
        
        uv = float3x2(
            currentFrag[0] / _ScreenParams.xy,
            currentFrag[1] / _ScreenParams.xy,
            currentFrag[2] / _ScreenParams.xy
        );
        
        sceneDepth = float3(
            LinearEyeDepth(SampleSceneDepth(uv[0]), _ZBufferParams),
            LinearEyeDepth(SampleSceneDepth(uv[1]), _ZBufferParams),
            LinearEyeDepth(SampleSceneDepth(uv[2]), _ZBufferParams)
        );
        
        viewDistance = float3(
            positionFromAbs.z * positionTo[0].z / lerp(positionTo[0].z, positionFromAbs.z, search1[0]),
            positionFromAbs.z * positionTo[1].z / lerp(positionTo[1].z, positionFromAbs.z, search1[1]),
            positionFromAbs.z * positionTo[2].z / lerp(positionTo[2].z, positionFromAbs.z, search1[2])
        );
        
        depth = sceneDepth - viewDistance;
        
        hit1 = float3(
            (depth[0] > 0 && depth[0] < _Thickness) || hit1[0] != 0 ? 1 : 0,
            (depth[1] > 0 && depth[1] < _Thickness) || hit1[1] != 0 ? 1 : 0,
            (depth[2] > 0 && depth[2] < _Thickness) || hit1[2] != 0 ? 1 : 0
        );
    
        float3 temp = search1;
    
        search1 = float3(
            (hit1[0] != 0 ? search0[0] : search1[0]) + ((search1[0] - search0[0]) / 2),
            (hit1[1] != 0 ? search0[1] : search1[1]) + ((search1[1] - search0[1]) / 2),
            (hit1[2] != 0 ? search0[2] : search1[2]) + ((search1[2] - search0[2]) / 2)
        );
    
        search0 = float3(
            hit1[0] != 1 ? temp[0] : search0[0],
            hit1[1] != 1 ? temp[1] : search0[1],
            hit1[2] != 1 ? temp[2] : search0[2]
        );
    }

    float3 visibility = hit1 * float3(
        1,//(1 - max(dot(-viewDir, rays[0]), 0)) * (uv[0].x < 0 || uv[0].x > 1 ? 0 : 1) * (uv[0].y < 0 || uv[0].y > 1 ? 0 : 1),
        1,//(1 - max(dot(-viewDir, rays[1]), 0)) * (uv[0].x < 0 || uv[0].x > 1 ? 0 : 1) * (uv[0].y < 0 || uv[0].y > 1 ? 0 : 1),
        (1 - max(dot(-viewDir, rays[2]), 0)) * GetWaterIncidentBlend(viewDir, normalVS)
    );
    
    visibility = clamp(visibility, 0, 1);
    
    uv = float3x2(
        lerp(originalUV, uv[0], visibility[0]),
        lerp(originalUV, uv[1], visibility[1]),
        uv[2]
    );
    
    _Light[uv[1] * _ScreenParams.xy] = _Light[uv[1] * _ScreenParams.xy] + float4(mainLight.color, 0) * 0.2;
    
    UVRG = float4(uv[0], uv[2]);
    blendFactor = visibility[2];
}*/

void SampleFakeSSR(const float2 originalUV, const float3 positionWS, const float3 viewDirWS, const float3 normalWS, const float clipW, out float4 UVRG) {
    const float3 refractedRay = refract(viewDirWS, normalWS, 1 / _IOR);
    const float2 refractedUV = TransformWorldToScreenPos(positionWS + refractedRay * 3 * saturate(DepthDifferenceRaw(originalUV, clipW))).xy;
    UVRG = float4(lerp(originalUV, refractedUV, saturate(DepthDifference(refractedUV, clipW))), originalUV);
}

float4 Fragment(const BlitVaryings IN) : SV_Target {
    float4 UVRG;
    const float4 positionWS = SAMPLE_TEXTURE2D(_PositionWS, sampler_PositionWS, IN.uv);
    
    if (positionWS.w > 0 || SampleSceneDepth(IN.uv) > SAMPLE_TEXTURE2D(_PositionHCS, sampler_PositionHCS, IN.uv).z) {
        return float4(IN.uv, 0,0);
    }
    
    #if defined(_SSR_ON)
    float2 blendFactor;
    SampleSSR(IN.uv, UVRG, blendFactor);
    _Light[IN.uv * _ScreenParams.xy] = float4(_Light[IN.uv * _ScreenParams.xy].xy, blendFactor);
    #else
    const float3 viewDir = GetWorldSpaceNormalizeViewDir(positionWS.xyz);
    SampleFakeSSR(IN.uv, positionWS.xyz, viewDir,
        SAMPLE_TEXTURE2D(_NormalWS, sampler_NormalWS, IN.uv).xyz,
        SAMPLE_TEXTURE2D(_PositionHCS, sampler_PositionHCS, IN.uv).w, UVRG
    );
    #endif
    return UVRG;
}