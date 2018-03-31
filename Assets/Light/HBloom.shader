Shader "Custom/HBloom" {
	Properties 
    {
        _MainTex("MainTex", 2D) = "" {}
        _BaseTex("BaseTex", 2D) = "" {}
	}

	SubShader 
    {
        // Prefilter
        Pass
        {
            ZTest Always ZWrite Off Cull Off
            CGPROGRAM 
            #pragma target 3.0
            #include "HBloom.cginc"
            #pragma multi_compiler __ ANTI_FLICKER  // Only turn on anti flicker when there has flicker
            #pragma fragment frag_prefilter
            #pragma vertex vert 
            ENDCG
        }

        // DownSample
        Pass
        {
            ZTest Always ZWrite Off Cull Off
            CGPROGRAM 
            #pragma target 3.0
            #include "HBloom.cginc"
            #pragma multi_compiler __ ANTI_FLICKER  // Only turn on anti flicker when there has flicker
            #pragma vertex vert
            #pragma fragment frag_downsample
            ENDCG
        }
        
        // UpSample and Bind
        Pass
        {
            ZTest Always ZWrite Off Cull Off
            CGPROGRAM
            #pragma target 3.0
            #include "HBloom.cginc"
            #pragma vertex vert_muti
            #pragma fragment frag_upsample
            ENDCG
        }
    }
}
