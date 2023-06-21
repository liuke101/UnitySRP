Shader "CustomRP/lit"
{
    Properties
    {
        _BaseColor("Color", Color) =(0.5, 0.5, 0.5, 1.0)
        _BaseMap("Texture", 2D) = "white" {}
        _Metallic("Metallic", Range(0,1)) = 0.0
        _Smoothness("Smoothness", Range(0,1)) = 0.5
        
        //透明度测试的阈值
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
        
        //是否开启透明度测试
        [Toggle(_CLIPPING)]_Clipping("Alpha Clipping", Float) = 0
        
        //设置混合运算符
        [Enum(UnityEngine.Rendering.BlendOp)]
        _BlendOp("混合操作",int) = 0
        
        //设置混合模式
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendSrc("源颜色的混合因子",int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendOst("目标颜色的混合因子",int) = 10
        
        //是否开启深度写入
        [Enum(Off,0,On,1)] _Zwrite("ZWrite",int) = 0
    }
    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
        }
        
        Pass
        {
            Tags
            {
                "LightMode" = "CustomLit" //自定义光照模式
            }
            
            BlendOp [_BlendOp] //可自定义混合运算符  
            Blend [_BlendSrc] [_BlendOst] //可自定义混合模式
            ZWrite [_Zwrite] //可自定义是否写入深度缓冲区
            
            HLSLPROGRAM

            //着色器编译目标级别设置为 3.5
            #pragma target 3.5

            //是否开启GPU实例化
            #pragma multi_compile_instancing

            //Shader Feature
            #pragma shader_feature _CLIPPING
            
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            
            #include "LitPass.hlsl"
            ENDHLSL
        }
    }
}