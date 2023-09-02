using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ProjectionVisualizer : MonoBehaviour
{
    [Range(0f, 1f)]
    public float ObjectToWorld;

    [Range(0f, 1f)]
    public float WorldToView;

    [Range(0f, 1f)]
    public float ViewToClip;

    [Range(0f, 1f)]
    public float ClipToNDC;

    public Vector3 ObjectWorldPosition;
    public Vector3 ObjectWorldRotation;
    public Vector3 ObjectWorldScale;

    [SerializeField]
    private Camera testCamera;
    private MeshFilter meshFilter;
    private Mesh mesh;

    private Vector3 frustumPostition;
    private Quaternion frustumRotation;

    private readonly Vector3[] modelVertices = new Vector3[] { 
            new Vector3(1, 1, 1),
            new Vector3(-1, 1, -1),
            new Vector3(1, 1, -1),
            new Vector3(-1, 1, 1),
            new Vector3(1, -1, 1),
            new Vector3(-1, -1, -1),
            new Vector3(1, -1, -1),
            new Vector3(-1, -1, 1)
    };

    private readonly Vector3[] modelNormals = new Vector3[] {
        Vector3.up, Vector3.up, Vector3.up, Vector3.up, Vector3.up, Vector3.up,
        Vector3.left, Vector3.left, Vector3.left, Vector3.left, Vector3.left, Vector3.left,
        Vector3.down, Vector3.down, Vector3.down, Vector3.down, Vector3.down, Vector3.down,
        Vector3.right, Vector3.right, Vector3.right, Vector3.right, Vector3.right, Vector3.right,
        Vector3.forward, Vector3.forward, Vector3.forward, Vector3.forward, Vector3.forward, Vector3.forward,
        Vector3.back, Vector3.back, Vector3.back, Vector3.back, Vector3.back, Vector3.back
    };

    private readonly int[] modelTriangles = new int[] { 
        2, 1, 0, 1, 3, 0, 1, 5, 3, 5, 7, 3, 5, 6, 7, 6, 4, 7, 6, 2, 4, 2, 0, 4, 4, 0, 7, 0, 3, 7, 5, 1, 6, 1, 2, 6
    };

    private void OnDrawGizmos()
    {
        //Origin
        Gizmos.color = Color.white;
        Gizmos.DrawSphere(Vector3.zero, 0.1f);

        // NDC
        Gizmos.color = Color.blue;
        Gizmos.DrawWireCube(Vector3.zero, Vector3.one * 2);

        // Frustum
        Gizmos.color = Color.green;
        Gizmos.matrix = Matrix4x4.TRS(frustumPostition + testCamera.transform.position, frustumRotation, Vector3.one);
        Gizmos.DrawFrustum(Vector3.zero, testCamera.fieldOfView, testCamera.farClipPlane, testCamera.nearClipPlane, testCamera.aspect);
    }

    private void OnValidate()
    {
        meshFilter = GetComponent<MeshFilter>();
        if (meshFilter.sharedMesh == null)
        {
            mesh = new Mesh()
            {
                name = "Generated Cube Mesh"
            };
            meshFilter.sharedMesh = mesh;
        }
        else
            mesh = meshFilter.sharedMesh;

        // Final vertices that get displayed
        Vector3[] finalVertices = new Vector3[modelVertices.Length];

        // Final normals
        Vector3[] finalNormals = new Vector3[modelNormals.Length];

        // Model matrix
        Matrix4x4 ModelMatrix = Matrix4x4.TRS(ObjectWorldPosition, Quaternion.Euler(ObjectWorldRotation), ObjectWorldScale);

        // View matrix
        Matrix4x4 ViewMatrix =  testCamera.transform.worldToLocalMatrix;

        // Projection matrix
        Matrix4x4 ProjectionMatrix = testCamera.projectionMatrix;

        ProjectionMatrix.SetColumn(2, ProjectionMatrix.GetColumn(2) * -1); // Gets rid of Unity's z-flip

        // The order of multiplication is important here

        // MV Matrix
        Matrix4x4 MVMatrix = ViewMatrix * ModelMatrix;

        // MVP Matrix
        Matrix4x4 MVPMatrix = ProjectionMatrix * ViewMatrix * ModelMatrix;


        // Rotate the normals to fix lighting. Transform does this automatically
        for (int i = 0; i < finalNormals.Length; i++)
        {
            Vector3 WorldNormal = ModelMatrix * new Vector4(modelNormals[i].x, modelNormals[i].y, modelNormals[i].z, 0); // ignore translation
            finalNormals[i] = Vector3.Slerp(modelNormals[i], WorldNormal, ObjectToWorld);
        }

        if (ObjectToWorld < 1)
        {
            frustumPostition = Vector3.zero;
            frustumRotation = testCamera.transform.rotation;

            // Interpolate between object and world space
            for (int i = 0;i < finalVertices.Length; i++)
            {
                Vector3 WorldPosition = ModelMatrix * new Vector4(modelVertices[i].x, modelVertices[i].y, modelVertices[i].z, 1);
                finalVertices[i] = Vector3.Lerp(modelVertices[i], WorldPosition, ObjectToWorld);
            }
        }
        else if (WorldToView < 1)
        {
            // Interpolate between world and view space
            for (int i = 0; i < finalVertices.Length; i++)
            {
                Vector3 WorldPosition = ModelMatrix * new Vector4(modelVertices[i].x, modelVertices[i].y, modelVertices[i].z, 1);
                Vector3 ViewPosition = MVMatrix * new Vector4(modelVertices[i].x, modelVertices[i].y, modelVertices[i].z, 1);
                finalVertices[i] = Vector3.Lerp(WorldPosition, ViewPosition, WorldToView);
            }

            // Change the frustum to reflect the change in coordinate systems
            frustumPostition = Vector3.Lerp(Vector3.zero, new Vector3(0, -1, 10), WorldToView);
            frustumRotation = Quaternion.Lerp(testCamera.transform.rotation, Quaternion.identity, WorldToView);
        }
        else if (ViewToClip < 1)
        {
            frustumPostition = new Vector3(0, -1, 10);
            frustumRotation = Quaternion.identity;

            // Interpolate between view and clip space
            for (int i = 0; i < finalVertices.Length; i++)
            {
                Vector3 ViewPosition = MVMatrix * new Vector4(modelVertices[i].x, modelVertices[i].y, modelVertices[i].z, 1);
                Vector3 ClipPosition = MVPMatrix * new Vector4(modelVertices[i].x, modelVertices[i].y, modelVertices[i].z, 1);
                finalVertices[i] = Vector3.Lerp(ViewPosition, ClipPosition, ViewToClip);
            }
        }
        else if (ClipToNDC <= 1)
        {
            frustumPostition = new Vector3(0, -1, 10);
            frustumRotation = Quaternion.identity;

            // Interpolate between clip and NDC space
            for (int i = 0; i < finalVertices.Length; i++)
            {
                Vector4 ClipPosition = MVPMatrix * new Vector4(modelVertices[i].x, modelVertices[i].y, modelVertices[i].z, 1);
                Vector3 NDCPosition = new Vector3(ClipPosition.x / ClipPosition.w, ClipPosition.y / ClipPosition.w, ClipPosition.z / ClipPosition.w);
                finalVertices[i] = Vector3.Lerp(new Vector3(ClipPosition.x, ClipPosition.y, ClipPosition.z), NDCPosition, ClipToNDC);
            }
        }

        // Vertices need to be deindexed, otherwise the edges would be round due to insufficient normal data.
        mesh.vertices = DeIndexVerticesForCube(finalVertices, out int[] linearIndices);
        mesh.triangles = linearIndices;
        mesh.normals = finalNormals;
        mesh.RecalculateBounds();
    }

    private Vector3[] DeIndexVerticesForCube(Vector3[] vertices, out int[] linearIndices)
    {
        Vector3[] deIndexedVerts = new Vector3[modelTriangles.Length];
        linearIndices = new int[modelTriangles.Length];

        for (int i = 0; i < modelTriangles.Length; i++)
        {
            deIndexedVerts[i] = vertices[modelTriangles[i]];
            linearIndices[i] = i;
        }

        return deIndexedVerts;
    }
}
