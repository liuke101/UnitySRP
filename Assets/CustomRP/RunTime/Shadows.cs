using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Shadows
{
    //用于在 Frame Debugger 中识别CommandBuffer的名称
    const string bufferName = "Shadows";
    
    //渲染接口CommandBuffer,用于存储渲染命令
    CommandBuffer buffer = new CommandBuffer { name = bufferName };
    
    //渲染上下文
    ScriptableRenderContext context;
    
    //存储相机剔除后的结果
    CullingResults cullingResults;
    /*******************************************************************************/
    
    //阴影设置
    ShadowSettings settings;
 
    //最大可投射阴影的定向光数量
    private const int maxShadowedDirectionalLightCount = 4;
    
    //产生阴影的定向光
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;  //产生阴影的可见光索引
    }
    
    //存储所有能产生阴影的定向光索引
    ShadowedDirectionalLight[] shadowedDirctionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    //已存储的可投射阴影的定向光数量
    private int ShadowedDirectionalLightCount;

    //阴影图集
    static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");
    
    //最大级联数量
    const int maxCascades = 4;
    
    //阴影转换矩阵:世界空间到阴影图块裁剪空间的转换矩阵
    static int dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");
    
    //存储阴影转换矩阵
    static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];
    
    
    /*******************************************************************************/
    
    /// <summary>
    /// 阴影数据设置
    /// </summary>
    /// <param name="context"></param>
    /// <param name="cullingResults"></param>
    /// <param name="settings"></param>
    public void Setup(ScriptableRenderContext context,CullingResults cullingResults,ShadowSettings settings)
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;
        
        ShadowedDirectionalLightCount = 0;
    }
    
    /*******************************************************************************/
    
    /// <summary>
    /// 存储可见光的阴影数据
    /// 目的:是在阴影图集中为该光源的ShadowMap保留空间，并存储渲染它们所需要的信息
    /// </summary>
    /// <param name="light"></param>
    /// <param name="visibleLightIndex"></param>
    public Vector2 ReserveDirectionalShadows(Light light,int visibleLightIndex)
    {
        //存储可见光源的索引
        //前提
        //1.光源开启了阴影投射并且阴影强度不能为0
        //2.在阴影最大投射距离内有被该光源影响且需要投影的物体存在，如果没有就不需要渲染该光源的ShadowMap了
        if(ShadowedDirectionalLightCount<maxShadowedDirectionalLightCount&&
           light.shadows!=LightShadows.None&&light.shadowStrength>0.0f&&
           cullingResults.GetShadowCasterBounds(visibleLightIndex,out Bounds b))
        {
            shadowedDirctionalLights[ShadowedDirectionalLightCount] = new ShadowedDirectionalLight
            {
                visibleLightIndex = visibleLightIndex
            };
            
            //返回阴影强度和阴影图块的偏移
            return new Vector2(light.shadowStrength,settings.directional.cascadeCount * ShadowedDirectionalLightCount++);
        }
        
        //如果光源没有阴影则返回零向量
        return Vector2.zero;
    }
    /*******************************************************************************/
    
    /// <summary>
    /// 渲染阴影
    /// </summary>
    public void Render()
    {
        if(ShadowedDirectionalLightCount > 0)
        {
            RenderDirectionalShadows();
        }
    }

    /*******************************************************************************/
    /// <summary>
    /// 渲染所有定向光阴影
    /// </summary>
    private void RenderDirectionalShadows()
    {
        //ShadowMap纹理尺寸
        int atlasSize = (int)settings.directional.atlasSize;
        
        //创建RT，并指定该类型为shadowmap
        buffer.GetTemporaryRT(dirShadowAtlasId,atlasSize,atlasSize,32,FilterMode.Bilinear,
            RenderTextureFormat.Shadowmap);
        
        //指定渲染数据存储到RT
        buffer.SetRenderTarget(dirShadowAtlasId,RenderBufferLoadAction.DontCare,RenderBufferStoreAction.Store);
        
        //清除渲染目标的数据
        buffer.ClearRenderTarget(true,false,Color.clear);

        buffer.BeginSample(bufferName);
        ExecuteBuffer();
        
        //要分割的图块大小和数量
        int tiles = ShadowedDirectionalLightCount * settings.directional.cascadeCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;

        //遍历所有定向光渲染阴影
        for (int i = 0; i < ShadowedDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }
        
        //将转换矩阵发送到 GPU
        buffer.SetGlobalMatrixArray(dirShadowMatricesId,dirShadowMatrices);

        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    /// <summary>
    /// 释放临时RT
    /// </summary>
    public void Cleanup()
    {
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }
    /*******************************************************************************/
    
    /// <summary>
    /// 渲染单个光源阴影
    /// </summary>
    /// <param name="index">产生阴影的定向光索引</param>
    /// <param name="split">分割数量</param>
    /// <param name="tileSize">ShadowMap尺寸</param>
    void RenderDirectionalShadows(int index,int split,int tileSize)
    {
        //产生阴影的可见光索引
        ShadowedDirectionalLight light = shadowedDirctionalLights[index];
        
        //创建阴影设置对象
        var shadowSettings = new ShadowDrawingSettings(cullingResults,light.visibleLightIndex);
        
        //得到级联ShadowMap需要的参数
        int cascadeCount = settings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = settings.directional.CascadeRatios;

        for (int i = 0; i < cascadeCount; i++)
        {
            //定向光没有一个真实位置，我们要找出与光的方向匹配的视图和投影矩阵
            //并给我们一个裁剪空间的立方体，该立方体与包含光源阴影的摄影机的可见区域重叠
            //使用该方法获取上述信息
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, //可见光的索引
                i, //设置阴影级联数据
                cascadeCount, //设置阴影级联数据
                ratios, //设置阴影级联数据
                tileSize, //ShadowMap尺寸
                0.1f, //阴影近平面偏移
                out Matrix4x4 viewMatrix, //光源的观察矩阵
                out Matrix4x4 projectionMatrix, //光源的投影矩阵
                out ShadowSplitData splitData); //ShadowSplitData 对象，包含了如何剔除投影对象的信息

            //设置ShadowSplitData
            shadowSettings.splitData = splitData;
            
            //调整图块索引，它等于光源的图块偏移加上级联的索引
            int tileIndex = tileOffset + i;
            
            //设置渲染视口
            //SetTileViewport(index, split, tileSize);

            //得到从世界空间到阴影纹理图块裁剪空间的转换矩阵
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(
                projectionMatrix * viewMatrix, //光源的投影矩阵乘以视图矩阵，得到从世界空间到光源裁剪空间的转换矩阵VP
                SetTileViewport(tileIndex, split, tileSize),
                split);


            //设置视图和投影矩阵
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            ExecuteBuffer();

            //绘制阴影
            //注意：DrawShadows 方法只渲染 Shader 中带有 ShadowCaster Pass 通道的物体
            context.DrawShadows(ref shadowSettings);
        }
    }
    
    /*******************************************************************************/

    /// <summary>
    /// 调整渲染视口来渲染单个图块
    /// </summary>
    /// <param name="index">图块索引</param>
    /// <param name="split">拆分的图块数量</param>
    /// <param name="tileSize">图块大小</param>
    Vector2 SetTileViewport(int index, int split, float tileSize)
    {
        //计算索引图快的偏移位置
        Vector2 offset = new Vector2(index % split, index / split);
        //设置渲染视口 拆分成多个图块
        buffer.SetViewport(new Rect(offset.x * tileSize, offset.y * tileSize, tileSize, tileSize));

        return offset;
    }
    
    /*******************************************************************************/

    /// <summary>
    /// 世界空间到阴影图块裁剪空间的转换矩阵
    /// </summary>
    /// <param name="m"></param>
    /// <param name="offset"></param>
    /// <param name="split"></param>
    /// <returns></returns>
    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
    {
        //如果图形API使用了反向Zbuffer,就将矩阵的Z分量的值进行反转
        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        
        //设置矩阵坐标
        float scale = 1f / split;
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        
        return m;
    }
    
    /*******************************************************************************/
    
    
    /*******************************************************************************/
    
    /// <summary>
    /// 执行缓冲区命令
    /// </summary>
    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    
}