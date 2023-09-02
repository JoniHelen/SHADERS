using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthMipData
{
    public int MipCount;
    public List<Vector2Int> MipSizes = new();
    public List<Vector2Int> MipOffsets = new();
}

public class DepthPyramidRenderPass : ScriptableRenderPass
{
    private RTHandle depthPyramidTexture;
    private readonly ComputeShader depthShader;
    private readonly int depthKernel;
    private readonly int copyKernel;
    private readonly Material material;

    private DepthMipData mipData;

    public static int DivRoundUp(float dividend, float divisor)
        => Mathf.CeilToInt(dividend / divisor);

    private static DepthMipData ComputeMipData(RenderTextureDescriptor descriptor)
    {
        var result = new DepthMipData();
        result.MipCount++;
        result.MipOffsets.Add(Vector2Int.zero);
        result.MipSizes.Add(new Vector2Int(descriptor.width, descriptor.height));
        var mipSize = result.MipSizes[0];
        do
        {
            // Round up.
            mipSize.x = Mathf.Max(1, (mipSize.x + 1) >> 1);
            mipSize.y = Mathf.Max(1, (mipSize.y + 1) >> 1);

            var prevMipBegin = result.MipOffsets[^1];
            var prevMipEnd = prevMipBegin + result.MipSizes[^1];

            result.MipSizes.Add(mipSize);

            var mipBegin = new Vector2Int();

            if ((result.MipCount & 1) != 0) // Odd
            {
                mipBegin.x = prevMipBegin.x;
                mipBegin.y = prevMipEnd.y;
            }
            else // Even
            {
                mipBegin.x = prevMipEnd.x;
                mipBegin.y = prevMipBegin.y;
            }
            
            result.MipOffsets.Add(mipBegin);

            result.MipCount++;
            
        } while (mipSize.x > 1 || mipSize.y > 1);

        return result;
    }

    public DepthPyramidRenderPass(Material material, ComputeShader shader, ref RTHandle depthTexture)
    {
        depthPyramidTexture = depthTexture;
        depthShader = shader;
        depthKernel = depthShader.FindKernel("GeneratePyramid");
        copyKernel = depthShader.FindKernel("InitialCopy");
        this.material = material;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var descriptor = renderingData.cameraData.renderer.cameraColorTargetHandle.rt.descriptor;
        mipData = ComputeMipData(descriptor);
        var mipParams = new Vector2Int[mipData.MipCount * 2];
        for (var i = 0; i < mipData.MipCount; i++)
        {
            mipParams[i * 2] = mipData.MipOffsets[i];
            mipParams[i * 2 + 1] = mipData.MipSizes[i];
        }
        WaterSurface.MipDataBuffer.SetData(mipParams);
        material.SetInt(WaterSurface.MipCount, mipData.MipCount);
        descriptor.enableRandomWrite = true;
        descriptor.height += DivRoundUp(descriptor.height, 2);
        RenderingUtils.ReAllocateIfNeeded(ref depthPyramidTexture, descriptor);
        
        material.SetTexture(WaterSurface.DepthMipChain, depthPyramidTexture);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get();
        
        cmd.SetComputeTextureParam(depthShader, copyKernel, WaterSurface.DepthMipChain, depthPyramidTexture);
        cmd.DispatchCompute(depthShader, copyKernel, DivRoundUp(mipData.MipSizes[0].x, 8), DivRoundUp(mipData.MipSizes[0].y, 8),
            1);
        
        var srcOffsets = new int[4];
        var dstOffsets = new int[4];
        
        for (var i = 1; i < mipData.MipCount; i++)
        {
            var dstSize = mipData.MipSizes[i];
            var dstOffset = mipData.MipOffsets[i];
            var srcSize = mipData.MipSizes[i - 1];
            var srcOffset = mipData.MipOffsets[i - 1];
            var srcLimit = srcOffset + srcSize - Vector2Int.one;
            
            srcOffsets[0] = srcOffset.x;
            srcOffsets[1] = srcOffset.y;
            srcOffsets[2] = srcLimit.x;
            srcOffsets[3] = srcLimit.y;
            
            dstOffsets[0] = dstOffset.x;
            dstOffsets[1] = dstOffset.y;
            dstOffsets[2] = 0;
            dstOffsets[3] = 0;

            cmd.SetComputeIntParams(depthShader, WaterSurface.SrcOffsetAndLimit, srcOffsets);
            cmd.SetComputeIntParams(depthShader, WaterSurface.DstOffset, dstOffsets);
            cmd.SetComputeTextureParam(depthShader, depthKernel, WaterSurface.DepthMipChain, depthPyramidTexture);

            cmd.DispatchCompute(depthShader, depthKernel, DivRoundUp(dstSize.x, 8), DivRoundUp(dstSize.y, 8),
                1);
        }
        
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}