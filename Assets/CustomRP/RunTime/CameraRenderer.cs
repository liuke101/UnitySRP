using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;

/// <summary>
/// 相机渲染类，进行单个相机的单独渲染
/// </summary>
public partial class CameraRenderer
{
    Camera camera;

    //SRP 用于渲染的底层接口，使用封装的各种方法实现基本的渲染绘制
    ScriptableRenderContext context;

    //用于在 Frame Debugger 中识别CommandBuffer的名称
    const string bufferName = "Render Camera";

    //渲染接口CommandBuffer,用于存储渲染命令
    CommandBuffer buffer = new CommandBuffer { name = bufferName };

    //存储相机剔除后的所有视野内可见物体的数据信息
    CullingResults cullingResults;

    //着色器标记 ID 用于引用着色器中的各种名称。
    
    //获取 Pass 中名字为 SRPDefaultUnlit 的着色器标签ID(对应Tags里的属性)
    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
    //获取 Pass 中名字为 CustomLit 的着色器标签
    static ShaderTagId litShaderTagId = new ShaderTagId("CustomLit");
    
    //绘制SRP不支持的着色器类型
    partial void DrawUnsupportedShaders();

    //绘制Gizmos
    partial void DrawGizmos();

    //在Game视图绘制的几何体也绘制到Scene视图中
    partial void PrepareForSceneWindow();

    //设置命令缓冲区的名字
    partial void PrepareBuffer();

    //设置灯光
    Lighting lighting = new Lighting();
/*******************************************************************************/

    /// <summary>
    /// 绘制在相机视野内的所有物体
    /// </summary>
    public void Render(ScriptableRenderContext context, Camera camera,bool useDynamicBatching, bool useGPUInstancing,ShadowSettings shadowSettings)
    {
        this.context = context;
        this.camera = camera;

        PrepareBuffer();

        //此操作可能会给 Scene 场景中添加一些几何体，所以我们在 Render() 方法中进行几何体剔除之前调用这个方法。
        PrepareForSceneWindow();

        //剔除
        if (!Cull(shadowSettings.maxDistance))
        {
            return;
        }
        
        buffer.BeginSample(SampleName); 
        ExecuteBuffer();
        //光源数据发送到GPU计算光照 + 渲染阴影
        lighting.Setup(context, cullingResults, shadowSettings);
        buffer.EndSample(SampleName);
        
        //渲染场景开始前的设置
        Setup(); //设置结束后进行buffer.BeginSample(SampleName)
        
        //绘制可见几何体
        DrawVisibleGeometry(useDynamicBatching, useGPUInstancing);

        //绘制SRP不支持的着色器类型
        DrawUnsupportedShaders();

        //绘制Gizmos
        DrawGizmos();
        
        //释放ShadowMap RT内存
        lighting.Cleanup();
        
        //提交缓冲区渲染命令
        Submit(); //提交前进行buffer.EndSample(SampleName)
    }

/*******************************************************************************/

    /// <summary>
    /// 剔除相机视野外的物体
    /// </summary>
    /// <returns></returns>
    bool Cull(float maxShadowDistance)
    {
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p)) //得到需要进行剔除检查的所有物体
        {
            //得到最大阴影距离，和相机远截面做比较，取最小的那个作为阴影距离
            p.shadowDistance = Mathf.Min(maxShadowDistance, camera.farClipPlane);
            
            cullingResults = context.Cull(ref p); //存储剔除后的结果数据
            return true;
        }

        return false;
    }

/*******************************************************************************/

    /// <summary>
    /// 绘制可见几何体
    /// 绘制顺序：不透明物体->绘制天空盒->透明物体
    /// </summary>
    void DrawVisibleGeometry(bool useDynamicBatching,bool useGPUInstancing)
    {
        //1.绘制不透明物体
        //设置绘制顺序和指定渲染相机：确定相机的透明排序模式是否使用正交或基于距离的排序
        var sortingSettings = new SortingSettings(camera)
        {
            criteria = SortingCriteria.CommonOpaque //不透明对象的典型排序模式
        };

        //设置渲染的Shader Pass和排序模式：设置是哪个 Shader 的哪个 Pass 进行渲染
        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings)
        {
            enableDynamicBatching = useDynamicBatching,
            enableInstancing = useGPUInstancing,
            perObjectData = PerObjectData.Lightmaps | PerObjectData.ShadowMask | PerObjectData.LightProbe | PerObjectData.OcclusionProbe | PerObjectData.LightProbeProxyVolume | PerObjectData.OcclusionProbeProxyVolume
            
        };
        
        //渲染CustomLit表示的pass块
        drawingSettings.SetShaderPassName(1, litShaderTagId);

        //过滤设置：设置哪些类型的渲染队列可以被绘制
        var fileteringSettings = new FilteringSettings(RenderQueueRange.opaque); //只绘制RenderQueue为opaque的不透明物体

        //图像绘制
        context.DrawRenderers(cullingResults, ref drawingSettings, ref fileteringSettings);

        //2.绘制天空盒
        context.DrawSkybox(camera);

        //3.绘制透明物体
        sortingSettings.criteria = SortingCriteria.CommonTransparent; //透明对象的典型排序模式
        drawingSettings.sortingSettings = sortingSettings;
        fileteringSettings.renderQueueRange = RenderQueueRange.transparent; //只绘制RenderQueue为transparent的透明的物体
        context.DrawRenderers(cullingResults, ref drawingSettings, ref fileteringSettings);
    }


/*******************************************************************************/

    /// <summary>
    /// 渲染场景开始前的设置
    /// 设置相机的属性和矩阵
    /// </summary>
    void Setup()
    {
        //设置相机特定的全局ShaderProperties
        context.SetupCameraProperties(camera); 

        //得到相机的清除标志Clear Flags 
        //这是一个枚举值，从小到大分别是 Skybox，Color(Solid Color)，Depth 和 Nothing
        CameraClearFlags flags = camera.clearFlags;

        //清除渲染目标，为了保证下一帧绘制的图像正确
        buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth, //当相机的Clear Flags 设置为前三个枚举时，都会清除深度缓冲区
            flags == CameraClearFlags.SolidColor, //当相机的Clear Flags 设置为 Solid Color 时才清除颜色缓冲
            flags == CameraClearFlags.Color ? camera.backgroundColor.linear : Color.clear //清除缓冲区的颜色值，如果我们设置的 Clear Flags 是 Color，那么需要使用相机的 Background 属性的颜色值，由于我们使用的是线性色彩空间，颜色值进行一下转换，其它的 Clear Flags 还默认使用 Color.clear（黑色）即可
        );
        
        buffer.BeginSample(SampleName);
        ExecuteBuffer();
    }

/*******************************************************************************/

    /// <summary>
    /// 提交缓冲区渲染命令
    /// </summary>
    void Submit()
    {
        //结束采样，放在渲染过程的结束
        buffer.EndSample(SampleName); 
        ExecuteBuffer();
        
        //通过 context 发送的渲染命令都是缓冲的，最后需要通过调用 Submit() 方法来正式提交渲染命令
        context.Submit();
    }

/*******************************************************************************/

    /// <summary>
    /// 执行缓冲区命令
    /// </summary>
    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear(); //通常执行命令和清除缓冲区是一起执行的，这样才能重用缓冲区
    }

/*******************************************************************************/
}