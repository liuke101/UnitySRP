using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomRenderPipeline : RenderPipeline
{
    private CameraRenderer render = new CameraRenderer();
    private bool useDynamicBatching, useGPUInstancing;
    
    public CustomRenderPipeline(bool useDynamicBatching, bool useGPUInstancing,bool useSRPBatcher)
    {
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        
        //启用 SRP Batcher
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
    }
    
    /// <summary>
    /// SRP的入口函数，每帧都会调用
    /// </summary>
    /// <param name="context">SRP 用于渲染的底层接口，使用封装的各种方法实现基本的渲染绘制</param>
    /// <param name="cameras">相机对象的数组，存储了参与这一帧渲染的所有相机对象</param>
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        //遍历所有相机进行单独渲染,这样设计可以让每个相机使用不同的渲染方式绘制画面
        foreach (Camera camera in cameras)
        {
            render.Render(context, camera,useDynamicBatching, useGPUInstancing);
        }
    }
    
    
}
