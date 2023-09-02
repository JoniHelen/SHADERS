Shader "Custom/SurfaceShaderExample1" // The name and location of the shader in the material selector
{
    Properties // This is the block where you add properties
    {
        // Custom properties
    }
    
    CustomEditor "ExampleShaderGUI" // Custom editor GUI
    
    SubShader // The subshader tells unity which render pipeline to use and how.
    {                   // You can define multiple subshaders for different pipelines.
        Tags {"RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="Geometry"}
        // RenderPipeline tag needs to be set so that Unity can render this shader in URP
        // https://docs.unity3d.com/2022.2/Documentation/Manual/SL-SubShaderTags.html

        HLSLINCLUDE
            // You can include or write common code used for multiple passes here.
        ENDHLSL

        Pass { // A pass defines one "iteration" of the drawing process. Unity executes all passes in the order that you define them.
        // If you are using command buffers, you can execute passes in a custom order as well.

            Name "Forward Lit" // The name of the pass. Useful for debugging and custom draw calls.
            
            Tags { "LightMode" = "SRPDefaultUnlit" } 
            // This tag is set so that unity knows what to do with lighting
            // UniversalForward is the default lighting. It draws all light contributions.
            // We will use SRPDefaultUnlit because we don't handle lights.
            // If no tag is specified, it will default to SRPDefaultUnlit.
            // https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@11.0/manual/urp-shaders/urp-shaderlab-pass-tags.html#urp-pass-tags-lightmode

            // Pass Commands
            Cull Back
            Blend One Zero
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM // This tag defines a HLSL code block in the pass.
            
            // Different shader stages are defined as #pragma directives.
            // The basic ones are 'vertex' and 'fragment'.
            // The syntax goes as follows: #pragma [stage] [funcName]
            #pragma vertex Vertex
            #pragma fragment Fragment

            // HLSL can be written here directly, or included as seen here.
            #include "SurfaceShaderExample1Program.hlsl"

            ENDHLSL // This is the end of the HLSL code.
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

            #include "../Common/SurfaceShaderExampleDepthProgram.hlsl"

            ENDHLSL
        }
        
        Pass { // This pass is necessary for shadows
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
