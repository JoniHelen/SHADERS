Shader "Custom/Cooler Water"
{
    Properties
    {
        // NORMAL MAP
        [Header(Normal Map)] [Space(10)]
        _NormalMap("Map", 2D) = "bump" {}
        
        // SSR SETTINGS
        [Header(SSR Properties)] [Space(10)]
        [Toggle] _SSR("Enable SSR", Float) = 1
        _IOR("Water IOR", Range(0, 3)) = 1.33
        _Thickness("Thickness", Range(0, 1)) = 0.2
        _Extinction("Extinction", Range(0, 1)) = 0
        _FresnelBias("Frensel Bias", Range(0, 1)) = 0
        
        // MATERIAL PROPERTIES
        [Header(Material Properties)] [Space(10)]
        [MainColor] _Color("Color", Color) = (0, 0.55859375, 0.74609375, 1)
        _Smoothness("Smoothness", Range(0, 1)) = 0.5
        _NormalStrength("Normal Strength", Range(0, 0.5)) = 0.1
        _Strength("Strength", Float) = 0.5
        _Depth("Depth", Float) = 0.5
        
        // WAVES
        [Header(Waves)][Space(10)]
        [Toggle] _SimulateWaves("Simulate Waves", Float) = 1
        
        // WAVE 1
        [Header(Wave 1 Parameters)] [Space(10)]
        [PowerSlider(0.2)] _Wave_1_Size("Wave Size", Range(0, 1)) = 0.5
        _Wave_1_Steepness("Steepness", Range(0, 1)) = 0.5
        _Wave_1_Angle("Wave Angle", Range(0, 365)) = 0
        
        // WAVE 2
        [Header(Wave 2 Parameters)][Space(10)]
        [PowerSlider(0.2)] _Wave_2_Size("Wave Size", Range(0, 1)) = 0.5
        _Wave_2_Steepness("Steepness", Range(0, 1)) = 0.5
        _Wave_2_Angle("Wave Angle", Range(0, 365)) = 0
        
        // WAVE 3
        [Header(Wave 3 Parameters)][Space(10)]
        [PowerSlider(0.2)] _Wave_3_Size("Wave Size", Range(0, 1)) = 0.5
        _Wave_3_Steepness("Steepness", Range(0, 1)) = 0.5
        _Wave_3_Angle("Wave Angle", Range(0, 365)) = 0
        
        // WAVE 4
        [Header(Wave 4 Parameters)][Space(10)]
        [PowerSlider(0.2)] _Wave_4_Size("Wave Size", Range(0, 1)) = 0.5
        _Wave_4_Steepness("Steepness", Range(0, 1)) = 0.5
        _Wave_4_Angle("Wave Angle", Range(0, 365)) = 0
    }
    SubShader
    {
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "UniversalMaterialType" = "Lit"
            "Queue" = "Transparent"
            "DisableBatching" = "False"
        }
        
        // Common vertex function for blit operations
        HLSLINCLUDE
        struct BlitVertexInput {
            float3 positionOS : POSITION;
            float2 uv0 :TEXCOORD0;
        };

        struct BlitVaryings {
            float4 positionHCS : SV_POSITION;
            float2 uv :TEXCOORD0;
        };

        BlitVaryings BlitVertex(const BlitVertexInput IN) {
            BlitVaryings OUT;
            
            OUT.positionHCS = float4(IN.positionOS.xyz, 1);
            OUT.uv = IN.uv0;

            return OUT;
        }
        ENDHLSL

        // First pass generates basic vertex interpolation data
        Pass {
            Name "Meta Prepass"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            Blend Off
            ZTest Off
            ZWrite Off

            HLSLPROGRAM

            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore

            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma multi_compile_vertex _ _SIMULATEWAVES_ON

            #include "CoolerWaterMetaPass.hlsl"

            ENDHLSL
        }
        
        // Second pass generates SSR offsets and light simulation
        Pass {
            Name "SSR Pass"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            Blend Off
            ZTest Off
            ZWrite Off

            HLSLPROGRAM

            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore

            #pragma vertex BlitVertex
            #pragma fragment Fragment

            #pragma multi_compile_fragment _ _SSR_ON

            #include "CoolerWaterSSRPass.hlsl"

            ENDHLSL
        }
        
        // Third pass calculates the final color of the water
        Pass {
            Name "Color Pass"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            Blend Off
            ZTest Off
            ZWrite Off

            HLSLPROGRAM

            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore

            #pragma vertex BlitVertex
            #pragma fragment Fragment

            #pragma multi_compile _ _ADDITIONAL_LIGHTS

            #include "CoolerWaterColorPass.hlsl"

            ENDHLSL
        }
        
        // This pass is used for debugging textures
        Pass {
            Name "Debug Blit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            Blend One Zero
            ZTest Off
            ZWrite Off

            HLSLPROGRAM

            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore

            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_PositionWS);
            SAMPLER(sampler_PositionWS);

            TEXTURE2D(_PositionHCS);
            SAMPLER(sampler_PositionHCS);

            TEXTURE2D(_NormalWS);
            SAMPLER(sampler_NormalWS);

            TEXTURE2D(_UVRG);
            SAMPLER(sampler_UVRG);

            TEXTURE2D(_UVBA);
            SAMPLER(sampler_UVBA);

            TEXTURE2D(_CollectedLight);
            SAMPLER(sampler_CollectedLight);

            CBUFFER_START(UnityPerMaterial)
            float _Debug;
            CBUFFER_END

            // The default blit needs HClip transformation
            BlitVaryings Vertex(BlitVertexInput IN) {
                BlitVaryings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS);
                OUT.uv = IN.uv0;

                return OUT;
            }

            float4 Fragment(BlitVaryings IN) : SV_Target {
                float4 col;
                switch (_Debug) {
                    case 1:
                        col = SAMPLE_TEXTURE2D(_PositionWS, sampler_PositionWS, IN.uv);
                        break;
                    case 2:
                        col = SAMPLE_TEXTURE2D(_PositionHCS, sampler_PositionHCS, IN.uv);
                        break;
                    case 3:
                        col = SAMPLE_TEXTURE2D(_NormalWS, sampler_NormalWS, IN.uv);
                        break;
                    case 4:
                        col = SAMPLE_TEXTURE2D(_UVRG, sampler_UVRG, IN.uv);
                        break;
                    case 5:
                        col = SAMPLE_TEXTURE2D(_UVBA, sampler_UVBA, IN.uv);
                        break;
                    case 6:
                        col = SAMPLE_TEXTURE2D(_CollectedLight, sampler_CollectedLight, IN.uv);
                        break;
                    default:
                        col = float4(0, 0, 0, 0);
                        break;
                }
                return col;
            }
            ENDHLSL
        }
    }
}