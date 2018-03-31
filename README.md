# Bloom-Effect-Unity

Myself Bloom Effect Implementation

## 0. 写在之前的话

![JI Stage2 with Bloom][1]

![JI Stage2 without Bloom][2]

这两天，我深入的理解，并编写实现了 Bloom 效果。本来打算系统的写一下的，但是尝试了一下，发现太长了，所以打算以链接的方式给出学习路径。后面几节的内容都是学习路径。

我自己的感受：

因为这是第一次接触这种可以说是工业级别的渲染代码（Unity 官方后处理中的Bloom代码），我受到很大的震撼。在花了整整两天时间仔细深入学习了其中各个步骤渲染，为什么这么做，为什么不那么做的原因后，我觉得我收获了非常非常多的东西。

<!-- more -->

## 1. 最好的学习模板

我最初是在 [keijiro/KinoBloom](https://github.com/keijiro/KinoBloom) 这个 Github 项目上看到 Bloom 的实现方式的。之后，在下载了 [Post Processing Stack](https://assetstore.unity.com/packages/essentials/post-processing-stack-83912) 这个 Unity 官方的后处理系统后，我认真的阅读、学习了其中关于实现 Bloom 部分的代码。（其实这两份代码都是 [keijiro](https://github.com/keijiro) 一个人写的）

在看过这两份代码后，我发现 Post Processing Stack 的代码质量更高。在这里推荐给大家包含 Bloom 实现的几个文件。

+ Resources/Shaders/Bloom.shader。包含了实现 Bloom 效果的具体各个的 Pass 的 Shader 代码。
+ Resources/Shaders/Bloom.cginc。包含了各个 Pass 的 vertex 和 fragment 的 Shader 代码。
+ Resources/Shaders/Common.cginc。包含了一些渲染所需的基础工具函数。
+ Runtime/Components/BloomComponent.cs。包含了调用 Shader 进行后处理的代码。


## 2. 初步了解 Bloom

1. Wiki 中关于 Bloom 的定义：[wiki_Bloom_shader_effect](https://en.wikipedia.org/wiki/Bloom_(shader_effect))
2. Wiki 中关于 HDR 的定义：[wiki_High_dynamic_range](https://en.wikipedia.org/wiki/High_dynamic_range)
3. 朴素的关于实现 Bloom 的原理：[how-to-do-good-bloom-for-hdr-rendering](http://harkal.sylphis3d.com/2006/05/20/how-to-do-good-bloom-for-hdr-rendering/)

## 3. 亮度筛选(Light Prefilter)

这部分主要是关于 Bloom Shader（在上文中提到的Resources/Shaders/Bloom.shader）中第一个 Pass 的实现方法。

代码部分：
```hlsl
half4 frag_prefilter(v2f_img i) : SV_Target
{
    float2 uv = i.uv;

#if ANTI_FLICKER
    float3 d = _MainTex_TexelSize.xyx * float3(1, 1, 0);
    half4 s0 = SafeHDR(tex2D(_MainTex, uv));
    half3 s1 = SafeHDR(tex2D(_MainTex, uv - d.xz)).rgb;
    half3 s2 = SafeHDR(tex2D(_MainTex, uv + d.xz)).rgb;
    half3 s3 = SafeHDR(tex2D(_MainTex, uv - d.yz)).rgb;
    half3 s4 = SafeHDR(tex2D(_MainTex, uv + d.yz)).rgb;
    half3 c = Median3(Median3(s0.rgb, s1, s2), s3, s4); // Roughly get the midient of s1, s2, s3, s4
#else
    half4 s0 = SafeHDR(tex2D(_MainTex, uv));
    half3 c = s0.rgb;
#endif

#if UNITY_COLORSPACE_GAMMA
    c = GammaToLinearSpace(c);
#endif

    half bright = Brightness(c);

    half knee = _Curve.x * _Curve.y;
    half soft = bright - (_Curve.x - knee);
    soft = clamp(soft, 0, 2 * knee);
    soft = soft * soft * 1 / (4 * knee + 0.00001);

    c *= max(soft, bright - _Curve.x) / max(bright, 1e-5);

    return half4(c, 0);
}
```


这个 Pass 是用来对图片的亮度进行筛选：选出高亮度的像素，去掉低亮度的像素。

**Gamma 空间和 Linear 空间：**

+ 什么是 Gamma 矫正（Gamma Correction）: [wiki_Gamma_correction](https://en.wikipedia.org/wiki/Gamma_correction)
+ Unity 在 Gamma 或 Linear 空间中的开发流程：[LinearRendering-LinearOrGammaWorkflow](https://docs.unity3d.com/Manual/LinearRendering-LinearOrGammaWorkflow.html)
+ 在 Shader 中判断游戏当前是在 Gamma 空间中还是在 Linear 空间中：[UNIYT_COLORSPACE_GAMMA](https://docs.unity3d.com/ScriptReference/Rendering.BuiltinShaderDefine.UNITY_COLORSPACE_GAMMA.html)
+ 什么是 sRGB 空间：[wiki_sRGB](https://en.wikipedia.org/wiki/SRGB)


**边缘柔和**

+ 如何在对亮度筛选时，让亮度边缘变得柔和：[catlike_bloom](http://catlikecoding.com/unity/tutorials/advanced-rendering/bloom/) 中的 Soft Threshold 一节

**在对亮度筛选时，如何避免闪烁的斑点：**

+ 什么是闪烁的斑点：[PostProcessing_issues_219](https://github.com/Unity-Technologies/PostProcessing/issues/219)
+ 什么是 Box Filter (Box卷积核)：[wiki_box_blur](https://en.wikipedia.org/wiki/Box_blur)
+ 利用 Box Filter 来快速计算 Gaussian Filter (高斯卷积核) 的原理和方法是什么：[Fast Image Convolutions](https://web.archive.org/web/20060718054020/http://www.acm.uiuc.edu/siggraph/workshops/wjarosz_convolution_2001.pdf)
+ 什么是 Bilinear Filtering : [wiki_Bilinear_filtering](https://en.wikipedia.org/wiki/Bilinear_filtering)


## 4. 模糊(Down Sample)

代码部分

```hlsl
half4 frag_downsample(v2f_img i) : SV_Target
{
    float4 d = _MainTex_TexelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0);

    half3 s;

    // Box filter
    half3 s1 = tex2D(_MainTex, i.uv + d.xy).rgb;
    half3 s2 = tex2D(_MainTex, i.uv + d.zy).rgb;
    half3 s3 = tex2D(_MainTex, i.uv + d.xw).rgb;
    half3 s4 = tex2D(_MainTex, i.uv + d.zw).rgb;

#if ANTI_FLICKER
    // ref : http://graphicrants.blogspot.com.br/2013/12/tone-mapping.html
    // Karis's anti-flicker tonemapping
    half s1w = 1.0 / (Brightness(s1) + 1.0);
    half s2w = 1.0 / (Brightness(s2) + 1.0);
    half s3w = 1.0 / (Brightness(s3) + 1.0);
    half s4w = 1.0 / (Brightness(s4) + 1.0);
    s = (s1 * s1w + s2 * s2w + s3 * s3w + s4 * s4w) / (s1w + s2w + s3w + s4w);
#else
    s = (s1 + s2 + s3 + s4) * 0.25;
#endif 
    
    return half4(s, 1.0);
}
```

这里的要点和前一节的差不多。所以就不细讲了。

这个 Pass 的主要作用是：对图像采样并模糊。所以这里用到了 BoxFilter 对图像进行采样模糊。

## 5. 扩大采样(Up Sample)

```hlsl
half4 frag_upsample(MutiVertex i) : SV_Target
{
    half3 base = tex2D(_BaseTex, i.uvBase);

    float4 d = _MainTex_TexelSize.xyxy * float4(1.0, 1.0, -1.0, 0) * _SamplerScale;

    // 9-tap bilinear unsampler(tent filter)
    half3 s;
    s = tex2D(_MainTex, i.uvMain - d.xy);
    s += tex2D(_MainTex, i.uvMain - d.wy) * 2.0;
    s += tex2D(_MainTex, i.uvMain - d.zy);

    s += tex2D(_MainTex, i.uvMain + d.zw) * 2.0;
    s += tex2D(_MainTex, i.uvMain) * 4.0;
    s += tex2D(_MainTex, i.uvMain + d.xw) * 2.0;

    s += tex2D(_MainTex, i.uvMain + d.zy);
    s += tex2D(_MainTex, i.uvMain + d.wy) * 2.0;
    s += tex2D(_MainTex, i.uvMain + d.xy);
 
    return half4(base + s * 1.0 / 16.0, 1);
}
```

这里采用的卷积核是 Tent 卷积核:

| 1 | 2 | 1 |
|:-:|:-:|:-:|
| 2 | 4 | 2 |
| 1 | 1 | 1 |

这里的主要作用就是对小的图像进行采样，从而形成一张大的图像。

## 总流程概览

**初始：**

![初始][3]

**亮度筛选：**

![亮度筛选][4]

**缩小并模糊（2次）**

![第一次 DownSample][5]

![第二次 DownSample][6]

**放大并叠加**

![第一次 UpSample][7]

![第二次 UpSample][8]

**最后和原图叠加**

![最终][9]


  [1]: http://static.zybuluo.com/HandY/vabj5dgogq93kfc1cidbsgau/Bloom.png
  [2]: http://static.zybuluo.com/HandY/npx3z5smii7ilpt4x7752y1q/UnBloom.png
  [3]: http://static.zybuluo.com/HandY/8irxd3s17d2sv1swkoexf2l0/%E6%97%A0%E6%A0%87%E9%A2%98.png
  [4]: http://static.zybuluo.com/HandY/b7857l3mlz08cig2g7bb4i0p/%E6%97%A0%E6%A0%87%E9%A2%98.png
  [5]: http://static.zybuluo.com/HandY/ehdsvuuifqvw2mkej304m3qv/%E6%97%A0%E6%A0%87%E9%A2%98.png
  [6]: http://static.zybuluo.com/HandY/ow6uvhuohzo5uq7soqtfzy8w/%E6%97%A0%E6%A0%87%E9%A2%98.png
  [7]: http://static.zybuluo.com/HandY/n4z85m7z27q8661k8lsd60w7/%E6%97%A0%E6%A0%87%E9%A2%98.png
  [8]: http://static.zybuluo.com/HandY/mod3rclz30zbhjryy1k1k31y/%E6%97%A0%E6%A0%87%E9%A2%98.png
  [9]: http://static.zybuluo.com/HandY/nni0lmikwnps06z5slxqzgjs/%E6%97%A0%E6%A0%87%E9%A2%98.png