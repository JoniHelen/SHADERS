using UnityEngine;
using UnityEditor;
using System.Linq;

public class ExampleShaderGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        var baseMapProperty = properties.FirstOrDefault(x => x.name == "_BaseMap");
        var baseColorProperty = properties.FirstOrDefault(x => x.name == "_BaseColor");
        if (baseColorProperty != null && baseMapProperty != null) {
            materialEditor.TexturePropertySingleLine(new GUIContent("Base Map"), baseMapProperty, baseColorProperty);
            materialEditor.TextureScaleOffsetProperty(baseMapProperty);
        }
        else if (baseColorProperty != null)
            materialEditor.ShaderProperty(baseColorProperty, new GUIContent("Base Color"));
        
        var normalMapProperty = properties.FirstOrDefault(x => x.name == "_NormalMap");
        if (normalMapProperty != null)
            materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map"), normalMapProperty);
        
        var roughnessMapProperty = properties.FirstOrDefault(x => x.name == "_RoughnessMap");
        if (roughnessMapProperty != null)
            materialEditor.TexturePropertySingleLine(new GUIContent("Roughness Map"), roughnessMapProperty);
        
        var ambientMapProperty = properties.FirstOrDefault(x => x.name == "_OcclusionMap");
        if (ambientMapProperty != null)
            materialEditor.TexturePropertySingleLine(new GUIContent("Ambient Occlusion Map"), ambientMapProperty);
        
        var metallicMapProperty = properties.FirstOrDefault(x => x.name == "_MetallicMap");
        if (metallicMapProperty != null)
            materialEditor.TexturePropertySingleLine(new GUIContent("Metallic Map"), metallicMapProperty);
        
        var parallaxMapProperty = properties.FirstOrDefault(x => x.name == "_ParallaxMap");
        var parallaxStrengthProperty = properties.FirstOrDefault(x => x.name == "_ParallaxStrength");
        if (parallaxMapProperty != null)
            materialEditor.TexturePropertySingleLine(new GUIContent("Parallax Map"), parallaxMapProperty, parallaxStrengthProperty);
        
        materialEditor.RenderQueueField();
        materialEditor.EnableInstancingField();
        materialEditor.DoubleSidedGIField();
    }
}