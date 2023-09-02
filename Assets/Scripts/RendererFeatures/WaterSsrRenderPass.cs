using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WaterSsrRenderPass : ScriptableRenderPass
{
    public Mesh Mesh;

    private RTHandle uvrgTexture;
    private RTHandle lightTexture;

    private Matrix4x4 matrix = Matrix4x4.identity;

    private readonly Material material;

    public WaterSsrRenderPass(Material material, ref RTHandle uvrg, ref RTHandle light)
    {
        this.material = material;
        uvrgTexture = uvrg;
        lightTexture = light;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var currentDescriptor = renderingData.cameraData.renderer.cameraColorTargetHandle.rt.descriptor;

        RenderingUtils.ReAllocateIfNeeded(ref uvrgTexture, currentDescriptor);
        currentDescriptor.enableRandomWrite = true;
        RenderingUtils.ReAllocateIfNeeded(ref lightTexture, currentDescriptor);
            
        material.SetTexture(WaterSurface.Uvrg, uvrgTexture);
        material.SetTexture(WaterSurface.CollectedLight, lightTexture);

        cmd.SetRenderTarget(lightTexture);
        cmd.ClearRenderTarget(false, true, new Color(0, 0, 0, 0));
            
        ConfigureTarget(uvrgTexture);
        ConfigureClear(ClearFlag.Color, Color.black);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get();
        cmd.SetRandomWriteTarget(2, lightTexture.rt.colorBuffer);
        cmd.DrawMesh(Mesh, matrix, material, 0, material.FindPass("SSR Pass"));
        cmd.ClearRandomWriteTargets();
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}