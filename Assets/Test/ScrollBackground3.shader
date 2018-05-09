Shader "Custom/ScrollBackground3" {
	
	Properties 
	{
		_TextureUp("The Upper Texture", 2D) = "white" {}
		_TextureMiddle("The Middle Texture", 2D) = "white" {}
		_TextureDown("The Down Texture", 2D) = "white" {}
		_ScrollSpeed("Scroll Speed", Float) = 0.1
	}


	SubShader 
	{
		Tags 
		{ 
			"RenderType"="Transparent" 
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
		}
		
		Pass 
		{
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha  

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			sampler2D _TextureUp;
			sampler2D _TextureMiddle;
			sampler2D _TextureDown;
			float _ScrollSpeed;

			struct vertexInput
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0; 
			};

			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;

				output.pos = UnityObjectToClipPos(input.vertex);
				output.uv = input.texcoord;

				return output;
			}

			fixed4 frag(vertexOutput input) : SV_Target
			{
				float addV = _ScrollSpeed * _Time.y;
				float mod3AddV = fmod(addV, 3);

				float originV = input.uv.y;

				if(mod3AddV < 1 - originV)
				{
					return tex2D(_TextureUp, float2(input.uv.x, mod3AddV + originV));
				}
				else if(mod3AddV < 2 - originV)
				{
					return tex2D(_TextureDown, float2(input.uv.x, mod3AddV + originV - 1));
				}
				else if(mod3AddV < 3 - originV)
				{
					return tex2D(_TextureMiddle, float2(input.uv.x, mod3AddV + originV - 2));
				}
				else
				{
					return tex2D(_TextureUp, float2(input.uv.x, mod3AddV + originV - 3));
				}

				//return fixed4(currentUV.y, currentUV.y, currentUV.y, 1);
				return fixed4(1, 1, 1, 0);
			}

			ENDCG
		}

	}
	FallBack "Diffuse"
}
