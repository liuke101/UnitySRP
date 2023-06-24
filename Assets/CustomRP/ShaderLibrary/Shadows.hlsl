//阴影图集采样库
#ifndef CUSTOM_SHADOWS_INCLUDE
#define CUSTOM_SHADOWS_INCLUDE

//支持投影的最大光源数
#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4

//最大级联数量
#define MAX_CASCADE_COUNT 4

//阴影图集纹理
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
//阴影转换矩阵
float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
CBUFFER_END

//阴影的数据信息
//由Shadows.ReserveDirectionalShadows方法设置
struct DirectionalShadowData
{
    float strength; //阴影强度
    int tileIndex;  //图集中的图块索引
};

/**
 * \brief 采样阴影图集
 * \param positionSTS 阴影纹理空间的表面位置
 * \return 
 */
float SampleDirectionalShadowAtlas(float3 positionSTS)
{
    return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}

//计算阴影衰减
float GetDirectionalShadowAttenuation(DirectionalShadowData data, Surface surfaceWS)
{
    //当灯光的阴影强度属性被降到0时，阴影衰减就不受阴影影响了，衰减值始终为1
    if (data.strength <= 0.0)
    {
        return 1.0;
    }

    //通过阴影转换矩阵和表面位置得到在阴影纹理(图块)空间的位置，然后对图集进行采样
    float3 positionSTS = mul(_DirectionalShadowMatrices[data.tileIndex], float4(surfaceWS.position, 1.0)).xyz;
    float shadow = SampleDirectionalShadowAtlas(positionSTS);

    //插值得到最终的阴影衰减
    return lerp(1.0, shadow, data.strength);
}

#endif
