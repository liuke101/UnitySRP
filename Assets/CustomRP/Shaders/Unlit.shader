Shader "CustomRP/Unlit"
{
    Properties
    {
        _BaseColor("Color", Color) = (1.0,1.0,1.0,1.0)
        _BaseMap("Texture", 2D) = "white" {}
        
        //透明度测试的阈值
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
        
        //是否开启透明度测试
        [Toggle(_CLIPPING)]_Clipping("Alpha Clipping", Float) = 0
        
        //设置混合运算符
        [Enum(UnityEngine.Rendering.BlendOp)]
        _BlendOp("混合操作",float) = 0
        
        //设置混合模式
        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend("源颜色的混合因子",float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend("目标颜色的混合因子",float) = 10
        
        //是否开启深度写入
        [Enum(Off,0,On,1)] _ZWrite("ZWrite",float) = 0
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
                "LightMode"="SRPDefaultUnlit" //SRPDefaultUnlit 是SRP/URP默认的LightMode标签ID
            }
            BlendOp [_BlendOp] //可自定义混合运算符  
            Blend [_SrcBlend] [_DstBlend] //可自定义混合模式
            ZWrite [_ZWrite] //可自定义是否写入深度缓冲区
            
            HLSLPROGRAM

            #pragma multi_compile_instancing
            #pragma shader_feature _CLIPPING
            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment
            
            #include "UnlitPass.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "CustomShaderGUI"
}