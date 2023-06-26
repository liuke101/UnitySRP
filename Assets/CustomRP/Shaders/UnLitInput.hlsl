﻿#ifndef CUSTOM_LIT_INPUT_INCLUDED  
#define CUSTOM_LIT_INPUT_INCLUDED

/*******************************************************************************/

//纹理和采样器是着色器资源，必须在全局定义，不能放入缓冲区中
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

//替换上面的CBUFFER_方式，来实现GPU Instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST) //获取纹理的平铺和偏移值
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

/*******************************************************************************/


float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP (UnityPerMaterial, _BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float4 GetBase (float2 baseUV)   
{  
    float4 map = SAMPLE_TEXTURE2D (_BaseMap, sampler_BaseMap, baseUV);  
    float4 color = UNITY_ACCESS_INSTANCED_PROP (UnityPerMaterial, _BaseColor);  
    return map * color;  
}  
   
float GetCutoff (float2 baseUV)   
{  
    return UNITY_ACCESS_INSTANCED_PROP (UnityPerMaterial, _Cutoff);  
}  

float3 GetEmission(float2 baseUV)
{
    return GetBase(baseUV).rgb;
}

#endif