Shader "Custom/SurfaceShaderExample3"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" { } // Now we have added a texture parameter
    }
    
    CustomEditor "ExampleShaderGUI" // Custom editor GUI
    
    SubShader
    {
        Tags {"RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="Geometry"}

        Pass {
            Name "Forward Lit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            Blend One Zero
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "SurfaceShaderExample3Program.hlsl"

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
