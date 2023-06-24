#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED
#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

/*******************************************************************************/
//纹理和采样器是着色器资源，必须在全局定义，不能放入缓冲区中
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

/*******************************************************************************/
//【常量缓冲区】（对应shaderlab中的Properties）
/*
//材质的所有属性都需要在常量缓冲区里定义
//CBUFFER_START 和 CBUFFER_END 宏来替代 CBUFFER 块，这样的话不支持常量缓冲区的平台就会忽略掉 CBUFFER 的代码。
CBUFFER_START(UnityPerMaterial) //定义在名字为 UnityPerMaterial 的常量缓冲区中
    float4 _BaseColor;
CBUFFER_END
*/

//材质的所有属性都需要在常量缓冲区里定义!!!
//替换上面的CBUFFER_方式，来实现GPU Instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial) //定义在名字为 UnityPerMaterial 的常量缓冲区中

UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)

UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//【访问方式】
// UNITY_ACCESS_INSTANCED_PROP(常量缓冲区名字, 属性名);
/*******************************************************************************/


//顶点输入结构体
//用作顶点函数的输入参数
struct Attributes
{
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    float3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//片元输入结构体
//用作片元函数的输入参数
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float2 baseUV : VAR_BASE_UV;
    float3 normalWS : VAR_NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//顶点函数
Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    
    UNITY_SETUP_INSTANCE_ID(input); //提取顶点输入结构体中的渲染对象的索引，并将其存储到其他实例宏所依赖的全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output); //将对象位置和索引输出，若索引存在则进行复制
    
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorld(input.normalOS);

    // 通过UNITY_ACCESS_INSTANCED_PROP访问material属性
    //计算缩放和偏移后的UV
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    
    return output;
}

//片元函数
float4 LitPassFragment(Varyings input) : SV_TARGET
{
    //片元中也定义 UNITY_SETUP_INSTANCE_ID(input) 提供对象索引
    UNITY_SETUP_INSTANCE_ID(input);
    
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap, input.baseUV);

    // 通过UNITY_ACCESS_INSTANCED_PROP访问material属性
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);

    float4 base = baseMap * baseColor;
    
    //透明度测试
    #if defined(_CLIPPING)
    clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff)); 
    #endif
    
    //定义一个Surface并填充属性
    Surface surface;
    surface.position = input.positionWS;
    surface.normal = normalize(input.normalWS);
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
    surface.smoothness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    
    //透明度预乘
    #if defined(_PREMULTIPLY_ALPHA)
    //获取BRDF数据
        BRDF brdf = GetBRDF(surface,true);
    #else
        BRDF brdf = GetBRDF(surface);
    #endif
    //计算最终颜色
        float3 finalcolor = GetLigting(surface, brdf);
    
    return float4(finalcolor,surface.alpha);
}

#endif
