
#ifndef  CUSTOM_SURFACE_INCLUDED
#define  CUSTOM_SURFACE_INCLUDED
//表面属性 
struct Surface
{
    float3 normal;
    float3 color;
    float alpha;
    float metallic;
    float smoothness;

    float3 viewDirection;
};

#endif