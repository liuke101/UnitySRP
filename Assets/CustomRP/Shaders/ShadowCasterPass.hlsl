#ifndef CUSTOM_SHADOW_CASTER_PASS_INCLUDED
#define CUSTOM_SHADOW_CASTER_PASS_INCLUDED


// /*******************************************************************************/
// TEXTURE2D(_BaseMap);
// SAMPLER(sampler_BaseMap);
//
// /*******************************************************************************/
// UNITY_INSTANCING_BUFFER_START(UnityPerMaterial) //定义在名字为 UnityPerMaterial 的常量缓冲区中
//
// UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
// UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
// UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
//
// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
// /*******************************************************************************/


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
Varyings ShadowCasterPassVertex(Attributes input)
{
    Varyings output;
    
    UNITY_SETUP_INSTANCE_ID(input); //提取顶点输入结构体中的渲染对象的索引，并将其存储到其他实例宏所依赖的全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output); //将对象位置和索引输出，若索引存在则进行复制
    
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);

    //解决阴影平坠的漏光问题
    #if UNITY_REVERSED_Z
    output.positionCS.z =
min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
    output.positionCS.z =
max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
    
    //计算缩放和偏移后的UV
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

//片元函数
void ShadowCasterPassFragment(Varyings input)
{
    //片元中也定义 UNITY_SETUP_INSTANCE_ID(input) 提供对象索引
    UNITY_SETUP_INSTANCE_ID(input);
    
    float4 base = GetBase(input.baseUV);
    
    //透明度测试
    #if defined(_SHADOWS_CLIP)
    //透明度低于阈值的片元进行舍弃
    clip(base.a - GetCutoff(input.baseUV));
    #elif defined(_SHADOWS_DITHER)
    float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
    clip(base.a - dither);
    #endif
}

#endif
