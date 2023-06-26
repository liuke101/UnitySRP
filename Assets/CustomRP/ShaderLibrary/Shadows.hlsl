//阴影图集采样库
#ifndef CUSTOM_SHADOWS_INCLUDE
#define CUSTOM_SHADOWS_INCLUDE
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

//如果使用的是PCF 3X3
#if defined(_DIRECTIONAL_PCF3)
//需要4个滤波样本，因为每个样本都使用双线性 2X2 的滤波模式，在所有方向上偏移半个纹素的平方覆盖了 3×3 的 Tent Filter，其中心的权重大于边缘
#define DIRECTIONAL_FILTER_SAMPLES 4
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
#define DIRECTIONAL_FILTER_SAMPLES 9
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
#define DIRECTIONAL_FILTER_SAMPLES 16
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

//支持投影的最大光源数
#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4

//最大级联数量
#define MAX_CASCADE_COUNT 4

//阴影图集纹理
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

/*******************************************************************************/

//【常量缓冲区】
CBUFFER_START(_CustomShadows)
int _CascadeCount; //级联数量
float4 _CascadeData[MAX_CASCADE_COUNT]; //级联数据
float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT]; //级联包围球数据
float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT]; //阴影转换矩阵
//float _ShadowDistance; //阴影最大距离
float4 _ShadowDistanceFade; //阴影衰减距离
float4 _ShadowAtlasSize; //阴影图集大小
CBUFFER_END

/*******************************************************************************/

//阴影的数据信息
//由Shadows.ReserveDirectionalShadows方法设置
struct DirectionalShadowData
{
    float strength; //阴影强度
    int tileIndex; //图集中的图块索引
    float normalBias; //法线偏移
    int shadowMaskChannel;  //阴影遮罩通道
};

//烘焙阴影数据  
struct ShadowMask  
{
    bool always; //标记了阴影遮罩是否使用了ShadowMask模式
    bool distance;  //标记了阴影遮罩是否使用了Distance ShadowMask模式
    float4 shadows;  //存储烘焙的阴影数据
};

//存储表面阴影数据
struct ShadowData
{
    int cascadeIndex; //级联索引
    float strength; //阴影有效性标识符，超出最后一个级联范围就设为0，不对阴影进行采样
    float cascadeBlend; //级联混合
    ShadowMask shadowMask;  
};



/*******************************************************************************/

/**
 * \brief 采样阴影图集
 * \param positionSTS 阴影纹理空间的表面位置
 * \return 
 */
float SampleDirectionalShadowAtlas(float3 positionSTS)
{
    return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}

/**
 * \brief 计算PCF滤波 权重和
 * \param positionSTS 阴影纹理空间的表面位置
 * \return 
 */
float FilterDirectionalShadow(float3 positionSTS)
{
    #if defined(DIRECTIONAL_FILTER_SETUP)
    //样本权重
    float weights[DIRECTIONAL_FILTER_SAMPLES];
    //样本位置
    float2 positions[DIRECTIONAL_FILTER_SAMPLES];
    float4 size = _ShadowAtlasSize.yyxx;
    DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
    float shadow = 0;
    for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) 
    {
        //遍历所有样本得到权重和
        shadow += weights[i] * SampleDirectionalShadowAtlas(
        float3(positions[i].xy, positionSTS.z));
    }
    
    
    return shadow;
    #else
    return SampleDirectionalShadowAtlas(positionSTS);
    #endif
}

/*******************************************************************************/

//计算级联阴影（实时阴影）
float GetCascadedShadow(DirectionalShadowData directional, ShadowData global, Surface surfaceWS)   
{  
    //计算法线偏移 
    float3 normalBias = surfaceWS.normal * (directional.normalBias * _CascadeData[global.cascadeIndex].y);  

    //通过阴影转换矩阵和表面位置得到在阴影纹理(图块)空间的位置，然后对图集进行采样
    float3 positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex], float4(surfaceWS.position + normalBias, 1.0)).xyz;  
    float shadow = FilterDirectionalShadow(positionSTS);  

    //如果级联混合小于1代表在在级联层级过渡区域中，必须从下一个级联中采样ShadowMap并得到当前级联的阴影衰减，根据级联混合属性值对两个级联的阴影衰减强度进行插值
    if (global.cascadeBlend < 1.0)   
    {  
        normalBias = surfaceWS.normal *(directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);  
        positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex + 1], float4(surfaceWS.position + normalBias, 1.0)).xyz;  
        shadow = lerp(FilterDirectionalShadow(positionSTS), shadow, global.cascadeBlend);  
    }  
    return shadow;  
}
/*******************************************************************************/

