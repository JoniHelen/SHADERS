using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class GameOfLife : MonoBehaviour
{
    public enum GameInit
    {
        RPentomino,
        Acorn,
        GosperGun,
        FullTexture
    }
    
    [SerializeField] private ComputeShader Simulator;
    [SerializeField] private bool WrapEdges;
    [SerializeField] private Material PlaneMaterial;
    [SerializeField] private float UpdateInterval = 2;
    [SerializeField] private GameInit InitSeed;
    [SerializeField] private Color CellColor;

    private float NextUpdate = 2;

    private static readonly Vector2Int TexSize = new(512, 512);
    
    private RenderTexture State1;
    private RenderTexture State2;

    private bool CurrentState;
    
    private static readonly int BaseMap = Shader.PropertyToID("_BaseMap");
    private static readonly int CellColour = Shader.PropertyToID("CellColour");
    private static readonly int TextureSize = Shader.PropertyToID("TextureSize");
    private static readonly int State1Tex = Shader.PropertyToID("State1");
    private static readonly int State2Tex = Shader.PropertyToID("State2");

    private static int State1Kernel;
    private static int State2Kernel;
    
    private static int RPentominoKernel;
    private static int AcornKernel;
    private static int GunKernel;
    private static int FullKernel;
    
    private void Start()
    {
        State1 = new RenderTexture(TexSize.x, TexSize.y, 0, DefaultFormat.LDR)
        {
            filterMode = FilterMode.Point,
            enableRandomWrite = true,
            wrapMode = TextureWrapMode.Repeat
        };

        State1.Create();
        
        State2 = new RenderTexture(TexSize.x, TexSize.y, 0, DefaultFormat.LDR)
        {
            filterMode = FilterMode.Point,
            enableRandomWrite = true,
            wrapMode = TextureWrapMode.Repeat
        };

        State2.Create();

        State1Kernel = Simulator.FindKernel("Update1");
        State2Kernel = Simulator.FindKernel("Update2");
        RPentominoKernel = Simulator.FindKernel("InitRPentomino");
        AcornKernel = Simulator.FindKernel("InitAcorn");
        GunKernel = Simulator.FindKernel("InitGun");
        FullKernel = Simulator.FindKernel("InitFullTexture");
        
        Simulator.SetTexture(State1Kernel, State1Tex, State1);
        Simulator.SetTexture(State1Kernel, State2Tex, State2);
        
        Simulator.SetTexture(State2Kernel, State1Tex, State1);
        Simulator.SetTexture(State2Kernel, State2Tex, State2);
        
        Simulator.SetTexture(RPentominoKernel, State1Tex, State1);
        Simulator.SetTexture(AcornKernel, State1Tex, State1);
        Simulator.SetTexture(GunKernel, State1Tex, State1);
        Simulator.SetTexture(FullKernel, State1Tex, State1);
        
        Simulator.SetVector(CellColour, CellColor);
        Simulator.SetVector(TextureSize, new Vector4(TexSize.x, TexSize.y));

        if (WrapEdges)
            Shader.EnableKeyword("WRAP_EDGES");
        else
            Shader.DisableKeyword("WRAP_EDGES");
        
        switch (InitSeed)
        {
            case GameInit.RPentomino:
                Simulator.Dispatch(RPentominoKernel, TexSize.x / 8, TexSize.y / 8, 1);
                break;
            case GameInit.Acorn:
                Simulator.Dispatch(AcornKernel, TexSize.x / 8, TexSize.y / 8, 1);
                break;
            case GameInit.GosperGun:
                Simulator.Dispatch(GunKernel, TexSize.x / 8, TexSize.y / 8, 1);
                break;
            case GameInit.FullTexture:
                Simulator.Dispatch(FullKernel, TexSize.x / 8, TexSize.y / 8, 1);
                break;
            default:
                break;
        }
    }

    private void Update()
    {
        if (!(Time.time >= NextUpdate)) return;
        
        CurrentState = !CurrentState;
        Simulator.Dispatch(CurrentState ? State1Kernel : State2Kernel, TexSize.x / 8, TexSize.y / 8, 1);
        PlaneMaterial.SetTexture(BaseMap, CurrentState ? State1 : State2);

        NextUpdate = Time.time + UpdateInterval;
    }

    private void OnDestroy()
    {
        State1.Release();
        State2.Release();
    }
    
    private void OnDisable()
    {
        State1.Release();
        State2.Release();
    }
}