using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent (typeof (Camera))]
public class HBloom : MonoBehaviour
{
    /// <summary>
    /// Blur added iteration times for blur render texture. The base iteration times is depend on resolution
    /// </summary>
    /// <remarks>
    /// Higher iteration times will make draw cost higher but a good blur effect.
    /// </remarks>
    public int m_blurAddIteration;

    /// <summary>
    /// Brightness threshold
    /// </summary>
    [Range (0, 1)]
    public float m_threshold;

    /// <summary>
    /// Soft threshold. Must lower than m_threshold
    /// </summary>
    [Range (0, 1)]
    public float m_softThreshold;

    /// <summary>
    /// Control the up sampler field, must be positive.
    /// The value is 1 means idle sample. Greater means sample larger area.
    /// </summary>
    [Range (0, 3)]
    public float m_sampleScale;

    /// <summary>
    /// Shader that used to bloom the screen
    /// </summary>
    public Shader m_bloomShader;

    /// <summary>
    /// Use for bloom anti flicker. 
    /// If the bloom doesn't flicker, this valur should set false
    /// </summary>
    public bool m_antiFlicker;

    private Material _material;

    private const int MaxIterations = 16;

    private RenderTexture[] _blurBuffer1 = new RenderTexture[MaxIterations];
    private RenderTexture[] _blurBuffer2 = new RenderTexture[MaxIterations];

    private void OnEnable ()
    {
        var shader = m_bloomShader ?? Shader.Find ("Custom/HBloom");
        _material = new Material (shader);
        _material.hideFlags = HideFlags.HideAndDontSave;
    }

    private void OnDisable ()
    {
        DestroyImmediate (_material);
    }

    /// <summary>
    /// OnRenderImage is called after all rendering is complete to render image.
    /// </summary>
    private void OnRenderImage (RenderTexture src, RenderTexture dest)
    {
        Vector4 curve = new Vector4 (GetBThreshold (), GetSoftThreshold (), 0, 0);

        _material.SetVector ("_Curve", curve);
        _material.SetFloat ("_SamplerScale", m_sampleScale);

        if(m_antiFlicker)
        {
            _material.EnableKeyword("ANTI_FLICKER");
        }
        else
        {
            _material.DisableKeyword("ANTI_FLICKER");
        }

        // Current render texture width and height
        int width = src.width;
        int height = src.height;

        // blur iteration times
        int iter = Mathf.Clamp (
            (int) Mathf.Log (width, 2) + m_blurAddIteration - 8, 0, MaxIterations);

        // Prefilter
        var prefilterRend = RenderTexture.GetTemporary (width, height, 0, RenderTextureFormat.Default);
        Graphics.Blit (src, prefilterRend, _material, 0);

        // Generate mip maps
        var last = prefilterRend;
        for (int level = 0; level < iter; level++)
        {
            _blurBuffer1[level] = RenderTexture.GetTemporary (
                last.width / 2, last.height / 2, 0, RenderTextureFormat.Default
            );

            Graphics.Blit (last, _blurBuffer1[level], _material, 1);

            last = _blurBuffer1[level];
        }

        // Upsample and bind
        for (int level = iter - 2; level >= 0; level--)
        {
            var baseTex = _blurBuffer1[level];
            _material.SetTexture ("_BaseTex", baseTex);

            _blurBuffer2[level] = RenderTexture.GetTemporary (
                baseTex.width, baseTex.height, 0, RenderTextureFormat.Default
            );

            Graphics.Blit (last, _blurBuffer2[level], _material, 2);

            last = _blurBuffer2[level];
        }

        // Last upsample
        _material.SetTexture ("_BaseTex", src);
        Graphics.Blit (last, dest, _material, 2);

        // Release buffer
        for (var i = 0; i < MaxIterations; i++)
        {
            if (_blurBuffer1[i] != null)
                RenderTexture.ReleaseTemporary (_blurBuffer1[i]);

            if (_blurBuffer2[i] != null)
                RenderTexture.ReleaseTemporary (_blurBuffer2[i]);

            _blurBuffer1[i] = null;
            _blurBuffer2[i] = null;
        }
        RenderTexture.ReleaseTemporary (prefilterRend);
    }

    /// <summary>
    /// Get valid bright threshold value
    /// </summary>
    private float GetBThreshold ()
    {
        return Mathf.Clamp (m_threshold, 1e-5f, 1);
    }

    /// <summary>
    /// Get valid soft threshold
    /// </summary>
    private float GetSoftThreshold ()
    {
        return Mathf.Clamp (m_softThreshold, 0, 1);
    }
}