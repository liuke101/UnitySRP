using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PerObjectMaterialProperties : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor");
    
    [SerializeField]
    Color baseColor = Color.white;

    private static MaterialPropertyBlock block;


    void Start()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
        }
        
        block.SetColor(baseColorId, baseColor);
        GetComponent<MeshRenderer>().SetPropertyBlock(block);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
