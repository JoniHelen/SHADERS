Shader "Custom/Goo"
{
    Properties
    {
        [KeywordEnum(Low, Medium, High, Off)]
        _DepthCullQuality ("Depth culling quality", Float) = 0
        [KeywordEnum(PBR, Diffuse)]
        _LightingMethod("Lighting method", Float) = 0
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
		_Smoothness ("Smoothness", Range(0, 1)) = 0
        _RayBias ("Ray Bias", Range(0, 1)) = 0
        _DepthBias ("Depth Bias", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags {"RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline" "Queue"="Transparent"}

        Pass {
            Name "Forward Lit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha
            ZTest LEqual
            ZWrite Off

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma multi_compile _DEPTHCULLQUALITY_LOW _DEPTHCULLQUALITY_MEDIUM _DEPTHCULLQUALITY_HIGH _DEPTHCULLQUALITY_OFF
            #pragma multi_compile _LIGHTINGMETHOD_PBR _LIGHTINGMETHOD_DIFFUSE

            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS

            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "GooProgram.hlsl"

            ENDHLSL
        }
    }
}