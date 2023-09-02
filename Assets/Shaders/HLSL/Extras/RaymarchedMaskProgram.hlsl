#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"

struct Attributes {
    float3 positionOS : POSITION;
    float2 uv0 :TEXCOORD0;
    float2 uv1 :TEXCOORD1;
    float2 uv2 :TEXCOORD2;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
    float2 uv :TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
    half  fogFactor : TEXCOORD4;
    half3 viewDirTS : TEXCOORD5;
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, sh, 6);
    #if defined(DYNAMICLIGHTMAP_ON)
    float2  dynamicLightmapUV : TEXCOORD7;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);
TEXTURE2D(_RoughnessMap);   SAMPLER(sampler_RoughnessMap);
TEXTURE2D(_OcclusionMap);   SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicMap);    SAMPLER(sampler_MetallicMap);
TEXTURE2D(_ParallaxMap);    SAMPLER(sampler_ParallaxMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _NormalMap_ST;
    float4 _RoughnessMap_ST;
    float4 _OcclusionMap_ST;
    float4 _ParallaxMap_ST;
    half _ParallaxStrength;
    half4 _BaseColor;
CBUFFER_END

Varyings Vertex(const Attributes input) {
    Varyings output;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    
    VertexPositionInputs vertPos = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs vertNormals = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionHCS = vertPos.positionCS;
    output.positionWS = vertPos.positionWS;
    output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);

    output.normalWS = vertNormals.normalWS;
    output.tangentWS = float4(vertNormals.tangentWS.xyz, input.tangentOS.w * GetOddNegativeScale());

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
    fogFactor = ComputeFogFactor(input.positionHCS.z);
    #endif
    
    const half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertPos.positionWS);
    const half3 viewDirTS = GetViewDirectionTangentSpace(output.tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
    
    OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.staticLightmapUV);
    #if defined(DYNAMICLIGHTMAP_ON)
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.sh);
    output.fogFactor = fogFactor;
    return output;
}

half SampleOcclusion(const float2 uv) {
    return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
}

half4 SampleColor(const float2 uv) {
    return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
}

half SampleRoughness(const float2 uv) {
    return SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).r;
}

half SampleMetallic(const float2 uv) {
    return SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv).r;
}

half3 SampleNormal(const float2 uv) {
    return UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv));
}

void ApplyPerPixelDisplacement(const half3 viewDirTS, inout float2 uv) {
    uv += ParallaxMapping(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), viewDirTS, _ParallaxStrength, uv);
}

void InitializeInputData(const Varyings input, const half3 normalTS, out InputData inputData) {
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;

    const half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    const float sgn = input.tangentWS.w;      // should be either +1 or -1
    const float3 bitangentWS = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    const half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangentWS.xyz, input.normalWS.xyz);
    inputData.tangentToWorld = tangentToWorld;
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.sh, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionHCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

inline void InitializeSurfaceData(const float2 uv, out SurfaceData surfaceData) {
    surfaceData = (SurfaceData)0;
    half4 albedo = SampleColor(uv);
    surfaceData.alpha = albedo.a * _BaseColor.a;
    surfaceData.albedo = albedo.rgb * _BaseColor.rgb;
    surfaceData.albedo = AlphaModulate(surfaceData.albedo, surfaceData.alpha);
    surfaceData.metallic = SampleMetallic(uv);
    surfaceData.smoothness = 1 - SampleRoughness(uv);
    surfaceData.normalTS = SampleNormal(uv);
    surfaceData.occlusion = SampleOcclusion(uv);
}

half Sphere(const half3 p, const half3 c, const half s) {
  return length(p - c) - s;
}

half SmoothUnion(const half d1, const half d2, const half k) {
    const half h = clamp(0.5 + 0.5 * (d2-d1) / k, 0.0, 1.0);
    return lerp(d2, d1, h) - k * h * (1.0 - h); 
}

half Distance(const half3 p, const half3x3 positions, const half3 radii) {
    return SmoothUnion(
        SmoothUnion(
            Sphere(p, positions._m00_m01_m02, radii.x),
            Sphere(p, positions._m10_m11_m12, radii.y),
            0.3),
        Sphere(p, positions._m20_m21_m22, radii.z),
        0.3);
}

