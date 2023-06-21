//BRDF相关库
//这里使用和 URP 一样的 BRDF 模型
#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED
#include "Surface.hlsl"
#include "Common.hlsl"

//电介质的反射率平均约0.04
#define MIN_REFLECTIVITY 0.04

float OneMinusReflectivity(float metallic)
{
    //不反射的范围从 0-1 调整到 0-0.96，保持和 URP 中一样
    float range = 1.0 - MIN_REFLECTIVITY;
    return range - metallic * range;
}

//BRDF属性
struct BRDF
{
    float3 diffuse;  //漫反射颜色
    float3 specular; //镜面反射颜色
    float roughness; //粗糙度
};

//获取给定表面的BRDF数据
BRDF GetBRDF(Surface surface)
{
    BRDF brdf;
    float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
    brdf.diffuse = surface.color * oneMinusReflectivity; //金属度越高，漫反射越弱

    //金属影响镜面反射的颜色，而非金属不影响。非金属的镜面反射应该是白色的
    //通过金属度在最小反射率和表面颜色之间进行插值得到 BRDF 的镜面反射颜色。
    brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic); 

    //光滑度转为实际粗糙度
    float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.smoothness); //源码：(1.0 - surface.smoothness)
    
    brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness); //源码将perceptualRoughness求平方，得到实际的粗糙度，这与迪士尼光照模型匹配。
    
    return brdf;
}

//计算镜面反射强度
//使用 URP 中相同的公式，这是简化版 Cook-Torrance 模型的一种变体
float SpecularStrength(Surface surface,BRDF brdf,Light light)
{
    float3 h = SafeNormalize(light.direction + surface.viewDirection);
    float nh2 = Square(saturate(dot(surface.normal,h)));
    float lh2 = Square(saturate(dot(light.direction,h)));
    float r2 = Square(brdf.roughness);
    float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
    float normalization = brdf.roughness * 4.0 + 2.0;
    return r2/(d2*max(0.1,lh2)*normalization);
}

//直接光照的表面颜色
float DirectBRDF(Surface surface, BRDF brdf, Light light)
{
    return SpecularStrength(surface,brdf,light) * brdf.specular + brdf.diffuse;
}

#endif
