//unity标准输入库
#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//定义在 UnityPerDraw 的常量缓冲区中
CBUFFER_START(UnityPerDraw)

float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
//这个矩阵包含一些在这里我们不需要的转换信息
float4 unity_WorldTransformParams;

//光照贴图
float4 unity_LightmapST;
//动态光照贴图的 UV 转换属性,为了防止因为一些兼容问题而导致 SRP 的批处理中断。
float4 unity_DynamicLightmapST;

//光照探针
float4 unity_SHAr;  
float4 unity_SHAg;  
float4 unity_SHAb;  
float4 unity_SHBr;  
float4 unity_SHBg;  
float4 unity_SHBb;  
float4 unity_SHC;  

//光照探针代理体（LPPV）
float4 unity_ProbeVolumeParams;  
float4x4 unity_ProbeVolumeWorldToObject;  
float4 unity_ProbeVolumeSizeInv;  
float4 unity_ProbeVolumeMin;

//遮挡探针
float4 unity_ProbesOcclusion;

CBUFFER_END

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;
float4x4 unity_ObjectToWorld_prev;
float4x4 unity_WorldToObject_prev;

//相机位置
float3 _WorldSpaceCameraPos;
#endif