half3 CalculateNormal(const half3 p, const half3x3 positions, const half3 radii) {
    const half h = 0.0001; // replace by an appropriate value
    const half2 k = float2(1, -1);
    return normalize(k.xyy * Distance(p + k.xyy * h, positions, radii) +
                      k.yyx * Distance(p + k.yyx * h, positions, radii) +
                      k.yxy * Distance(p + k.yxy * h, positions, radii) +
                      k.xxx * Distance(p + k.xxx * h, positions, radii));
}

half4 Raymarch(Varyings v) {
    const half3 _Sphere1Dir = normalize(half3(0, 1, -0.75));
    const half3 _Sphere2Dir = normalize(half3(1, 1, 0));
    const half3 _Sphere3Dir = normalize(half3(1, 0, 0.5));

    const half3 _Sphere1Position = _Sphere1Dir * sin(_Time.y) * 0.4;
    const half3 _Sphere2Position = _Sphere2Dir * sin(_Time.y + 0.5) * 0.4;
    const half3 _Sphere3Position = _Sphere3Dir * sin(_Time.y + 1) * 0.4;

    const half3 positionOS = TransformWorldToObject(v.positionWS);

    half rayDst = 0;
    half3 rayOrigin = positionOS;
    const half3 rayDir = -GetObjectSpaceNormalizeViewDir(positionOS);
    
    [loop]
    for (int i = 0; i < 75; i++) {
        
        const half _Sphere1Radius = 0.1;
        const half _Sphere2Radius = 0.075;
        const half _Sphere3Radius = 0.05;
        
        const half dist = Distance(rayOrigin,
            half3x3(_Sphere1Position, _Sphere2Position, _Sphere3Position),
            half3(_Sphere1Radius, _Sphere2Radius, _Sphere3Radius)
        );

        if (dist <= 0.001) {

            const half3 normalWS = TransformObjectToWorldNormal(
                CalculateNormal(rayOrigin,
                    half3x3(_Sphere1Position, _Sphere2Position, _Sphere3Position),
                    half3(_Sphere1Radius, _Sphere2Radius, _Sphere3Radius)
                )
            );

            const half3 positionWS = TransformObjectToWorld(rayOrigin);

            // Populate input data
            InputData lightingInput = (InputData)0;
            lightingInput.positionWS = positionWS;
            lightingInput.positionCS = TransformObjectToHClip(rayOrigin);
            lightingInput.normalWS = normalWS;
            lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(positionWS);
            lightingInput.shadowCoord = TransformWorldToShadowCoord(positionWS);

            #if defined(DYNAMICLIGHTMAP_ON)
                lightingInput.bakedGI = SAMPLE_GI(v.staticLightmapUV, v.dynamicLightmapUV.xy, v.sh, normalWS);
            #else
                lightingInput.bakedGI = SAMPLE_GI(v.staticLightmapUV, v.sh, normalWS);
            #endif

            // Populate surface data
            SurfaceData surfaceInput = (SurfaceData)0;
            surfaceInput.albedo = half3(1, 0.5, 0);
            surfaceInput.alpha = 1;
            surfaceInput.occlusion = 1;
            surfaceInput.emission = half3(1, 0.2, 0) * 15;

            return UniversalFragmentPBR(lightingInput, surfaceInput);
        }

        rayOrigin += rayDir * dist;
        rayDst += dist;
    }

    return 0;
}

half4 Fragment(Varyings input) : SV_TARGET {

    const half mask = smoothstep(0.5, 0.75, length(input.uv - 0.5) * 2);
    const half4 raymarchCol = Raymarch(input);

    if (mask + raymarchCol.a == 0) {
        clip(-1);
    }

    UNITY_SETUP_INSTANCE_ID(input);

    ApplyPerPixelDisplacement(input.viewDirTS, input.uv);

    SurfaceData surfaceData;
    InitializeSurfaceData(input.uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, false);
    
    return lerp(raymarchCol, color, mask);
}