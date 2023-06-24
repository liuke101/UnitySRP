using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomShaderGUI : ShaderGUI
{
    //显示和编辑材质的属性
    private MaterialEditor editor;
    
    //正在编辑的材质的引用对象,通过材质编辑器的 Targets 属性得到
    private Object[] materials;
    
    //可以编辑的属性数组
    private MaterialProperty[] properties;

    //GUI折叠
    private bool showPresets;
    
    public override void OnGUI(MaterialEditor materialEditor,MaterialProperty[] properties)
    {
        base.OnGUI(materialEditor, properties);
        this.editor = materialEditor;
        this.materials = materialEditor.targets;
        this.properties = properties;
        
        EditorGUILayout.Space();
        
        //折叠
        showPresets = EditorGUILayout.Foldout(showPresets,"Presets",true);
        if (showPresets)
        {
            //下面四个方法是四个Button
            OpaquePreset();
            ClipPreset();
            FadePreset();
            TransparentPreset();
        }
    }
    
    //设置材质属性
    bool SetProperty(string name, float value)
    {
        MaterialProperty property = FindProperty(name, properties, false);
        if (property != null)
        {
            property.floatValue = value;
            return true;
        }
        
        return false;
    }
    
    //同时设置关键字和属性
    void SetProperty(string name, string keyword, bool value)
    {
        if (SetProperty(name, value ? 1.0f : 0.0f))
        {
            SetKeyword(keyword, value);
        }
    }

    //设置关键字状态
    void SetKeyword(string keyword, bool enable)
    {
        if (enable)
        {
            foreach (Material material in materials)
            {
                material.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material material in materials)
            {
                material.DisableKeyword(keyword);
            }
        }
    }
    
    
    bool Clipping
    {
        set => SetProperty("_Clipping", "_CLIPPING", value);
    }
    
    bool PremultiplyAlpha
    {
        set => SetProperty("_PremulAlpha", "_PREMULTIPLY_ALPHA", value);
    }
    
    BlendMode SrcBlend
    {
        set => SetProperty("_SrcBlend", (float) value);
    }
    
    BlendMode DstBlend
    {
        set => SetProperty("_DstBlend", (float) value);
    }
    
    bool ZWrite
    {
        set => SetProperty("_ZWrite", value ? 1.0f : 0.0f);
    }
    
    RenderQueue RenderQueue
    {
        set
        {
            foreach (Material material in materials)
            {
                material.renderQueue = (int) value;
            }
        }
    }

    //给每种渲染模式（注意这里的渲染模式是自定义的一种叫法,不是RenderMode也不是RenderType）创建一个按钮
    bool PresetButton(string name)
    {
        if (GUILayout.Button(name))
        {
            //属性重置
            editor.RegisterPropertyChangeUndo(name);
            return true;
        }

        return false;
    }
    
    //不透明渲染模式的的材质属性设置
    void OpaquePreset()
    {
        if (PresetButton("Opaque"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.Geometry;
        }
    }

    //透明度测试模式的材质属性设置
    void ClipPreset()
    {
        if (PresetButton("Clip"))
        {
            Clipping = true;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.AlphaTest;
        }
    }
    
    //透明度混合模式的材质属性设置
    void FadePreset()
    {
        if (PresetButton("Fade"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.SrcAlpha;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
        }
    }
    
    //如果shader的预乘属性不存在，不需要显示对应渲染模式的预设置按钮
    bool HasProperty(string name) => FindProperty(name,properties,false) != null;
    bool HasPremultiplyAlpha => HasProperty("_PremulAlpha");
    
    //透明度预乘模式的材质属性设置
    void TransparentPreset()
    {
        if (HasPremultiplyAlpha && PresetButton("Transparent"))
        {
            Clipping = false;
            PremultiplyAlpha = true;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
        }
    }
    
    

}
