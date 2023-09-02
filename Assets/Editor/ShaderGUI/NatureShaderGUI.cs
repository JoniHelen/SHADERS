using UnityEngine;
using UnityEditor;
using System.Linq;

public class NatureShaderGUI : ShaderGUI
{
    private static readonly int ObjectType = Shader.PropertyToID("_ObjectType");

    private static bool windSettingsOpen;
    private static bool objectSettingsOpen;
    
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        var material = materialEditor.target as Material;
        if (material == null) return;
        
        EditorGUILayout.Separator();

        windSettingsOpen = EditorGUILayout.BeginFoldoutHeaderGroup(windSettingsOpen, new GUIContent("Wind Settings"));
        if (windSettingsOpen)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(properties.First(x => x.name == "_WindStrength"), "Strength");
            materialEditor.ShaderProperty(properties.First(x => x.name == "_WindDirection"), "Direction");
            materialEditor.ShaderProperty(properties.First(x => x.name == "_WindSpeed"), "Speed");
            materialEditor.ShaderProperty(properties.First(x => x.name == "_WindScale"), "Scale");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
        
        EditorGUILayout.Separator();
        
        objectSettingsOpen = EditorGUILayout.BeginFoldoutHeaderGroup(objectSettingsOpen, new GUIContent("Object Settings"));
        if (objectSettingsOpen)
        {
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(properties.First(x => x.name == "_ObjectType"), "Object Type");
            switch (material.GetFloat(ObjectType))
            {
                case 1:
                    var flowerColorProperty = properties.First(x => x.name == "_FlowerColor");
                    materialEditor.ColorProperty(flowerColorProperty, "Flower Color");
                    break;
                case 2:
                    var leafTexProperty = properties.First(x => x.name == "_LeafTexture");
                    var leafTintProperty = properties.First(x => x.name == "_LeafTint");
                    materialEditor.TexturePropertySingleLine(new GUIContent("Texture"), leafTexProperty, leafTintProperty);
                    materialEditor.TextureScaleOffsetProperty(leafTexProperty);
                    materialEditor.ShaderProperty(properties.First(x => x.name == "_LeafSaturation"), "Saturation");
                    materialEditor.ShaderProperty(properties.First(x => x.name == "_LeafEmission"), "Emission");
                    materialEditor.ShaderProperty(properties.First(x => x.name == "_TreeHeight"), "Tree Height");
                    break;
                case 3:
                    var barkTexProperty = properties.First(x => x.name == "_BarkTexture");
                    materialEditor.TexturePropertySingleLine(new GUIContent("Texture"), barkTexProperty);
                    materialEditor.TextureScaleOffsetProperty(barkTexProperty);
                    materialEditor.ShaderProperty(properties.First(x => x.name == "_TreeHeight"), "Tree Height");
                    break;
            }
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
        
        EditorGUILayout.Separator();
        
        materialEditor.RenderQueueField();
        materialEditor.EnableInstancingField();
        materialEditor.DoubleSidedGIField();
    }
}
