using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WaterTextureDebugRenderPass : ScriptableRenderPass
{
    private RTHandle temp;

    private readonly Material material;

    public WaterTextureDebugRenderPass(Material material)
    { this.material = material; }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var currentDescriptor = renderingData.cameraData.renderer.cameraColorTargetHandle.rt.descriptor;
        RenderingUtils.ReAllocateIfNeeded(ref temp, currentDescriptor);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
        var cmd = CommandBufferPool.Get();
        cmd.Blit(temp, cameraTarget, material, material.FindPass("Debug Blit"));
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        temp?.Release();
    }
}