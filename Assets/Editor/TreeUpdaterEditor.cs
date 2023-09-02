using UnityEditor;
using UnityEngine.UIElements;

[CustomEditor(typeof(TreeUpdater))]
public class TreeUpdaterEditor : Editor
{
    public VisualTreeAsset inspectorXML;

    public override VisualElement CreateInspectorGUI()
    {
        var inspector = new VisualElement();
        inspectorXML.CloneTree(inspector);
        inspector.Q<Button>("updateButton").clicked += ((TreeUpdater)target).UpdateAllTrees;
        return inspector;
    }
}
