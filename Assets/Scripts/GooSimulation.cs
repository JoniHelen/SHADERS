using System;
using System.Runtime.InteropServices;
using Unity.Collections;
using Unity.Mathematics;
using UnityEngine;

public class GooSimulation : MonoBehaviour
{
    [StructLayout(LayoutKind.Sequential)]
    public struct BallData
    {
        public float3 Position;
        public int PartitionIndex;
        public float3 Velocity;
        public int IndexInPartitions;

        public static int Size => 32; // 8 * 4-byte values
    }

    [StructLayout(LayoutKind.Sequential)]
    public unsafe struct Partition
    {
        public float3 ExtentsMin;
        public int Length;
        public float3 ExtentsMax;
        public int IndexInPartitions;
        public fixed int PartitionBlock[27];
        public int BlockLength;

        public static int Size => 144; // 36 * 4-byte values
    }

    [Header("Simulation"), Space(10)]
    public ComputeShader SimulationShader;

    [Header("Goo Properties"), Space(10)]

    [Range(0f, 10f), Tooltip("How much gravity affects the Goo.")]
    public float GravityFactor = 1;

    [Range(0f, 10f), Tooltip("How bouncy the goo is.")]
    public float RepulsionFactor = 1;

    [Header("Cube Properties"), Space(10)]
    public bool ManualRotation = false;

    private ComputeBuffer BallBuffer, SimulationResultBuffer;
    private ComputeBuffer PartitionBuffer, IndexBuffer;

    private const float BallRadius = 0.0625f;
    private const int BallCount = 512;

    private Material BallMaterial;
    private Vector3 mousePos;
    private int SimulationKernel, ResolveKernel, PartitionKernel;

    private NativeArray<BallData> NewBalls
    {
        get {
            var balls = new NativeArray<BallData>(BallCount, Allocator.Temp);
            for (int x = 0; x < 8; x++)
                for (int y = 0; y < 8; y++)
                    for (int z = 0; z < 8; z++) {
                        int flattenedIndex = x * 64 + y * 8 + z;
                        balls[flattenedIndex] = new BallData {
                            Position = new float3() {
                                x = x / 8f - 0.5f,
                                y = y / 8f - 0.5f,
                                z = z / 8f - 0.5f
                            } + BallRadius,
                            PartitionIndex = flattenedIndex,
                            IndexInPartitions = flattenedIndex * BallCount
                        };
                    }
            return balls;
        }
    }

    private NativeArray<int> NewIndices
    {
        get
        {
            var indices = new NativeArray<int>(BallCount * BallCount, Allocator.Temp);
            for (int i = 0; i < BallCount; i++)
                indices[i * BallCount] = i;
            return indices;
        }
    }

    private unsafe NativeArray<Partition> NewPartitions
    {
        get
        {
            var partitions = new NativeArray<Partition>(BallCount, Allocator.Temp);
            for (int x = 0; x < 8; x++)
                for (int y = 0; y < 8; y++)
                    for (int z = 0; z < 8; z++)
                    {
                        var flattenedIndex = x * 64 + y * 8 + z;
                        var min = new float3
                        {
                            x = x / 8f - 0.5f,
                            y = y / 8f - 0.5f,
                            z = z / 8f - 0.5f
                        };
                        var block = CreatePartitionBlock(new int3(x, y, z), out int length);
                        var partition = new Partition
                        {
                            Length = 1,
                            IndexInPartitions = flattenedIndex * BallCount,
                            ExtentsMin = min,
                            ExtentsMax = min + 2 * BallRadius,
                            BlockLength = length
                        };

                        fixed (int* blockData = block)
                        {
                            for (int i = 0; i < block.Length; i++)
                                partition.PartitionBlock[i] = blockData[i];
                        }

                        partitions[flattenedIndex] = partition;
                    }
            return partitions;
        }
    }

    private ReadOnlySpan<int> CreatePartitionBlock(int3 position, out int blockLength)
    {
        blockLength = 0;
        var block = new int[27];

        for (int x = -1; x <= 1; x++)
            for (int y = -1; y <= 1; y++)
                for (int z = -1; z <= 1; z++)
                {
                    var offset = new int3(x, y, z);
                    var offsetPosition = position + offset;

                    var notValid = offsetPosition < 0;
                    if (math.any(notValid)) continue;
                    notValid = offsetPosition > 8;
                    if (math.any(notValid)) continue;

                    block[blockLength++]
                        = offsetPosition.x * 64
                        + offsetPosition.y * 8
                        + offsetPosition.z;
                }
        return block.AsSpan();
    }

    private void Awake()
    {
        BallMaterial = GetComponent<Renderer>().sharedMaterial;
        BallBuffer = new ComputeBuffer(BallCount, BallData.Size);
        SimulationResultBuffer = new ComputeBuffer(BallCount, BallData.Size);
        PartitionBuffer = new ComputeBuffer(BallCount, Partition.Size);
        IndexBuffer = new ComputeBuffer(BallCount * BallCount, sizeof(int));

        var Balls = NewBalls;
        BallBuffer.SetData(Balls);
        SimulationResultBuffer.SetData(Balls);

        PartitionBuffer.SetData(NewPartitions);
        IndexBuffer.SetData(NewIndices);

        BallMaterial.SetBuffer("Balls", SimulationResultBuffer);

        SimulationKernel = SimulationShader.FindKernel("Simulate");
        ResolveKernel = SimulationShader.FindKernel("Resolve");
        PartitionKernel = SimulationShader.FindKernel("UpdateSpatialPartitions");

        SimulationShader.SetBuffer(SimulationKernel, "Balls", BallBuffer);
        SimulationShader.SetBuffer(SimulationKernel, "SimulationResults", SimulationResultBuffer);
        SimulationShader.SetBuffer(ResolveKernel, "Balls", BallBuffer);
        SimulationShader.SetBuffer(ResolveKernel, "SimulationResults", SimulationResultBuffer);
        SimulationShader.SetBuffer(PartitionKernel, "Balls", BallBuffer);
        SimulationShader.SetBuffer(PartitionKernel, "SimulationResults", SimulationResultBuffer);
        SimulationShader.SetBuffer(PartitionKernel, "BallIndices", IndexBuffer);
        SimulationShader.SetBuffer(PartitionKernel, "Partitions", PartitionBuffer);
    }

    private void Update()
    {
        if (ManualRotation)
        {
            if (Input.GetMouseButtonDown(0))
                mousePos = Input.mousePosition;

            if (Input.GetMouseButton(0))
            {
                Vector3 mouseDelta = mousePos - Input.mousePosition;
                transform.Rotate(new Vector3(-mouseDelta.y, mouseDelta.x, 0) * 0.5f, Space.World);
                mousePos = Input.mousePosition;
            }
        }
        else
            transform.rotation = Quaternion.Euler(100 * Time.time * new Vector3(1, -1, 1));

        SimulationShader.SetVector("Factors", new Vector3(GravityFactor, RepulsionFactor, Time.deltaTime));
        SimulationShader.SetVector("Gravity", transform.InverseTransformDirection(Vector3.down) * 9.81f);
        SimulationShader.Dispatch(SimulationKernel, 1, 1, 1);
        SimulationShader.Dispatch(PartitionKernel, 1, 1, 1);
        SimulationShader.Dispatch(ResolveKernel, 1, 1, 1);
        SimulationShader.Dispatch(PartitionKernel, 1, 1, 1);
    }

    private void OnDestroy()
    {
        BallBuffer.Dispose();
        SimulationResultBuffer.Dispose();
        IndexBuffer.Dispose();
        PartitionBuffer.Dispose();
    }
}