#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED
#include "../ShaderLibrary/Common.hlsl"

/*
//材质的所有属性都需要在常量缓冲区 CBUFFER 里定义
//CBUFFER_START 和 CBUFFER_END 宏来替代 CBUFFER 块，这样的话不支持常量缓冲区的平台就会忽略掉 CBUFFER 的代码。
CBUFFER_START(UnityPerMaterial) //定义在名字为 UnityPerMaterial 的常量缓冲区中
    float4 _BaseColor;
CBUFFER_END
*/

//纹理和采样器是着色器资源，必须在全局定义，不能放入缓冲区中
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

//替换上面的CBUFFER_方式，来实现GPU Instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST) //获取纹理的平铺和偏移值
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)



//顶点输入结构体
//用作顶点函数的输入参数
struct Attributes
{
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//片元输入结构体
//用作片元函数的输入参数
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 baseUV : VAR_BASE_UV;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//顶点函数
Varyings UnlitPassVertex(Attributes input)
{
    Varyings output;
    
    UNITY_SETUP_INSTANCE_ID(input); //提取顶点输入结构体中的渲染对象的索引，并将其存储到其他实例宏所依赖的全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output); //将对象位置和索引输出，若索引存在则进行复制
    
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);

    //通过UNITY_ACCESS_INSTANCED_PROP访问material属性
    //计算缩放和偏移后的UV
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    
    return output;
}

//片元函数
float4 UnlitPassFragment(Varyings input) : SV_TARGET
{
    //片元中也定义 UNITY_SETUP_INSTANCE_ID(input) 提供对象索引
    UNITY_SETUP_INSTANCE_ID(input);
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap, input.baseUV);
    
    //通过UNITY_ACCESS_INSTANCED_PROP访问material属性
    #if defined(_CLIPPING)
    clip(baseMap.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff)); 
    #endif
    
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    
    //使用宏访问获取缓冲区中材质的颜色属性
    return baseColor * baseMap;
}

#endif
