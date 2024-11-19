//基于视差映射的水晶Shader。
Shader "Mh2/Effects/ParallaxCrystal"
{
        Properties
        { 
            [MainTexture] _BaseMap("Base Map", 2D) = "white"{}
            [HDR]_BaseColorTint("BaseMapColorTint",Color) = (1,1,1,1)
            _HeightMap("高度图",2D) = "white"{}
            _HeightMapVec("x:HeightSpeedX y:HeightSpeedY z:HeightScale,w:HeightDistortIntensity",Vector) = (0.1,0.1,1,0.5)
            _DistortToggle("扰动图开关",Float) = 0
            _DistortMap("扰动图",2D) = "black"{}
            _DistortVec("x：DistortSpeedX。y:DistortSpeedY。z:DistortIntensity",Vector) = (0.2,0.2,0.1,0.2) 
            
            _NormalMap("法线贴图",2D) = "bump"{}
            
            _Layer1Toggle("叠加贴图1开关",Float) = 0
            _Layer1Tex("层1图",2D) = "white"{}
            [HDR]_Layer1ColorTint("层1图颜色",Color) = (1,1,1,1)
            _Layer1Vec("层1Vec x:SpeedX,y:SpeedY,Z:heightStep,Y:FallOffStep",Vector) = (0,0,0.2,0.9)       
                        
            _Layer2Toggle("叠加贴图2开关",Float) = 0
            _Layer2Tex("层2图",2D) = "white"{}
            [HDR]_Layer2ColorTint("层2图颜色",Color) = (1,1,1,1)
            _Layer2Vec("层2Vec x:SpeedX,y:SpeedY,Z:heightStep,Y:FallOffStep",Vector) = (0,0,0.2,0.9)
            
            _MatCapToggle("MatCap开关",Float) = 0
            _MatCapTex("MatCap图",2D) = "white"{}
            [HDR]_MatCapColorTint("MatCap颜色",Color) = (1,1,1,1)
            
            _FresnelToggle("菲尼尔开关",Float) = 0
            _FresnelVec("菲涅尔Vec",Vector) = (0.5,0.5,0,0)
            [HDR]_FresnelColor("菲涅尔颜色",Color) = (1,1,1,1)
            
            _MRRDissolveToggle("溶解开关",Float) = 0
            _DissolveNoiseMap("溶解噪波图",2D) = "white"{}
            _DissovlveCenter("溶解中心位置",Vector) = (0,0,0,0)
            [HDR]_DissolveColor("溶解颜色",Color) = (1,1,1,1)
            _DissolveVec1("溶解矢量 x 位置 y 溶解范围 z 顶点膨胀距离 w  ",Vector) = (1,1,1,1)
            _DissolveVec2("溶解矢量 x 溶解图动画X y 溶解图动画Y z 颜色位置 w 颜色过度范围 ",Vector) = (1,1,1,1)
            
//            _VertexOffset_Map("顶点偏移贴图",2D) = "white"{}
            _VertexOffsetVec("顶点偏移矢量",Vector) = (-0.1,0.1,0.5,0)
             
           
            [HideInInspector] _SrcBlend ("__src-ignore", Float) = 1.0
            [HideInInspector] _DstBlend ("__dst-ignore", Float) = 0.0
            [HideInInspector] _Cull ("__cull-ignore", Float) = 2.0
            [HideInInspector] _ZTest ("__ztest-ignore", Float) = 4.0 //默认值LEqual
            [HideInInspector] _ZWrite("__ZWrite-ignore", Float) = 0 //默认值LEqual
            
            [HideInInspector] _BlendMode("__BlendMode", Float) = 0 //默认值LEqual
            
            _ScreenOutlineToggle("描边开关",Float) = 1
            
            [HideInInspector]_Stencil ("Stencil ID [0;255]", Float) = 0
            [HideInInspector]_StencilReadMask ("ReadMask [0;255]", Int) = 255
            [HideInInspector]_StencilWriteMask ("WriteMask [0;255]", Int) = 255
            [HideInInspector][Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comparison", Int) = 3
            [HideInInspector][Enum(UnityEngine.Rendering.StencilOp)] _StencilOp ("Stencil Operation", Int) = 0
            [HideInInspector][Enum(UnityEngine.Rendering.StencilOp)] _StencilFail ("Stencil Fail", Int) = 0
            [HideInInspector][Enum(UnityEngine.Rendering.StencilOp)] _StencilZFail ("Stencil ZFail", Int) = 0
            
            // Editmode props  编辑模式下的PropFlags？
            [HideInInspector] _QueueBias ("Queue偏移_QueueBias", Float) =0
            _ForceZWriteToggle("_ForceZWriteToggle",Float) = 0

            
            
        }
    
        // The SubShader block containing the Shader code.
        SubShader
        {
            // SubShader Tags define when and under which conditions a SubShader block or
            // a pass is executed.
            Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
    
            //BlendOp[_BlendOp]   //考虑注释~
            Blend[_SrcBlend][_DstBlend]
            ZWrite [_ZWrite]//粒子不写入深度缓冲
            ZTest[_ZTest]
            
            
            
            Pass
            {
                
                Stencil 
                {
                    Ref [_Stencil]
                    Comp [_StencilComp]
                    Pass [_StencilOp]
                    ReadMask [_StencilReadMask]
                    WriteMask [_StencilWriteMask]
                    ZFail [_StencilZFail]
                    
                }

//                Blend SrcAlpha OneMinusSrcAlpha
                HLSLPROGRAM
                // This line defines the name of the vertex shader.
                #pragma vertex vert
                // This line defines the name of the fragment shader.
                #pragma fragment frag

                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local _NORMALMAP

                #pragma  shader_feature_local CRYSTAL_DISTORT
                #pragma  shader_feature_local CRYSTAL_LAYER1
                #pragma  shader_feature_local CRYSTAL_LAYER2
                #pragma  shader_feature_local CRYSTAL_MATCAP
                #pragma  shader_feature_local CRYSTAL_FRESNEL
                #pragma  shader_feature_local MRR_DISSOLVE
                #pragma  shader_feature_local CRYSTAL_VERTEX_OFFSET
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
                #include "Packages/com.r2.render.utility/Shader/HLSL/Mh2_Utility.hlsl"

                #define CRYSTAL_BASE_PASS
                #include "Packages/com.r2.render.utility/Shader/HLSL/Mh2ParallexCrystalFuciton.hlsl"
    
               
                ENDHLSL
            }
            
            Pass
            {
                Name "ShadowCaster"
                Tags
                {
                    "LightMode" = "ShadowCaster"
                }

                ZWrite On
                ZTest LEqual
                ColorMask 0

                HLSLPROGRAM
                #pragma target 2.0

                //--------------------------------------
                // GPU Instancing
                #pragma multi_compile_instancing
                #pragma multi_compile _ DOTS_INSTANCING_ON
                #pragma target 3.5 DOTS_INSTANCING_ON

                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ALPHATEST_ON
                #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #pragma  shader_feature_local CRYSTAL_VERTEX_OFFSET
                #pragma  shader_feature_local MRR_DISSOLVE

                // -------------------------------------
                // Universal Pipeline keywords

                // -------------------------------------
                // Unity defined keywords
                #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

                // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

                #pragma vertex ShadowPassVertex
                #pragma fragment ShadowPassFragment

                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
                // #if defined(LOD_FADE_CROSSFADE)
                //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
                // #endif
                #include "Packages/com.r2.render.utility/Shader/HLSL/Mh2ParallexCrystalFuciton.hlsl"

                // Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
                // For Directional lights, _LightDirection is used when applying shadow Normal Bias.
                // For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
                float3 _LightDirection;
                float3 _LightPosition;

                struct ShadowCasterAttributes
                {
                    float4 positionOS   : POSITION;
                    float3 normalOS     : NORMAL;
                    float2 uv           : TEXCOORD0;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                struct ShadowCasterVaryings
                {
                    float2 uv           : TEXCOORD0;
                    float4 DissolveUV   : TEXCOORD1;
                    float3 positionWS   : TEXCOORD2;

                    // The positions in this struct must have the SV_POSITION semantic.
                    float4 positionHCS  : SV_POSITION;
                };

                // float4 GetShadowPositionHClip(Attributes input)
                // {
                //     float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                //     float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                //
                // #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                //     float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                // #else
                //     float3 lightDirectionWS = _LightDirection;
                // #endif
                //
                //     float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                //
                // #if UNITY_REVERSED_Z
                //     positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                // #else
                //     positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                // #endif
                //
                //     return positionCS;
                // }

                ShadowCasterVaryings ShadowPassVertex(ShadowCasterAttributes IN)
                {
                    ShadowCasterVaryings OUT;
                    // UNITY_SETUP_INSTANCE_ID(input);

                    OUT.positionWS = TransformObjectToWorld(IN.positionOS);

                    // output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                    half3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
                    #ifdef MRR_DISSOLVE
                        OUT.positionWS = calDissolveWSInVextex(OUT.positionWS,normalWS);
                    #endif

                    #ifdef CRYSTAL_VERTEX_OFFSET
                        OUT.positionWS = calVertexOffsetWSInVextex(OUT.positionWS,normalWS);
                    #endif
                    OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);

                    #ifdef MRR_DISSOLVE
                        OUT.DissolveUV.xy =  calDissolveUV(IN.uv,_Time.x);
                    #endif
                    
                    return OUT;
                }

                half4 ShadowPassFragment(ShadowCasterVaryings IN) : SV_TARGET
                {
                    // Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                    half3 color = half3(0,0,0);
                    #ifdef MRR_DISSOLVE
                        calDissolveInFrag(IN.positionWS,IN.DissolveUV.xy,color);
                    #endif
                    
                // #ifdef LOD_FADE_CROSSFADE
                //     LODFadeCrossFade(input.positionCS);
                // #endif

                    return 0;
                }
                ENDHLSL
            }
        }
            CustomEditor "ParallexCrystalShaderGUI"


}
