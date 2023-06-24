using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Random = UnityEngine.Random;

public class MeshBall : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor");
    static int metallicId = Shader.PropertyToID("_Metallic");
    static int smoothnessId = Shader.PropertyToID("_Smoothness");
    
    [SerializeField] private Mesh mesh = default;
    [SerializeField] private Material material = default;
    
    Matrix4x4[] matrices = new Matrix4x4[1023];
    Vector4[] baseColors = new Vector4[1023];
    
    float[] metallic = new float[1023];
    float[] smoothness = new float[1023];
    
    MaterialPropertyBlock block;

    private void Awake()
    {
        for (int i = 0; i < matrices.Length; i++)
        {
            matrices[i] = Matrix4x4.TRS(
                Random.insideUnitSphere * 10f,
                Quaternion.Euler(Random.value * 360f, Random.value * 360f, Random.value * 360f),
                Vector3.one * UnityEngine.Random.Range(0.5f, 1.5f)
                );
            baseColors[i] = new Vector4(Random.value, Random.value, Random.value, Random.Range(0.5f,1.0f));
            metallic[i] = Random.value < 0.90f ? 1.0f : 0.0f;
            smoothness[i] = Random.Range(0.05f, 0.95f);
        }
    }

    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
            block.SetVectorArray(baseColorId, baseColors);
            block.SetFloatArray(metallicId, metallic);
            block.SetFloatArray(smoothnessId, smoothness);
        }

        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block);
    }
}
