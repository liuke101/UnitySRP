using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
/// <summary>
/// 自定义渲染管线资产类，用于创建自定义渲染管线
/// </summary>
//在Project下右键->Create菜单中添加一个新的子菜单,用来创建管线资产
[CreateAssetMenu(menuName = "Rendering/Create Custom Render Pipeline")]
public class CustomRenderPineAsset : RenderPipelineAsset
{
    //定义合批状态字段
    [SerializeField] private bool useDynamicBatching = true;
    [SerializeField] private bool useGPUInstancing = true;
    [SerializeField] private bool userSRPBatcher = true;
    
    //阴影设置
    [SerializeField] private ShadowSettings shadows = default;
    
    //重写抽象方法，需要返回一个RenderPipeline实例对象
    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderPipeline(useDynamicBatching, useGPUInstancing, userSRPBatcher,shadows);
    }
}
