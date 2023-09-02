Shader"Custom/StencilMask"
{
    Properties
    {
        [Enum(Front, 1, Right, 2, Left, 3, Back, 4)]
        _CubeFaceMask("Cube Face Mask", Float) = 1
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
                Comp Always
                Pass Replace
            }

            Cull Back
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma target 4.5            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 Vertex(float3 positionOS : POSITION) : SV_POSITION {
	            return TransformObjectToHClip(positionOS.xyz);
            }

            half4 Fragment() : SV_Target {
	            return half4(0, 0, 0, 0);
            }

            ENDHLSL
        }
    }
}
