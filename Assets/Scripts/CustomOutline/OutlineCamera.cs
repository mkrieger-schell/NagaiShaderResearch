// Copyright (c) 2024 Schell Games. MIT license (see nagai_license.txt in root directory).

using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

public class OutlineCamera : MonoBehaviour
{
    [SerializeField]
    private Camera mainCam;
    
    // for these two materials, use the following shaders:
    // mat should use NagaiOutlines.shader
    // unlitMat should use NagaiOutlineBlend.shader
    
    [SerializeField] private Material mat;
    [SerializeField] private Material unlitMat;

    private int texID;
    void Start()
    {
        mainCam.depthTextureMode = DepthTextureMode.DepthNormals | DepthTextureMode.Depth;

        texID = Shader.PropertyToID("_ScreenCopyTexture");

        CommandBuffer rtBuff = new CommandBuffer();
        rtBuff.name = "Blit to Temp RenderTexture";
        rtBuff.GetTemporaryRT(texID, Screen.width, Screen.height, 32, FilterMode.Bilinear, RenderTextureFormat.Default, RenderTextureReadWrite.Default, 1);
        
        rtBuff.Blit(BuiltinRenderTextureType.DepthNormals, texID, mat, 0);
        rtBuff.Blit(texID, BuiltinRenderTextureType.CameraTarget, unlitMat);

        rtBuff.ReleaseTemporaryRT(texID);
        mainCam.AddCommandBuffer(CameraEvent.BeforeForwardAlpha, rtBuff);
    }
}
