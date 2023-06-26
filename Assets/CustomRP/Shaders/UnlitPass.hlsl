#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED


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

    output.baseUV = TransformBaseUV(input.baseUV);

    return output;
}

//片元函数
float4 UnlitPassFragment(Varyings input) : SV_TARGET
{
    //片元中也定义 UNITY_SETUP_INSTANCE_ID(input) 提供对象索引
    UNITY_SETUP_INSTANCE_ID(input);
    float4 base = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap, input.baseUV);
    
    //通过UNITY_ACCESS_INSTANCED_PROP访问material属性
    #if defined(_CLIPPING)
    clip(base.a - GetCutoff(input.baseUV)); 
    #endif
    
    
    //使用宏访问获取缓冲区中材质的颜色属性
    return GetBase(input.baseUV);
}

#endif
