using UnityEngine;
using UnityEditor;
using System.Linq;

public class CrackedIceShaderGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        var baseMapProperty = properties.First(x => x.name == "_BaseMap");
        var baseColorProperty = properties.First(x => x.name == "_BaseColor");
        materialEditor.TexturePropertySingleLine(new GUIContent("Base Map"), baseMapProperty, baseColorProperty);
        materialEditor.TextureScaleOffsetProperty(baseMapProperty);
        var normalMapProperty = properties.First(x => x.name == "_NormalMap");
        var snowNormalMapProperty = properties.First(x => x.name == "_SnowNormalMap");
        materialEditor.TexturePropertySingleLine(new GUIContent("Normal Maps"), normalMapProperty, snowNormalMapProperty);
        var roughnessMapProperty = properties.First(x => x.name == "_RoughnessMap");
        materialEditor.TexturePropertySingleLine(new GUIContent("Roughness Map"), roughnessMapProperty);
        var parallaxMapProperty = properties.First(x => x.name == "_ParallaxMap");
        var parallaxStrengthProperty = properties.First(x => x.name == "_ParallaxStrength");
        var parallaxSamplesProperty = properties.First(x => x.name == "_ParallaxSamples");
        materialEditor.TexturePropertySingleLine(new GUIContent("Parallax"), parallaxMapProperty, parallaxStrengthProperty, parallaxSamplesProperty);
        var occlusionStrengthProperty  = properties.First(x => x.name == "_OcclusionStrength");
        materialEditor.ShaderProperty(occlusionStrengthProperty, new GUIContent("Occlusion Strength"));
        materialEditor.RenderQueueField();
        materialEditor.EnableInstancingField();
        materialEditor.DoubleSidedGIField();
    }
}