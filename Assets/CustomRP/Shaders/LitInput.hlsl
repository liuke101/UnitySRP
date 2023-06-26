#ifndef CUSTOM_LIT_INPUT_INCLUDED  
#define CUSTOM_LIT_INPUT_INCLUDED


//纹理和采样器是着色器资源，必须在全局定义，不能放入缓冲区中
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
TEXTURE2D(_EmissionMap);

/*******************************************************************************/
//【常量缓冲区】（对应shaderlab中的Properties）
//材质的所有属性都需要在常量缓冲区里定义

//替换CBUFFER_方式，来实现GPU Instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial) //定义在名字为 UnityPerMaterial 的常量缓冲区中

UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)

UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//【访问方式】
// UNITY_ACCESS_INSTANCED_PROP(常量缓冲区名字, 属性名);

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
   
float GetMetallic (float2 baseUV)   
{  
    return UNITY_ACCESS_INSTANCED_PROP (UnityPerMaterial, _Metallic);  
}  
   
float GetSmoothness (float2 baseUV)   
{  
    return UNITY_ACCESS_INSTANCED_PROP (UnityPerMaterial, _Smoothness);  
}

float3 GetEmission(float2 baseUV)
{
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, baseUV);  
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _EmissionColor);  
    return map.rgb * color.rgb; 
}

#endif