// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

// this script only exists to set the global texture for noise to be triplanar mapped to Nagai surfaces.
// 

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NagaiGlobals : MonoBehaviour
{
    [SerializeField]
    private Texture globalNoise;
    
    void Start()
    {
        Shader.SetGlobalTexture("_NagaiGlobalNoise", globalNoise);
    }

    void Update()
    {
        Matrix4x4 MV = Camera.main.cameraToWorldMatrix;
        Shader.SetGlobalMatrix("_CameraMV", MV);
    }
}
