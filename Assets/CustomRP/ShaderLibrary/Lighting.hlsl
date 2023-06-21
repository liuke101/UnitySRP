//光照计算相关库
#ifndef  CUSTOM_LIGHTING_INCLUDED
#define  CUSTOM_LIGHTING_INCLUDED
#include "Surface.hlsl"
#include "Light.hlsl"
#include "BRDF.hlsl"
#define MAX_DIRECTIONAL_LIGHT_COUNT 4

//多个平行光的属性
CBUFFER_START(_CustomLight)
int _DirectionalLightCount;
float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

//计算入射光
float3 IncomingLight(Surface surface, Light light)
{
    return saturate(dot(surface.normal, light.direction)) * light.color;
}

//获取平行光数量
int GetDirectionalLightCount()
{
    return _DirectionalLightCount;
}


//获取指定索引的方向光的数据
Light GetDirectionalLight(int index)
{
    Light light;
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;
    return light;
}

//入射光照乘以表面颜色,得到最终的照明颜色
float3 GetLighting(Surface surface, BRDF brdf, Light light)
{
    return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

//获取最终照明结果
float3 GetLigting(Surface surface, BRDF brdf)
{
    //可见方向光的照明结果进行累加得到最终照明结果
    float3 color = 0.0;
    for (int i = 0; i < GetDirectionalLightCount(); i++)
    {
        color += GetLighting(surface, brdf, GetDirectionalLight(i));
    }
    return color;
}

#endif
