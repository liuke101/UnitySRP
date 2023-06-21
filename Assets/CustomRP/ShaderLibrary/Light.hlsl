//灯光数据相关库
#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

//灯光属性
struct Light
{
    float3 color;
    float3 direction;
};

//获取平行光属性
Light GetMainLight()
{
    Light light;
    light.color = float3(1.0, 1.0, 1.0);
    light.direction = float3(0.0, 1.0, 0.0);
    return light;
}

#endif