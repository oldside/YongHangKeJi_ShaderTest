Shader "Universal Render Pipeline/Toon"
{
	Properties
	{
		[MainTexture]   _BaseMap("颜色贴图", 2D) = "gray" {}
		[MainColor]     _BaseColor("基础颜色", Color) = (1, 1, 1, 1)

		[NoScaleOffset] _DarkColorMap("暗部颜色贴图", 2D) = "black" {}
						_DarkColor("暗部颜色", Color) = (1, 1, 1, 1)
						_DarkSharp("暗部边界锐利程度",Range(0,0.5)) = 0.1

		[NoScaleOffset] _BrightColorMap("亮部颜色贴图", 2D) = "white" {}
						_BrightColor("亮部颜色", Color) = (1, 1, 1, 1)
						_BrightSharp("亮部边界锐利程度",Range(0,0.5)) = 0.1

		[NoScaleOffset] _OutlineColorMap("描边颜色贴图", 2D) = "white" {}
						_OutlineColor("描边颜色", Color) = (1, 1, 1, 1)
						_OutlineWidth("描边粗细",Range(0,0.01)) = 0.025

		[Space]			_RimLightRange("轮廓光范围",Range(0,1)) = 0.5
						_RimLightSharp("轮廓光边界锐利程度",Range(0,0.5)) = 0.1
						_RimLightIntensity("轮廓光强度",float) = 1

						_AOIntensity ("AO强度",Range(0,1)) = 0.5

			
	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry"}
			LOD 100

			Pass
			{
				NAME "OUTLINE"
				Tags{"LightMode" = "SRPDefaultUnlit"}

				ZWrite On
				Cull Front

				HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x

				#pragma vertex vert
				#pragma fragment frag

				#pragma multi_compile_instancing

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				#include "ToonInput.hlsl"		

				struct Attributes
				{
					float4 positionOS       : POSITION;
					half4 vertexColor		: COLOR0;
					half3 normal			: NORMAL;
					half4 tangent			: TANGENT;
					float2 uv               : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct Varyings
				{
					float2 uv        : TEXCOORD0;
					float4 vertex : SV_POSITION;

					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
				};

				Varyings vert(Attributes input)
				{
					Varyings output = (Varyings)0;

					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_TRANSFER_INSTANCE_ID(input, output);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
					
					//根据_BaseMap_ST计算UV
					output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

					//从顶点色读取切线空间法线值，使用模型本身的法线计算描边会在硬边处断裂
					//切线空间法线存到顶点色通道是额外写的一个小程序完成的，对fbx文件进行操作
					half3 normalTS = input.vertexColor.rgb * 2.0 - 1.0;
				
					//将切线空间法线变换至物体空间
					//获取法线
					half3 normal = input.normal;
					//获取切线
					half4 tangent = input.tangent;
					//法线和切线叉乘计算副切线
					half3 bitangent = cross(normal,tangent.xyz) * tangent.w * unity_WorldTransformParams.w;
					//构建切线→模型空间转换矩阵
					half3x3 TtoO = half3x3(tangent.x, bitangent.x, normal.x,
						tangent.y, bitangent.y, normal.y,
						tangent.z, bitangent.z, normal.z);

					//将法线转换到模型空间下
					half3 normalOS = mul(TtoO, normalTS);

					//将法线从物体空间变换到观察空间
					half3 normalWS = TransformObjectToWorldNormal(normalOS);
					half3 normalVS = TransformWorldToViewDir(normalWS);

					//法线扁平化，防止内凹模型出现描边穿插
					normalVS.z = -0.5;
					normalVS = normalize(normalVS);

					//计算世界坐标位置
					float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
					//计算观察坐标位置
					float3 positionVS = TransformWorldToView(positionWS);

					//顶点位置沿法线方向外扩，乘以一个-positionVS.z可以令描边在屏幕空间中保持固定粗细；使用顶点色alpha通道控制描边粗细
					positionVS = positionVS + normalVS * ( ( -positionVS.z * _OutlineWidth ) * input.vertexColor.a);

					//变化到裁剪空间
					float4 positionCS = TransformWViewToHClip(positionVS);
					output.vertex = positionCS;
										
					return output;
				}

				half4 frag(Varyings input) : SV_Target
				{
					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

					half2 uv = input.uv;
					//计算描边颜色
					half3 outlineColor = SAMPLE_TEXTURE2D(_OutlineColorMap, sampler_OutlineColorMap, uv).rgb * _OutlineColor.rgb;

					return half4(outlineColor, 1);
				}
				ENDHLSL
				}

			Pass
			{
				Name "Toon"
				Tags{"LightMode" = "UniversalForward"}
				Cull Back
				HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma target 2.0
				// 加个主灯光阴影
				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS

				#pragma vertex vert
				#pragma fragment frag

				#pragma multi_compile_instancing

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
				#include "ToonInput.hlsl"		

				struct Attributes
				{
					float4 positionOS       : POSITION;
					half3 normalOS			: NORMAL;
					float2 uv               : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct Varyings
				{
					float2 uv				: TEXCOORD0;
					half3 normalWS			: TEXCOORD2;
					half3 viewDirWS			: TEXCOORD3;

#ifdef _MAIN_LIGHT_SHADOWS
					float4 shadowCoord		: TEXCOORD4;
#endif
					float4 vertex			: SV_POSITION;

					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
				};

				Varyings vert(Attributes input)
				{
					Varyings output = (Varyings)0;

					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_TRANSFER_INSTANCE_ID(input, output);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
					
					//将顶点位置变换为世界空间
					float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
					//将顶点位置从世界空间变换到裁剪空间
					float4 positionCS = TransformWorldToHClip(positionWS);
					output.vertex = positionCS;
					//根据_BaseMap_ST计算UV;
					output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
					//将法线从物体空间变换到世界空间传给片元着色器
					output.normalWS = TransformObjectToWorldNormal(input.normalOS);

					output.viewDirWS = GetCameraPositionWS() - positionWS;

#ifdef _MAIN_LIGHT_SHADOWS
					//计算阴影空间坐标传递给片元着色器
					output.shadowCoord = TransformWorldToShadowCoord(positionWS);
#endif
					return output;
				}

				half4 frag(Varyings input) : SV_Target
				{
					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

					//获取UV
					half2 uv = input.uv;

					//获取基础贴图颜色
					half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;

					//计算AO，为了方便计算把AO强度变量做1-x操作并将范围调整至[-1,1]
					half AO = saturate(baseColor.a + (0.5-_AOIntensity) * 2.0);
					//获取暗部贴图颜色
					half4 darkColor = SAMPLE_TEXTURE2D(_DarkColorMap, sampler_DarkColorMap, uv) * _DarkColor;
					//暗部范围可以由暗部贴图的alpha通道精细控制
					half darkRange = darkColor.a;

					//获取亮部贴图颜色
					half4 brightColor = SAMPLE_TEXTURE2D(_BrightColorMap, sampler_BrightColorMap, uv) * _BrightColor;

					//亮部范围可以由亮部贴图的alpha通道精细控制
					half brightRange = brightColor.a;

					//获取阴影空间坐标
#ifdef _MAIN_LIGHT_SHADOWS
					float4 shadowCoord = input.shadowCoord;
#else
					float4 shadowCoord = float4(0, 0, 0, 0);
#endif					
					//获取主光源
					Light mainLight = GetMainLight(shadowCoord);
					//获取主光源颜色
					half3 lightColor = mainLight.color;
					//获取主光源方向
					half3 lightDirWS = mainLight.direction;
					
					//获取归一化世界法线
					half3 normalWS = SafeNormalize(input.normalWS);
					//获取归一化视线方向
					half3 viewDirWS = SafeNormalize(input.viewDirWS);

					//计算半兰伯特光照
					half halfLambert = dot(lightDirWS, normalWS) * 0.5 + 0.5;

					//计算轮廓光
					half r = 1 - dot(viewDirWS, normalWS);
					half3 rimLight = smoothstep(-_RimLightSharp, _RimLightSharp,  r + _RimLightRange - 1) * _RimLightIntensity * brightColor.rgb;
					
					//定义最终输出颜色变量
					half3 outputColor;

					//计算暗部边界范围，与轮廓光处理方法一样，将取值范围调至[-1,1]然后用smoothstep函数对其值进行“挤压”
					half darkBoundary = smoothstep(-_DarkSharp, _DarkSharp, halfLambert * AO + darkRange - 1);

					//计算亮部边界范围，原理同上，乘以step(0.0001, brightRange)是为了当brightRange值为0时完全消除亮点
					half brightBoundary = smoothstep(-_BrightSharp, _BrightSharp, halfLambert * AO + brightRange - 1) * step(0.0001, brightRange);

					//使用lerp对亮部暗部进行颜色混合
					outputColor = lerp(darkColor.rgb,baseColor.rgb, darkBoundary);
					outputColor = lerp( outputColor, brightColor.rgb, brightBoundary);
					//加上轮廓光
					outputColor += rimLight;

					return  half4(outputColor,1);
				}
				ENDHLSL
			}

			Pass
			{
			Name "ShadowCaster"
			Tags{"LightMode" = "ShadowCaster"}

			ZWrite On
			ZTest LEqual
			Cull Back

			HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma target 2.0

				#pragma multi_compile_instancing

				#pragma vertex ShadowPassVertex
				#pragma fragment ShadowPassFragment

				
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
				#include "ToonInput.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
				
				float3 _LightDirection;
				
				struct Attributes
				{
					float4 positionOS   : POSITION;
					float3 normalOS     : NORMAL;
					float2 texcoord     : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};
				
				struct Varyings
				{
					float2 uv           : TEXCOORD0;
					float4 positionCS   : SV_POSITION;
				};
				
				float4 GetShadowPositionHClip(Attributes input)
				{
					float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
					float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
				
					float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
				
				#if UNITY_REVERSED_Z
					positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#else
					positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#endif
				
					return positionCS;
				}
				
				Varyings ShadowPassVertex(Attributes input)
				{
					Varyings output;
					UNITY_SETUP_INSTANCE_ID(input);
				
					output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
					output.positionCS = GetShadowPositionHClip(input);
					return output;
				}
				
				half4 ShadowPassFragment(Varyings input) : SV_TARGET
				{
					//Alpha(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).a, _BaseColor, 1.0);
					return 0;
				}


				ENDHLSL
			}

			Pass
			{
			Tags{"LightMode" = "DepthOnly"}

			ZWrite On
			ColorMask 0

			HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma target 2.0

				#pragma vertex DepthOnlyVertex
				#pragma fragment DepthOnlyFragment

				#pragma multi_compile_instancing

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
				#include "ToonInput.hlsl"	
				

				struct Attributes
				{
					float4 position     : POSITION;
					float2 texcoord     : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};
				
				struct Varyings
				{
					float2 uv           : TEXCOORD0;
					float4 positionCS   : SV_POSITION;
					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
				};
				
				Varyings DepthOnlyVertex(Attributes input)
				{
					Varyings output = (Varyings)0;
					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
				
					output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
					output.positionCS = TransformObjectToHClip(input.position.xyz);
					return output;
				}
				
				half4 DepthOnlyFragment(Varyings input) : SV_TARGET
				{
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
				
					//Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, 1.0);
					return 0;
				}
				ENDHLSL
			}


		}
			FallBack "Universal Render Pipeline/Unlit"
}
