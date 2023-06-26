#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"  
#include "../ShaderLibrary/Lighting.hlsl"

//顶点输入结构体
//用作顶点函数的输入参数
struct Attributes
{
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    float3 normalOS : NORMAL;

    GI_ATTRIBUTE_DATA
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
    
    GI_VARYINGS_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//顶点函数
Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    
    UNITY_SETUP_INSTANCE_ID(input); //提取顶点输入结构体中的渲染对象的索引，并将其存储到其他实例宏所依赖的全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output); //将对象位置和索引输出，若索引存在则进行复制
    TRANSFER_GI_DATA(input, output);
    
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorld(input.normalOS);

    // 通过UNITY_ACCESS_INSTANCED_PROP访问material属性
    //计算缩放和偏移后的UV
    output. baseUV = TransformBaseUV(input.baseUV);
    
    return output;
}

//片元函数
float4 LitPassFragment(Varyings input) : SV_TARGET
{
    //片元中也定义 UNITY_SETUP_INSTANCE_ID(input) 提供对象索引
    UNITY_SETUP_INSTANCE_ID(input);
    

    float4 base = GetBase(input. baseUV);  
    
    //透明度测试
    #if defined(_CLIPPING)
    clip (base. a - GetCutoff(input. baseUV));
    #endif
    
    //定义一个Surface并填充属性
    Surface surface;
    surface.position = input.positionWS;
    surface.normal = normalize(input.normalWS);
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface. metallic = GetMetallic (input. baseUV);  
    surface. smoothness = GetSmoothness (input. baseUV);
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.depth = -TransformWorldToView(input.positionWS).z;
    surface.dither = InterleavedGradientNoise(input.positionCS.xy,0);

    //获取全局光照  
    GI gi = GetGI (GI_FRAGMENT_DATA (input), surface);
    
    //透明度预乘
    #if defined(_PREMULTIPLY_ALPHA)
    //获取BRDF数据
        BRDF brdf = GetBRDF(surface,true);
    #else
        BRDF brdf = GetBRDF(surface);
    #endif
    //计算最终颜色
        float3 finalcolor = GetLigting(surface, brdf, gi);

    finalcolor += GetEmission(input.baseUV);
    
    return float4(finalcolor,surface.alpha);
}

#endif
