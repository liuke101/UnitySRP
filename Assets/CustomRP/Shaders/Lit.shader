Shader "CustomRP/lit"
{
    Properties
    {
        _BaseColor("基本颜色", Color) =(0.5, 0.5, 0.5, 1.0)
        _BaseMap("基本纹理", 2D) = "white" {}
        _Metallic("金属度", Range(0,1)) = 0.0
        _Smoothness("光滑度", Range(0,1)) = 0.5
        
        //透明度测试的阈值
        _Cutoff("透明度测试阈值", Range(0,1)) = 0.5
        
        //是否开启透明度测试
        [Toggle(_CLIPPING)] _Clipping("透明度测试", Float) = 0
        
        //是否开启透明度预乘
        [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha("透明度预乘", Float) = 0
        
        //设置混合运算符
        [Enum(UnityEngine.Rendering.BlendOp)]
        _BlendOp("混合操作",float) = 0
        
        //设置混合模式
        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend("源颜色的混合因子",float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend("目标颜色的混合因子",float) = 10
        
        //是否开启深度写入
        [Enum(Off,0,On,1)] _ZWrite("深度写入",float) = 0
        
        //投影模式
        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("投影模式", Float) = 0
        
        //是否接受阴影
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("接受阴影", Float) = 1
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
            Blend [_SrcBlend] [_DstBlend] //可自定义混合模式
            ZWrite [_ZWrite] //可自定义是否写入深度缓冲区
            
            HLSLPROGRAM

            //着色器编译目标级别设置为 3.5
            #pragma target 3.5

            //PCF滤波模式
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7

            //级联混合模式
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            
            //是否开启GPU实例化
            #pragma multi_compile_instancing
            
            //Shader Feature
            #pragma shader_feature _CLIPPING
            #pragma shader_feature _PREMULTIPLY_ALPHA
            //是否接受阴影
            #pragma shader_feature _RECEIVE_SHADOWS
            
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            
            #include "LitPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Tags
            {
                "LightMode" = "ShadowCaster" //该LightMode将物体的深度渲染到阴影贴图或者深度贴图中
            }
            
            ColorMask 0 //关闭颜色写入
            
            HLSLPROGRAM

            //着色器编译目标级别设置为 3.5
            #pragma target 3.5

            //是否开启GPU实例化
            #pragma multi_compile_instancing

            //Shader Feature
            //投影模式
            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER

            
            
            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment
            
            #include "ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
    
    CustomEditor "CustomShaderGUI"
}