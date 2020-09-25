#ifndef TOON_INPUT_INCLUDED
#define TOON_INPUT_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	CBUFFER_START(UnityPerMaterial)
	float4 _BaseMap_ST;
	half4 _BaseColor;
	half4 _DarkColor;
	half4 _BrightColor;
	half4 _OutlineColor;
	half _OutlineWidth;
	half _DarkSharp;
	half _BrightSharp;
	half _RimLightRange;
	half _RimLightSharp;
	float _RimLightIntensity;
	half _AOIntensity;

	CBUFFER_END

	TEXTURE2D(_BaseMap);
	SAMPLER(sampler_BaseMap);

	TEXTURE2D(_DarkColorMap);
	SAMPLER(sampler_DarkColorMap);

	TEXTURE2D(_BrightColorMap);
	SAMPLER(sampler_BrightColorMap);

	TEXTURE2D(_OutlineColorMap);
	SAMPLER(sampler_OutlineColorMap);
	
#endif