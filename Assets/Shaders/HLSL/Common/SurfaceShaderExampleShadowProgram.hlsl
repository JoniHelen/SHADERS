// GPU Instancing
#pragma multi_compile_instancing
            
#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

float3 _LightPosition;
float3 _LightDirection;

struct Attributes {
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionHCS : SV_POSITION;
};

Varyings Vertex(const Attributes input) {
	Varyings output;
	
	UNITY_SETUP_INSTANCE_ID(input);
	
    const float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    const float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
	
	// Define shadow pass specific clip position for Universal
	#if _CASTING_PUNCTUAL_LIGHT_SHADOW
		const float3 lightDirectionWS = normalize(_LightPosition - positionWS);
	#else
		const float3 lightDirectionWS = _LightDirection;
	#endif
		output.positionHCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
	#if UNITY_REVERSED_Z
		output.positionHCS.z = min(output.positionHCS.z, UNITY_NEAR_CLIP_VALUE);
	#else
		output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

	return output;
}

half4 Fragment(const Varyings IN) : SV_TARGET {
	return 0;
}