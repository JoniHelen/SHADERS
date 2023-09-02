using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WaterColorRenderPass : ScriptableRenderPass
{
    public Mesh Mesh;

    private Matrix4x4 matrix = Matrix4x4.identity;

    private readonly Material material;

    public WaterColorRenderPass(Material material)
    { this.material = material; }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get();
        cmd.DrawMesh(Mesh, matrix, material, 0, material.FindPass("Color Pass"));
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}