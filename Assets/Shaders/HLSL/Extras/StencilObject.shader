Shader"Custom/StencilObject"
{
    Properties
    {
        [Enum(Front, 1, Right, 2, Left, 3, Back, 4)]
        _CubeFaceMask("Cube Face Mask", Float) = 1
        [MainColor] _Color("Color", Color) = (0.5, 0.1, 0.1, 1)
        [Enum(Off, 0, Front, 1, Back, 2)]
        _Cull("Face Culling", Float) = 2.0
        [Enum(Off, 0, On, 1)]
        _ZWrite("ZWrite", Float) = 1.0
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }

        Pass 
        {
            Name "Forward Lit"
            Tags { "LightMode" = "UniversalForward" }

            Stencil
            {
                Ref [_CubeFaceMask]
                Comp Equal
                Pass Keep
            }

            Cull[_Cull]
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite[_ZWrite]
            

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma target 4.5            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, sh, 5);
                #if defined(DYNAMICLIGHTMAP_ON)
                float2  dynamicLightmapUV : TEXCOORD6;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            CBUFFER_END

            Varyings Vertex(const Attributes input) {
                Varyings output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                VertexPositionInputs vertPos = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs vertNormals = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionHCS = vertPos.positionCS;
                output.positionWS = vertPos.positionWS;
                output.uv = input.uv0;

                output.normalWS = vertNormals.normalWS;
                output.tangentWS = float4(vertNormals.tangentWS.xyz, input.tangentOS.w * GetOddNegativeScale());

                half fogFactor = 0;
                #if !defined(_FOG_FRAGMENT)
                fogFactor = ComputeFogFactor(input.positionHCS.z);
                #endif
                
                OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.staticLightmapUV);
                #if defined(DYNAMICLIGHTMAP_ON)
                output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                OUTPUT_SH(output.normalWS.xyz, output.sh);
                output.fogFactor = fogFactor;
                return output;
            }

            void InitializeInputData(const Varyings input, const half3 normalTS, out InputData inputData) {
                inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                inputData.normalWS = input.normalWS;

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
                surfaceData.alpha = _Color.a;
                surfaceData.albedo = _Color.rgb;
                surfaceData.albedo = AlphaModulate(surfaceData.albedo, surfaceData.alpha);
                surfaceData.smoothness = 0.5;
                surfaceData.occlusion = 0.5;
            }

            half4 Fragment(Varyings input) : SV_TARGET {

                UNITY_SETUP_INSTANCE_ID(input);

                SurfaceData surfaceData;
                InitializeSurfaceData(input.uv, surfaceData);

                InputData inputData;
                InitializeInputData(input, surfaceData.normalTS, inputData);

                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                color.a = OutputAlpha(color.a, false);
                
                return color;
            }

            ENDHLSL
        }

        Pass {
            Name "Depth Only"
            Tags { "LightMode" = "DepthOnly" }

            Cull Back
            ZTest LEqual
            ZWrite On
            ColorMask R

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "../Common/SurfaceShaderExampleDepthProgram.hlsl"

            ENDHLSL
        }
        
        Pass {
            Name "Shadow Caster"
            Tags { "LightMode" = "ShadowCaster" }

            Cull Back
            ZTest LEqual
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "../Common/SurfaceShaderExampleShadowProgram.hlsl"

            ENDHLSL
        }
    }
}
