Shader "Custom/Intersection"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 1, 1)
        _IntersectionColor("Intersection Color", Color) = (0, 0, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        
        Pass
        {
            Name "IntersectionUnlit"
            Tags { "LightMode"="SRPDefaultUnlit" }
            
            Cull Back
            Blend One Zero
            ZTest LEqual
            ZWrite On
            
            HLSLPROGRAM

            #pragma vertex Vertex;
            #pragma fragment Fragment;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
            };

            Varyings Vertex(const Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                return output;
            }

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _IntersectionColor;
            CBUFFER_END

            float4 Fragment(const Varyings input) : SV_TARGET
            {
                const float2 screenUV = GetNormalizedScreenSpaceUV(input.positionHCS);
                const float depthTexture = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
                const float depthObject = LinearEyeDepth(input.positionWS, UNITY_MATRIX_V);
                const float diff = depthTexture - depthObject;
                return (sin(diff + _Time.y) + 1) * 0.5;
            }
            
            ENDHLSL
        }
    }
}