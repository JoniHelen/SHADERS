Shader "Custom/Water"
{
    Properties
    {
        [Header(Normal Maps)] [Space(10)]
        _NormalMap("Map 1", 2D) = "bump" {}
        [Header(SSR Properties)] [Space(10)]
        [Toggle] _SSR("Enable SSR", Float) = 1
        _IOR("Water IOR", Range(0, 3)) = 1.33
        _Scatter("Light scattering", Range(0, 1)) = 0
        _MaxDistance("Max Distance", Range(0, 100)) = 50
        _Resolution("Resolution", Range(0, 1)) = 1
        [IntRange] _MaxSteps("Max Steps", Range(0, 500)) = 200
        [IntRange] _RefineSteps("Refinement Steps", Range(0, 20)) = 10
        _Thickness("Thickness", Range(0, 5)) = 0.5
        [Header(Material Properties)] [Space(10)]
        [MainColor] _Color("Color", Color) = (0, 0.55859375, 0.74609375, 1)
        _Smoothness("Smoothness", Range(0, 1)) = 0.5
        _NormalStrength("Normal Strength", Range(0, 0.5)) = 0.1
        _Strength("Strength", Float) = 0.5
        _Depth("Depth", Float) = 0.5
        [Header(Waves)][Space(10)]
        [Toggle] _SimulateWaves("Simulate Waves", Float) = 1
        [Header(Wave 1 Parameters)] [Space(10)]
        [PowerSlider(0.2)] _Wave_1_Size("Wave Size", Range(0, 1)) = 0.5
        _Wave_1_Steepness("Steepness", Range(0, 1)) = 0.5
        _Wave_1_Angle("Wave Angle", Range(0, 365)) = 0
        [Header(Wave 2 Parameters)][Space(10)]
        [PowerSlider(0.2)] _Wave_2_Size("Wave Size", Range(0, 1)) = 0.5
        _Wave_2_Steepness("Steepness", Range(0, 1)) = 0.5
        _Wave_2_Angle("Wave Angle", Range(0, 365)) = 0
        [Header(Wave 3 Parameters)][Space(10)]
        [PowerSlider(0.2)] _Wave_3_Size("Wave Size", Range(0, 1)) = 0.5
        _Wave_3_Steepness("Steepness", Range(0, 1)) = 0.5
        _Wave_3_Angle("Wave Angle", Range(0, 365)) = 0
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

        Pass {
            Name "Forward Lit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull Off
            Blend One Zero
            ZTest LEqual
            ZWrite Off

            HLSLPROGRAM

            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore

            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma multi_compile_vertex _ _SIMULATEWAVES_ON
            #pragma multi_compile_fragment _ _SSR_ON
            #pragma multi_compile _ _ADDITIONAL_LIGHTS

            #include "WaterProgram.hlsl"

            ENDHLSL
        }
    }
}