//得到烘焙阴影的衰减值
float GetBakedShadow(ShadowMask mask, int channel)   
{  
    float shadow = 1.0;
    //若 ShadowMask Mode使用Distance ShadowMask 模式，我们返回烘焙阴影数据的 R 分量
    if (mask.always || mask.distance) 
    {
        //光源使用了ShadowMask时
        if (channel >= 0)   
        {  
            shadow = mask.shadows[channel];  
        }   
    }  
    return shadow;  
}

//根据传入的灯光阴影强度对烘焙阴影进行插值得到烘焙阴影的衰减值
float GetBakedShadow(ShadowMask mask, int channel, float strength)   
{  
    if (mask.always || mask.distance)   
    {  
        return lerp(1.0, GetBakedShadow(mask,channel), strength); 
    }  
    return 1.0;  
}


/*******************************************************************************/

//混合烘焙和实时阴影  
float MixBakedAndRealtimeShadows(ShadowData global, float shadow, int shadowMaskChannel, float strength)   
{  
    float baked = GetBakedShadow(global.shadowMask, shadowMaskChannel);

    //若 ShadowMask Mode使用Distance ShadowMask 模式，混合烘焙和实时阴影
    if (global.shadowMask.distance)   
    {  
        shadow = lerp(1.0, shadow, global.strength);  
        shadow = min(baked, shadow);  
        return lerp(1.0, shadow, strength);  
    }  
    return lerp(1.0, shadow, strength * global.strength);  
}
/*******************************************************************************/


//计算阴影衰减
//将烘焙阴影和实时阴影进行混合，在超过阴影最大距离时使用烘焙阴影，距离之内使用实时阴影。
float GetDirectionalShadowAttenuation(DirectionalShadowData directional, ShadowData global, Surface surfaceWS)
{
    //如果不接受阴影，阴影衰减为1
    #if !defined(_RECEIVE_SHADOWS)
    return 1.0;
    #endif
    float shadow;
    
    if (directional.strength * global.strength <= 0.0)   
    {
        //传递的灯光阴影强度的绝对值，这样即使在阴影最大距离外或者关闭了实时阴影的投射也可以得到正确的烘焙阴影。
        shadow = GetBakedShadow(global.shadowMask, abs(directional.strength)); 
    }
    else   
    {
        shadow = GetCascadedShadow(directional, global, surfaceWS);

        //混合阴影获得最终衰减结果
        shadow = MixBakedAndRealtimeShadows(global, shadow, directional.shadowMaskChannel, directional.strength); 
        
    }     
    return shadow;
}

/*******************************************************************************/

//线性淡化公式计算阴影衰减的强度
float FadedShadowStrength(float distance, float scale, float fade)
{
    return saturate((1.0 - distance * scale) * fade);
}


/*******************************************************************************/

//返回世界空间的表面阴影数据
ShadowData GetShadowData(Surface surfaceWS)
{
    ShadowData data;
    data.cascadeBlend = 1.0;
    //当表面深度比最大阴影距离小时，才进行阴影采样
    data.strength = FadedShadowStrength(surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
    data.shadowMask.always = false;  
    data.shadowMask.distance = false;
    data.shadowMask.shadows = 1.0;
    

    
    int i;
    //级联混合
    for (i = 0; i < _CascadeCount; i++)
    {
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);

        if (distanceSqr < sphere.w)
        {
            //计算级联阴影的衰减强度
            float fade = FadedShadowStrength(distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);

            //如果对象处在最后一个级联范围中
            //和阴影最大距离的阴影衰减强度相乘得到最终阴影强度
            //否则将阴影衰减强度赋值给级联混合属性
            if (i == _CascadeCount - 1)
            {
                data.strength *= fade;
            }
            else
            {
                data.cascadeBlend = fade;
            }
            break;
        }
    }

    //如果超出最后一个级联范围,标识符设为0，不对阴影采样
    if (i == _CascadeCount)
    {
        data.strength = 0.0;
    }

    //混合模式为抖动模式时，如果我们不在最后一个级联中，且当级联混合值小于抖动值时，则跳到下一个级联
    #if defined(_CASCADE_BLEND_DITHER)
    else if (data.cascadeBlend < surfaceWS.dither) 
    {
        i += 1;
    }
    #endif
    //级联混合模式如果是Soft则将级联混合值设为 1
    #if !defined(_CASCADE_BLEND_SOFT)
    data.cascadeBlend = 1.0;
    #endif
    data.cascadeIndex = i; //得到合适的级联层级索引

    return data;
}


#endif
