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
        public float slopeScaleBias;   //斜度比例偏移
        public float nearPlaneOffset; //阴影视椎体近裁剪平面偏移
    }
    
    //存储所有能产生阴影的定向光索引
    ShadowedDirectionalLight[] shadowedDirctionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    //已存储的可投射阴影的定向光数量
    private int ShadowedDirectionalLightCount;

    //阴影图集
    static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");
    
    //最大级联数量
    const int maxCascades = 4;
    
    //级联数据
    static int cascadeDataId = Shader.PropertyToID("_CascadeData");
    static Vector4[] cascadeData = new Vector4[maxCascades];
    
    //级联数量 Properties ID
    static int cascadeCountId = Shader.PropertyToID("_CascadeCount");
    
    //级联包围球 Properties ID
    static int cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres");
    
    //级联混合模式 Properties ID
    static string[] cascadeBlendKeywords = {"_CASCADE_BLEND_SOFT","_CASCADE_BLEND_DITHER"};
    
    //存储级联包围球数据，XYZ分量存储包围球的位置，W分量存储球体半径
    static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];
    
    //阴影衰减距离 Properties ID
    static int shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");
    
    //阴影转换矩阵:世界空间到阴影图块裁剪空间的转换矩阵
    static int dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");
    
    //存储阴影转换矩阵
    private static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];
    
    /*******************************************************************************/
    
    //PCF滤波模式  
    static string[] directionalFilterKeywords =   
    {  
        "_DIRECTIONAL_PCF3",  
        "_DIRECTIONAL_PCF5",  
        "_DIRECTIONAL_PCF7",  
    };  
    
    //阴影的图集大小 Properties ID
    static int shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize");  
    
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
    public Vector3 ReserveDirectionalShadows(Light light,int visibleLightIndex)
    {
        //存储可见光源的索引
        //前提
        //1.光源开启了阴影投射并且阴影强度不能为0
        //2.在阴影最大投射距离内有被该光源影响且需要投影的物体存在，如果没有就不需要渲染该光源的ShadowMap了
        if(ShadowedDirectionalLightCount<maxShadowedDirectionalLightCount&&
           light.shadows!=LightShadows.None&&light.shadowStrength>0.0f&&
           cullingResults.GetShadowCasterBounds(visibleLightIndex,out Bounds b))
        {
            //创建 ShadowedDirectionalLight 实例
            shadowedDirctionalLights[ShadowedDirectionalLightCount] = new ShadowedDirectionalLight
            {
                visibleLightIndex = visibleLightIndex,
                slopeScaleBias = light.shadowBias,
                nearPlaneOffset = light.shadowNearPlane
            };
            
            //返回阴影强度\阴影图块的偏移\法线偏移
            return new Vector3(
                light.shadowStrength,
                settings.directional.cascadeCount * ShadowedDirectionalLightCount++,
                light.shadowNormalBias);
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
        
        //级联数据发送GPU
        buffer.SetGlobalVectorArray(cascadeDataId,cascadeData);
        
        //将级联数量和包围球数据发送到GPU
        buffer.SetGlobalInt(cascadeCountId, settings.directional.cascadeCount);
        buffer.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        
        //阴影转换矩阵传入GPU
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);

        //把阴影最大距离和阴影衰减距离的倒数传递给 GPU
        float f = 1.0f - settings.directional.cascadeFade;
        buffer.SetGlobalVector(shadowDistanceFadeId,new Vector4(1.0f / settings.maxDistance, 1.0f / settings.distanceFade,1.0f / (1.0f - f * f)));
        
        //设置PCF滤波模式
        SetKeywords(directionalFilterKeywords,(int)settings.directional.filter - 1);
        
        //设置级联混合模式
        SetKeywords(cascadeBlendKeywords,(int)settings.directional.cascadeBlendMode - 1);
        
        //传递图集大小和纹素大小  
        buffer.SetGlobalVector( shadowAtlasSizeId, new Vector4(atlasSize, 1f / atlasSize));
        
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

        //剔除偏差
        float cullingFactor = Mathf.Max(0f, 0.8f - settings.directional.cascadeFade);
        
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
                light.nearPlaneOffset, //阴影近平面偏移
                out Matrix4x4 viewMatrix, //光源的观察矩阵
                out Matrix4x4 projectionMatrix, //光源的投影矩阵
                out ShadowSplitData splitData); //ShadowSplitData 对象，包含了如何剔除投影对象的信息
            
            //我们让所有的光源都使用相同的级联，所以只需要拿到第一个定向光的包围球数据即可
            if (index == 0)
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }
            
            //剔除偏差
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;
            
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
            
            //绘制阴影前，设置斜度比例偏差值
            buffer.SetGlobalDepthBias(0, light.slopeScaleBias);
            ExecuteBuffer();
            
            //绘制阴影
            //注意：DrawShadows 方法只渲染 Shader 中带有 ShadowCaster Pass 通道的物体
            context.DrawShadows(ref shadowSettings);
            
            //绘制阴影后全局深度偏差归零
            buffer.SetGlobalDepthBias(0f, 0f);
        }
    }

    /*******************************************************************************/
    
    /// <summary>
    /// 设置级联数据
    /// </summary>
    /// <param name="index"></param>
    /// <param name="cullingSphere"></param>
    /// <param name="tileSize"></param>
    private void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
    {
        //包围球直径除以阴影图块尺寸=纹素大小
        float texelSize = 2f * cullingSphere.w / tileSize;
        
        //增加PCF滤波的样本区域意味着最终在最后一个级联的包围球范围之外也有可能进行采样
        //要在计算包围球半径的平方之前，使用包围球半径减去经过调整后的纹素大小（偏差大小）来避免这种情况。**
        float filterSize = texelSize * ((float)settings.directional.filter + 1f);
        cullingSphere.w -= filterSize;
        
        //在Shadows.hlsl中判断物体表面的片元是否在包围球中，可以通过该片元到球心距离的平方和球体半径的平方来比较
        //传递数据之前先计算好球体半径的平方，就不用再在着色器中计算了
        cullingSphere.w *= cullingSphere.w; //*=得到半径的平方值
        cascadeCullingSpheres[index] = cullingSphere;
        
        //纹素是正方形，最坏的情况是不得不沿着正方形的对角线偏移，所以将纹素大小乘以根号2进行缩放
        cascadeData[index] = new Vector4(1.0f / cullingSphere.w, texelSize * 1.4142136f);
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
    
    /// <summary>
    /// 设置关键字
    /// </summary>
    void SetKeywords(string[] keywords, int enabledIndex)
    {
        for (int i = 0; i < keywords.Length; i++)
        {
            if (i == enabledIndex)
            {
                buffer.EnableShaderKeyword(keywords[i]);
            }
            else
            {
                buffer.DisableShaderKeyword(keywords[i]);
            }
        }
    }
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