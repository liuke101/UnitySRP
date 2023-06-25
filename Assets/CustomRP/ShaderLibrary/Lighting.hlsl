//光照计算相关库
#ifndef  CUSTOM_LIGHTING_INCLUDED
#define  CUSTOM_LIGHTING_INCLUDED

//计算入射光
float3 IncomingLight(Surface surface, Light light)
{
    return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color;
}

//入射光照乘以表面颜色,得到最终的照明颜色
float3 GetLighting(Surface surface, BRDF brdf, Light light)
{
    return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

//获取最终照明结果
float3 GetLigting(Surface surfaceWS, BRDF brdf)
{
    //得到表面阴影数据
    ShadowData shadowData = GetShadowData(surfaceWS);
    
    //可见方向光的照明结果进行累加得到最终照明结果
    float3 color = 0.0;
    for (int i = 0; i < GetDirectionalLightCount(); i++)
    {
        Light light = GetDirectionalLight(i, surfaceWS, shadowData);
        color += GetLighting(surfaceWS, brdf, light);
    }
    return color;
}

#endif
