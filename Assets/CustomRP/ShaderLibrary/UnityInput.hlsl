//unity标准输入库
#include <HLSLSupport.cginc>
#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//定义在 UnityPerDraw 的常量缓冲区中
CBUFFER_START(UnityPerDraw)

float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
//这个矩阵包含一些在这里我们不需要的转换信息
float4 unity_WorldTransformParams;
CBUFFER_END

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;
float4x4 unity_ObjectToWorld_prev;
float4x4 unity_WorldToObject_prev;

//相机位置
float3 _WorldSpaceCameraPos;
#endif
