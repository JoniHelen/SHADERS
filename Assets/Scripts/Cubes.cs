using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Cubes : MonoBehaviour
{
    [SerializeField] private float Angle;
    [SerializeField] private ComputeShader CubeShader;
    [SerializeField] private Mesh CubeMesh;
    [SerializeField] private Material CubeMaterial;

    private static int CubeKernel;
    private static readonly int Direction = Shader.PropertyToID("Direction");
    private static readonly int Positions = Shader.PropertyToID("Positions");

    private const int CubeAmount = 128 * 128;

    private Vector3[] CubePositions = new Vector3[CubeAmount];

    private Matrix4x4[] CubeMatrices = new Matrix4x4[CubeAmount];

    private void PopulateCubes(Vector3[] cubes)
    {
        for (int x = 0; x < 128; ++x)
        {
            for (int y = 0; y < 128; ++y)
            {
                int idx = x * 128 + y;
                cubes[idx] = new Vector3(x / 128f, 0, y / 128f);
            }
        }
    }
    
    private ComputeBuffer CubeBuffer;

    private void Start()
    {
        CubeBuffer = new ComputeBuffer(CubeAmount, 3 * sizeof(float));
        PopulateCubes(CubePositions);
        CubeShader.SetBuffer(CubeKernel, Positions, CubeBuffer);
        CubeKernel = CubeShader.FindKernel("CSMain");
    }
    
    private void Update()
    {
        CubeBuffer.SetData(CubePositions);
        
        Vector2 dir = new Vector2(Mathf.Sin(Mathf.Deg2Rad * Angle), Mathf.Cos(Mathf.Deg2Rad * Angle));
        CubeShader.SetVector(Direction, dir);
        CubeShader.Dispatch(CubeKernel, 16, 16, 1);

        CubeBuffer.GetData(CubePositions);
        
        for (int i = 0; i < CubeAmount; ++i)
        {
            CubeMatrices[i] = Matrix4x4.TRS(CubePositions[i] + transform.position, Quaternion.identity, Vector3.one * (1 / 128f));
        }
        
        Graphics.DrawMeshInstanced(CubeMesh, 0, CubeMaterial, CubeMatrices);
    }

    private void OnDisable()
    {
        CubeBuffer?.Dispose();
    }

    private void OnDestroy()
    {
        CubeBuffer?.Dispose();
    }
}
