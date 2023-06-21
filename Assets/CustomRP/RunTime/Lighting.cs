using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// 灯光类
/// </summary>
public class Lighting
{
    //用于在 Frame Debugger 中识别CommandBuffer的名称
    const string bufferName = "Lighting";
    
    //渲染接口CommandBuffer,用于存储渲染命令
    CommandBuffer buffer = new CommandBuffer { name = bufferName };
    
    //存储相机剔除后的结果
    CullingResults cullingResults;
    
    //限制最大的可见平行光数量
    const int maxDirLightCount = 4;
    
    //存储可见光的颜色和方向
    Vector4[] dirLightColors = new Vector4[maxDirLightCount];
    Vector4[] dirLightDirections = new Vector4[maxDirLightCount];
    
    //获取Shader中的Properties ID
    static int dirLightCountId = Shader.PropertyToID("_DirectionalLightCount");
    static int dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors");
    static int dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections");
    
    
    
    /// <summary>
    /// 设置光源数据
    /// </summary>
    /// <param name="context"></param>
    public void Setup(ScriptableRenderContext context,CullingResults cullingResults)
    {
        this.cullingResults = cullingResults;
        
        buffer.BeginSample(bufferName);
        
        //多光源数据
        SetupLights();
        
        buffer.EndSample(bufferName);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    /// <summary>
    /// 将所有可见的光源数据传递到GPU
    /// </summary>
    private void SetupLights()
    {
        //获取所有可见的光源
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;

        int dirLightCount = 0;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            //如果是方向光，才把灯光数据存储到数组
            if (visibleLight.lightType == LightType.Directional)
            {
                //VisibleLight结构很大,我们改为传递引用不是传递值，这样不会生成副本
                SetupDirectionalLight(dirLightCount++, ref visibleLight);
                //当超过灯光限制数量中止循环
                if (dirLightCount >= maxDirLightCount)
                {
                    break;
                }
            }
        }
        
        //为所有着色器设置Properties ID对应的值
        buffer.SetGlobalInt(dirLightCountId, dirLightCount);
        buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
    }

    /// <summary>
    /// 将可见光的光照颜色和方向存储到数组
    /// </summary>
    private void SetupDirectionalLight(int index,ref VisibleLight visibleLight)
    {
        // finalColor = 光源强度乘以光源颜色
        dirLightColors[index] = visibleLight.finalColor;
        
        
        // localToWorldMatrix为4x4光源变换矩阵，第三列即为光源的前向向量，将其取反作为光照方向
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        
        Light light = RenderSettings.sun; //程序化天空盒使用的光照，如果没有，则使用最亮的方向光。
    }
    
    
}