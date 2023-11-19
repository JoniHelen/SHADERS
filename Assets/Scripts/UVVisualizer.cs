using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class UVVisualizer : MonoBehaviour
{
    [SerializeField] private ComputeShader UVShader;
    [SerializeField] private Material VisualizationMaterial;

    private RenderTexture UVTexture;

    private static int MainKernel;
    
    private static readonly int BaseMap = Shader.PropertyToID("_BaseMap");
    private static readonly int UVMap = Shader.PropertyToID("UVMap");

    void Start()
    {
        MainKernel = UVShader.FindKernel("VisualizeUV");

        UVTexture = new RenderTexture(1024, 1024, 0, DefaultFormat.LDR)
        {
            enableRandomWrite = true
        };

        UVTexture.Create();
        VisualizationMaterial.SetTexture(BaseMap, UVTexture);
        
        UVShader.SetTexture(MainKernel, UVMap, UVTexture);
        
        UVShader.Dispatch(MainKernel, 1024 / 8, 1024 / 8, 1);
    }

    private void OnDisable()
    {
        UVTexture.Release();
    }

    private void OnDestroy()
    {
        UVTexture.Release();
    }
}