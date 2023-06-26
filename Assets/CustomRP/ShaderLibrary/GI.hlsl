﻿//全局光照相关库  
#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

//光照贴图和相关采样器
TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

//光照探针代理体LPPV——3D纹理和相关采样器
TEXTURE3D_FLOAT (unity_ProbeVolumeSH);  
SAMPLER (samplerunity_ProbeVolumeSH);

//阴影遮罩纹理和相关采样器
TEXTURE2D(unity_ShadowMask);  
SAMPLER(samplerunity_ShadowMask);

//当需要渲染光照贴图对象时  
#if defined(LIGHTMAP_ON)
#define GI_ATTRIBUTE_DATA float2 lightMapUV : TEXCOORD1;  
#define GI_VARYINGS_DATA float2 lightMapUV : VAR_LIGHT_MAP_UV;  
#define TRANSFER_GI_DATA(input, output) output.lightMapUV = input.lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
#define GI_FRAGMENT_DATA(input) input.lightMapUV  
#else
//否则这些宏都应为空  
#define GI_ATTRIBUTE_DATA  
#define GI_VARYINGS_DATA  
#define TRANSFER_GI_DATA(input, output)  
#define GI_FRAGMENT_DATA(input) 0.0
#endif

//GI属性
struct GI
{
    //漫反射颜色  
    float3 diffuse;
    ShadowMask shadowMask;
};

//采样光照贴图
float3 SampleLightMap(float2 lightMapUV)
{
    #if defined(LIGHTMAP_ON)
    return SampleSingleLightmap(
        TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), //TEXTURE2D_ARGS 宏，它需要将光照贴图和采样器作为参数；
        lightMapUV,
        float4(1.0, 1.0, 0.0, 0.0),  //UV 的缩放和偏移，之前已经用它们处理过 UV 坐标了，所以传入默认值即可；
    #if defined(UNITY_LIGHTMAP_FULL_HDR)
   false,  //是否压缩了光照贴图，这是通过 UNITY_LIGHTMAP_FULL_HDR 是否被定义来判断的；
    #else
   true,  
    #endif
   float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)); //包含了解码指令的 float4类型的变量

    #else
    return 0.0;
    #endif
}

//光照探针采样  
float3 SampleLightProbe(Surface surfaceWS)
{
    #if defined (LIGHTMAP_ON)
    return 0.0;  //若该对象正在使用光照贴图就直接返回 0
    #else
    //判断是否使用 LPPV 或插值光照探针  
    if (unity_ProbeVolumeParams. x)   
    {  
        return SampleProbeVolumeSH4 (TEXTURE3D_ARGS (unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH), surfaceWS. position, surfaceWS. normal,  
        unity_ProbeVolumeWorldToObject, unity_ProbeVolumeParams. y, unity_ProbeVolumeParams. z, unity_ProbeVolumeMin. xyz, unity_ProbeVolumeSizeInv. xyz);  
    }
    else
    {
        float4 coefficients[7];
        coefficients[0] = unity_SHAr;
        coefficients[1] = unity_SHAg;
        coefficients[2] = unity_SHAb;
        coefficients[3] = unity_SHBr;
        coefficients[4] = unity_SHBg;
        coefficients[5] = unity_SHBb;
        coefficients[6] = unity_SHC;
        return max(0.0, SampleSH9(coefficients, surfaceWS.normal));
    }
    #endif
}

//采样shadowMask得到烘焙阴影数据  
float4 SampleBakedShadows(float2 lightMapUV, Surface surfaceWS)   
{
    //有使用光照贴图的情况下采样shadowmask
    #if defined(LIGHTMAP_ON)  
    return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightMapUV);
    //没有使用光照贴图的情况下返回遮挡探针数据
    #else
    if (unity_ProbeVolumeParams.x)   
    {  
        //采样LPPV遮挡数据  
        return SampleProbeOcclusion(TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),surfaceWS.position,   
        unity_ProbeVolumeWorldToObject,unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz);  
    }  
    else   
    {   
        return unity_ProbesOcclusion;  
    }
    
    #endif 

}
//获取GI属性
GI GetGI(float2 lightMapUV, Surface surfaceWS)
{
    GI gi;
    gi.diffuse = SampleLightMap (lightMapUV) + SampleLightProbe (surfaceWS);
    gi.shadowMask.distance = false;  
    gi.shadowMask.shadows = 1.0;
    #if defined(_SHADOW_MASK_ALWAYS)  
    gi.shadowMask.always = true;  
    gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);  
    #elif defined(_SHADOW_MASK_DISTANCE)  
    gi.shadowMask.distance = true;  
    gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS); 
    #endif  
    return gi;
}



#endif
