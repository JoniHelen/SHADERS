#ifndef CUSTOM_MAIN_LIGHT_INCLUDED
#define CUSTOM_MAIN_LIGHT_INCLUDED

void MainLight_float(out half3 Direction, out half3 Color, out float DistanceAtten, out half ShadowAtten, out uint LayerMask) {

    Direction = 0;
    Color = 0;
    DistanceAtten = 0;
    ShadowAtten = 0;
    LayerMask = 0;

    #ifdef UNIVERSAL_REALTIME_LIGHTS_INCLUDED
    Light light = GetMainLight();
    Direction = light.direction;
    Color = light.color;
    DistanceAtten = light.distanceAttenuation;
    ShadowAtten = light.shadowAttenuation;
    LayerMask = light.layerMask;
    #endif
}

#endif