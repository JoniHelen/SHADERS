half rayDst = 0;
half3 rayOrigin = positionOS;
const half3 rayDir = -viewDirOS;
    
#if !defined(_DEPTHCULLQUALITY_OFF)
half3 intersectedSpheres[128];
int hitsAmount = 0;
    
half closestHitDistance = 999;
half3 closestHit = 0;
int closestHitIndex;
    
    // Perform distance culling
    
    for (int i = 0; i < BALL_COUNT; i++)
    {
        const half3 pos = Balls[i].Position;
        half3 intersection;
        if (IntersectSphere(rayOrigin, rayDir, pos, BALL_RADIUS, 0, intersection))
        {
            half3 v = rayOrigin - intersection;
            half dist2 = dot(v, v);

            if (dist2 < closestHitDistance)
            {
                closestHitDistance = dist2;
                closestHit = pos;
                closestHitIndex = i;
            }
        }
    }

    if (closestHitDistance != 999)
    {
        intersectedSpheres[0] = closestHit;
        hitsAmount++;
    }

    for (int j = 0; j < BALL_COUNT; j++)
    {
        half3 pos = Balls[j].Position;
        half3 intersection;
        if (IntersectSphere(rayOrigin, rayDir, pos, BALL_RADIUS,
#if defined(_GRAPH_NODE)
        rayBias,
#else
        _RayBias,
#endif
        intersection))
        {
            half3 v = rayOrigin - intersection;
            half dist2 = dot(v, v);

            if (dist2 < closestHitDistance + 
#if defined(_GRAPH_NODE)
            depthBias
#else
            _DepthBias
#endif
            && j != closestHitIndex)
            {
                intersectedSpheres[hitsAmount] = pos;
                hitsAmount++;
            }
        }
    }

    if (hitsAmount == 0)
    {
#if defined(_GRAPH_NODE)
        color = 0;
        return;
#else
        return 0;
#endif
    }
#endif
    
    for (int k = 0; k < 50; k++)
    {
#if defined(_DEPTHCULLQUALITY_OFF)
        const half dist = Distance(rayOrigin);
#else
        const half dist = Distance(rayOrigin, intersectedSpheres, hitsAmount);
#endif

        if (dist <= 0.001)
        {

#if defined(_DEPTHCULLQUALITY_OFF)
            const half3 normalWS = TransformObjectToWorldNormal(CalculateNormal(rayOrigin));
#else
            const half3 normalWS = TransformObjectToWorldNormal(CalculateNormal(rayOrigin, intersectedSpheres, hitsAmount));
#endif
            
            const half3 positionWS = TransformObjectToWorld(rayOrigin);
            
            #ifdef UNIVERSAL_REALTIME_LIGHTS_INCLUDED
            #if defined(_LIGHTINGMETHOD_PBR)
            
            // Populate input data
            InputData lightingInput = (InputData)0;
            lightingInput.positionWS = positionWS;
            lightingInput.positionCS = TransformObjectToHClip(rayOrigin);
            lightingInput.normalWS = normalWS;
            lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(positionWS);
            lightingInput.shadowCoord = TransformWorldToShadowCoord(positionWS);
            #if defined(_GRAPH_NODE)
            lightingInput.bakedGI = bakedGI;
            #else
            #if defined(DYNAMICLIGHTMAP_ON)
                lightingInput.bakedGI = SAMPLE_GI(v.staticLightmapUV, v.dynamicLightmapUV.xy, v.sh, normalWS);
            #else
                lightingInput.bakedGI = SAMPLE_GI(v.staticLightmapUV, v.sh, normalWS);
            #endif
            #endif

            // Populate surface data
            SurfaceData surfaceInput = (SurfaceData)0;
            surfaceInput.albedo = (rayOrigin + 1) / 2;
            surfaceInput.alpha = 1;
            #if defined(_GRAPH_NODE)
            surfaceInput.smoothness = smoothness;
            #else
            surfaceInput.smoothness = _Smoothness;
            #endif
            surfaceInput.occlusion = 0.5;
            
            #if defined(_GRAPH_NODE)
            color = UniversalFragmentPBR(lightingInput, surfaceInput);
            #else
            return UniversalFragmentPBR(lightingInput, surfaceInput);
            #endif
            
            #elif defined(_LIGHTINGMETHOD_DIFFUSE)
            Light light = GetMainLight();
            half3 ambient = 0.1 * light.color;
            half3 diffuse = max(dot(normalWS, light.direction), 0.0) * light.color;
            half3 viewDir = GetWorldSpaceNormalizeViewDir(positionWS);
            half3 reflection = reflect(-light.direction, normalWS);
            half3 specular = pow(max(dot(viewDir, reflection), 0.0), 256) * light.color;
            #if defined(_GRAPH_NODE)
            color = half4((ambient + diffuse + specular * 5) * (rayOrigin + 1) / 2, 1);
            #else
            return half4((ambient + diffuse + specular * 5) * (rayOrigin + 1) / 2, 1);
            #endif
            #endif
            #endif
            #if defined(_GRAPH_NODE)
            return;
            #endif
        }

        rayOrigin += rayDir * dist;
        rayDst += dist;
    }
    
    #if defined(_GRAPH_NODE)
    color = 0;
    #else
    return 0;
    #endif