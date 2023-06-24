//灯光数据相关库
#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4

//多个定向光的属性（相当于shaderlab中的Properties）
CBUFFER_START(_CustomLight)
int _DirectionalLightCount;
float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT]; 
CBUFFER_END

//灯光属性
struct Light
{
    float3 color;      //光源颜色
    float3 direction;  //光源方向
    float attenuation; //光源衰减
};

//获取定向光数量
int GetDirectionalLightCount()
{
    return _DirectionalLightCount;
}

//获取定向光的阴影数据
DirectionalShadowData GetDirectionalShadowData(int lightIndex)
{
    DirectionalShadowData data;
    data.strength = _DirectionalLightShadowData[lightIndex].x;
    data.tileIndex = _DirectionalLightShadowData[lightIndex].y;
    return data;
}

//获取指定索引的定向光的属性
Light GetDirectionalLight(int index, Surface surfaceWS)
{
    Light light;
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;

    //得到阴影数据
    DirectionalShadowData data = GetDirectionalShadowData(index);
    //得到阴影衰减
    light.attenuation = GetDirectionalShadowAttenuation(data, surfaceWS);
    
    return light;
}



#endif