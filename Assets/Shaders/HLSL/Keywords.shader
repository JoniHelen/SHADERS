Shader "Custom/TestiShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _Shininess("Shininess", Float) = 4
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipleline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "OmaPass"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            Cull Back
            Blend One Zero
            ZTest LEqual
            ZWrite On
            
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma target 4.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // Lighting needs to be included

            struct Attributes {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float _Shininess;
                float4 _BaseColor;
            CBUFFER_END

            Varyings Vertex(const Attributes input) {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS);
                output.positionWS = TransformObjectToWorld(input.positionOS);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                return output;
            }

            float4 BlinnPhong(const Varyings input)
            {
                const Light light = GetMainLight();
                
                // ambient
                const float3 ambient = 0.1 * light.color;
                
                // diffuse
                const float3 diffuse = saturate(dot(input.normalWS, light.direction)) * light.color;
                
                // specular
                const float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                
                const float3 halfwayDir = normalize(light.direction + viewDirWS);
                const float3 specular = pow(saturate(dot(input.normalWS, halfwayDir)), _Shininess) * light.color;
                return float4((ambient + diffuse + specular) * _BaseColor, 1);
            }

            float4 Fragment(const Varyings input) : SV_TARGET {
                return BlinnPhong(input);
            }
            
            ENDHLSL
        }

        Pass { // This pass is necessary for proper depth writing
            Name "Depth Only"
            Tags { "LightMode" = "DepthOnly" }

            Cull Back
            ZTest LEqual
            ZWrite On
            ColorMask R

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Common/SurfaceShaderExampleDepthProgram.hlsl"

            ENDHLSL
        }
    }
}