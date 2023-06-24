
#ifndef  CUSTOM_SURFACE_INCLUDED
#define  CUSTOM_SURFACE_INCLUDED
//表面属性 
struct Surface
{
    float3 position; //表面位置
    float3 normal;   //表面法线
    float3 color;    //表面颜色
    float alpha;     //透明度
    float metallic;  //金属度
    float smoothness;//光滑度

    float3 viewDirection; //观察方向
};

#endif