using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WaterSurface : ScriptableRendererFeature
{
    private WaterMetaRenderPass WaterMetaPass 
        => waterMetaPass ??= new WaterMetaRenderPass(settings.WaterMaterial,
            ref positionWSTexture, ref positionHCSTexture, ref normalTexture) {
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents
        };
    
    private WaterSsrRenderPass WaterSsrPass 
        => waterSsrPass ??= new WaterSsrRenderPass(settings.WaterMaterial, ref uvrgTexture, ref lightTexture) {
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents
        };
    
    private WaterColorRenderPass WaterColorPass 
        => waterColorPass ??= new WaterColorRenderPass(settings.WaterMaterial) {
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents
        };
    
    private DepthPyramidRenderPass DepthPyramidPass 
        => depthPyramidPass ??= new DepthPyramidRenderPass(settings.WaterMaterial, settings.depthShader, ref depthPyramidTexture) {
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents
        };
    
    public static GraphicsBuffer MipDataBuffer 
        => mipDataBuffer ??= new GraphicsBuffer(GraphicsBuffer.Target.Structured, 14, 16);

    public enum WaterDebugLayer {
        None, PositionWS, PositionHCS, NormalWS, UVRG, Light
    }

    [System.Serializable]
    public class Settings
    {
        public Material WaterMaterial;
        public Cubemap Skybox;
        public ComputeShader depthShader;
        public WaterDebugLayer Debug;
    }

    private WaterMetaRenderPass waterMetaPass;
    private WaterSsrRenderPass waterSsrPass;
    private WaterColorRenderPass waterColorPass;
    private DepthPyramidRenderPass depthPyramidPass;
    private WaterTextureDebugRenderPass waterDebugPass;

    private RTHandle positionWSTexture;
    private RTHandle positionHCSTexture;
    private RTHandle normalTexture;

    private RTHandle uvrgTexture;
    private RTHandle lightTexture;

    private RTHandle depthPyramidTexture;
    
    private Mesh quadMesh;

    [SerializeField]
    private Settings settings = new();
    
    private static GraphicsBuffer mipDataBuffer;

    private static readonly int Debug = Shader.PropertyToID("_Debug");
    private static readonly int SkyColor = Shader.PropertyToID("_SkyColor");
    private static readonly int DepthPyramidOffsetsAndLimits = Shader.PropertyToID("_DepthPyramidOffsetsAndLimits");
    public static readonly int SrcOffsetAndLimit = Shader.PropertyToID("_SrcOffsetAndLimit");
    public static readonly int DstOffset = Shader.PropertyToID("_DstOffset");
    public static readonly int DepthMipChain = Shader.PropertyToID("_DepthMipChain");
    public static readonly int MipCount = Shader.PropertyToID("_MipCount");
    public static readonly int PositionWs = Shader.PropertyToID("_PositionWS");
    public static readonly int PositionHcs = Shader.PropertyToID("_PositionHCS");
    public static readonly int NormalWs = Shader.PropertyToID("_NormalWS");
    public static readonly int Uvrg = Shader.PropertyToID("_UVRG");
    public static readonly int CollectedLight = Shader.PropertyToID("_CollectedLight");

    public override void Create()
    {
        waterDebugPass = new WaterTextureDebugRenderPass(settings.WaterMaterial) {
            renderPassEvent = RenderPassEvent.AfterRenderingTransparents
        };
        
        quadMesh = new Mesh {
            vertices = new[] {
                new Vector3(1, 1, 0),
                new Vector3(1, -1, 0),
                new Vector3(-1, -1, 0),
                new Vector3(-1, 1, 0)
            },
            uv = new[] {
                new Vector2(1, 0),
                new Vector2(1, 1),
                new Vector2(0, 1),
                new Vector2(0, 0),
            },
            triangles = new[] {
                0, 3, 1,
                1, 3, 2
            }
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.WaterMaterial == null || settings.depthShader == null
            || settings.Skybox == null || renderingData.cameraData.isPreviewCamera) return;

        WaterSsrPass.Mesh = WaterColorPass.Mesh = quadMesh;
        
        settings.WaterMaterial.SetBuffer(DepthPyramidOffsetsAndLimits, MipDataBuffer);
        settings.WaterMaterial.SetTexture(SkyColor, settings.Skybox);
        
        renderer.EnqueuePass(WaterMetaPass);
        renderer.EnqueuePass(DepthPyramidPass);
        renderer.EnqueuePass(WaterSsrPass);
        renderer.EnqueuePass(WaterColorPass);

        if (settings.Debug == WaterDebugLayer.None) return;
        settings.WaterMaterial.SetFloat(Debug, (int)settings.Debug);
        renderer.EnqueuePass(waterDebugPass);
    }

    protected override void Dispose(bool disposing)
    {
        positionWSTexture?.Release();
        positionHCSTexture?.Release();
        normalTexture?.Release();
        uvrgTexture?.Release();
        lightTexture?.Release();
        depthPyramidTexture?.Release();
        MipDataBuffer.Release();
    }
}