using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;
using UnityEngine.UI;

/// <summary>
/// 相机渲染类：编辑器渲染
/// </summary>
public partial class CameraRenderer
{
#if UNITY_EDITOR //内容只会在unity编辑器中执行，打包后不会被执行。
    
    //SRP不支持的着色器标签类型
    private static ShaderTagId[] legacyShaderTagIds =
    {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM")
    };
    
    //粉红颜色错误材质
    static Material errorMaterial;

    /// <summary>
    /// 绘制SRP不支持的着色器类型
    /// </summary>
    partial void DrawUnsupportedShaders()
    {
        //不支持的ShaderTag类型我们使用错误材质专用Shader来渲染(粉色颜色)
        if (errorMaterial == null)
        {
            errorMaterial = new Material(Shader.Find("Hidden/InternalErrorShader"));
        }
        
        //数组第一个元素用来构造DrawingSettings对象的时候设置
        var drawingSettings = new DrawingSettings(legacyShaderTagIds[0], new SortingSettings(camera))
            { overrideMaterial = errorMaterial };
        
        //将所有不支持的着色器类型标签添加到绘制设置中
        for (int i = 1; i < legacyShaderTagIds.Length; i++)
        {
            //遍历数组逐个设置着色器的PassName，从i=1开始
            drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
        }
        
        //使用默认设置即可，反正画出来的都是不支持的
        var filteringSettings = FilteringSettings.defaultValue;
        
        //绘制不支持的ShaderTag类型的物体
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }
#endif
/*******************************************************************************/
#if UNITY_EDITOR
    /// <summary>
    /// 绘制Gizmos
    /// </summary>
    partial void DrawGizmos()
    {
        if (Handles.ShouldRenderGizmos()) //该方法决定是否绘制 Gizmos
        {
            //参数：给定当前视图的相机，需要绘制的 Gizmos 子集
            //子集一共有两个，用于指定应在图像效果（后处理效果）之前还是之后绘制 Gizmos
            //这里对两个子集都进行绘制
            context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
            context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
        }
    }
#endif
/*******************************************************************************/
#if UNITY_EDITOR
    /// <summary>
    /// 在Game视图绘制的几何体也绘制到Scene视图中
    /// </summary>
    partial void PrepareForSceneWindow()
    {
        //判断相机如果是在 Scene 视图渲染出来的，就将 UI 发送到 Scene 视图进行渲染
        if(camera.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
        }
    }
#endif 
/*******************************************************************************/
#if UNITY_EDITOR
    //如果是在编辑器下运行，定义一个 SampleName 属性，使用相机的名字给它和缓冲区的名字赋值
    string SampleName {get; set;}
    
    /// <summary>
    /// 设置命令缓冲区的名字
    /// </summary>
    partial void PrepareBuffer()
    {
        //设置一下只有在编辑器模式下才分配内存,而不在构建项目后运行时分配内存
        Profiler.BeginSample("Editor Only");
        
        //buffer.name 用于在 Frame Debugger 中识别CommandBuffer的名称
        //为了区分多个相机渲染的条目，使用相机的名字去设置命令缓冲区的名字
        buffer.name = SampleName = camera.name;
        
        Profiler.EndSample();
    }
#else
    //如果是在其它平台下运行，则 SampleName 只是作为一个常量字符串 bufferName，也就是 "Render Camera"。
    const string SampleName = bufferName;    
#endif
}