using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class ShadowSettings 
{
   //阴影最大距离
   [Min(0.0f)]
   public float maxDistance = 100.0f;
   
   //ShadowMap大小
   public enum TextureSize
   {
      _256 = 256,
      _512 = 512,
      _1024 = 1024,
      _2048 = 2048,
      _4096 = 4096,
      _8192 = 8192
   }
   
   //方向光的阴影配置
   [System.Serializable]
   public struct Directional
   {
      //纹理尺寸
      public TextureSize atlasSize; 
      
      //级联数量
      [Range(1,4)]
      public int cascadeCount;
      //级联比例
      //最后一级会覆盖整个区域，所以不用自己调节
      [Range(0.0f,1.0f)]
      public float cascadeRatio1,cascadeRatio2,cascadeRatio3;
      
      //在ComputeDirectionalShadowMatricesAndCullingPrimitives方法中使用
      public Vector3 CascadeRatios => new Vector3(cascadeRatio1,cascadeRatio2,cascadeRatio3);
   }
   
   //默认尺寸为1024
   public Directional directional = new Directional
   {
      atlasSize = TextureSize._1024,
      cascadeCount = 4,
      cascadeRatio1 = 0.1f,
      cascadeRatio2 = 0.25f,
      cascadeRatio3 = 0.5f
      
   };
   
   
   
}
