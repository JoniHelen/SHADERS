using UnityEngine;

public class TreeModelMatrixUpdater : MonoBehaviour
{
    private static readonly int TreeMatrix = Shader.PropertyToID("_TreeMatrix");
    private static readonly int LeafMatrix = Shader.PropertyToID("_LeafMatrix");
    
    public void UpdateTreeMatrices()
    {
        var renderers = GetComponentsInChildren<Renderer>();

        var block = new MaterialPropertyBlock();
        block.SetMatrix("_TreeMatrix", transform.worldToLocalMatrix);
        block.SetMatrix("_LeafMatrix", transform.localToWorldMatrix);
        foreach (var rend in renderers) {
            rend.SetPropertyBlock(block);
        }
    }
}