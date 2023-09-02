Shader "Custom/Wind Nature"
{
    Properties
    {
        _WindStrength("Strength", Float) = 0
        _WindDirection("Direction", Range(0, 360)) = 0
        _WindSpeed("Speed", Float) = 0
        _WindScale("Scale", Float) = 0
        [KeywordEnum(Grass, Flower, Leaf, Tree)]
        _ObjectType("Object Type", Float) = 0
        _FlowerColor("Flower Color", Color) = (1, 1, 1, 1)
        _LeafTexture("Leaf Texture", 2D) = "white" {}
        _LeafTint("Leaf tint", Color) = (1, 1, 1, 1)
        _LeafSaturation("Saturation", Float) = 1
        _LeafEmission("Leaf Emission", Float) = 0
        _BarkTexture("Bark Texture", 2D) = "white" {}
        _TreeHeight("Tree Height", Range(0.001, 50)) = 1
    }
    
    CustomEditor "NatureShaderGUI"
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="Geometry" }
        
        HLSLINCLUDE
        #include "WindNatureProgram.hlsl"
        ENDHLSL
        
        Pass {
            Name "Forward Lit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            Blend One Zero
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            
            // Material Keywords
            #pragma shader_feature_local _OBJECTTYPE_GRASS _OBJECTTYPE_FLOWER _OBJECTTYPE_LEAF _OBJECTTYPE_TREE
            
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
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
            
            ENDHLSL
        }
        
        Pass
        {
            Name "Shadow Caster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // Material Keywords
            #pragma shader_feature_local _OBJECTTYPE_GRASS _OBJECTTYPE_FLOWER _OBJECTTYPE_LEAF _OBJECTTYPE_TREE
            
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            ENDHLSL
        }
        
        Pass
        {
            Name "Depth Only"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // Material Keywords
            #pragma shader_feature_local _OBJECTTYPE_GRASS _OBJECTTYPE_FLOWER _OBJECTTYPE_LEAF _OBJECTTYPE_TREE
            
            // GPU Instancing
            #pragma multi_compile_instancing

            ENDHLSL
        }
    }
}
