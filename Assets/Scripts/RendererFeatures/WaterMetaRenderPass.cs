using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WaterMetaRenderPass : ScriptableRenderPass
{
    private RTHandle positionWSTexture;
    private RTHandle positionHCSTexture;
    private RTHandle normalTexture;
    private RTHandle[] targets;
    private FilteringSettings filter;
    
    private readonly Material material;

    public WaterMetaRenderPass(Material material, ref RTHandle positionWS, ref RTHandle positionHCS, ref RTHandle normalWS)
    {
        this.material = material;
        positionWSTexture = positionWS;
        positionHCSTexture = positionHCS;
        normalTexture = normalWS;
        filter = new FilteringSettings(RenderQueueRange.all, LayerMask.GetMask("Water"));
        targets = new RTHandle[3];
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var currentDescriptor = renderingData.cameraData.renderer.cameraColorTargetHandle.rt.descriptor;

        RenderingUtils.ReAllocateIfNeeded(ref positionWSTexture, currentDescriptor);
        RenderingUtils.ReAllocateIfNeeded(ref positionHCSTexture, currentDescriptor);
        RenderingUtils.ReAllocateIfNeeded(ref normalTexture, currentDescriptor);
        
        material.SetTexture(WaterSurface.PositionWs, positionWSTexture);
        material.SetTexture(WaterSurface.PositionHcs, positionHCSTexture);
        material.SetTexture(WaterSurface.NormalWs, normalTexture);
        
        targets[0] = positionWSTexture;
        targets[1] = positionHCSTexture;
        targets[2] = normalTexture;
        
        ConfigureTarget(targets);
        ConfigureClear(ClearFlag.Color, Color.black);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var settings = new DrawingSettings(new ShaderTagId("UniversalForward"),
            new SortingSettings(renderingData.cameraData.camera)) {
            overrideMaterial = material,
            overrideMaterialPassIndex = material.FindPass("Meta Prepass")
        };
        
        context.DrawRenderers(renderingData.cullResults, ref settings, ref filter);
    }
}