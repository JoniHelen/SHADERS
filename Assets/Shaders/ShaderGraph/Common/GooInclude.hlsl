#ifndef CUSTOM_GOO_INCLUDED
#define CUSTOM_GOO_INCLUDED

#include "../../HLSL/Common/CommonGoo.hlsl"

#define _GRAPH_NODE

void Goo_half(half3 positionOS, half3 viewDirOS, half rayBias, half depthBias,
    half3 bakedGI, half smoothness, out half4 color)
{
    #include "../../HLSL/Common/CommonGooRaymarch.hlsl"
}

#endif