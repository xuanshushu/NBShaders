#ifndef MH2_PARTICLESUNLITFORWARDPASS
    #define MH2_PARTICLESUNLITFORWARDPASS

    // #include "../../CGInclude/W9_Common.cginc"

   

    struct AttributesParticle//即URP语境下的appdata
    {
        float4 vertex: POSITION;
        float3 normalOS: NORMAL;
        half4 color: COLOR;
        // #if defined(_FLIPBOOKBLENDING_ON) && !defined(UNITY_PARTICLE_INSTANCING_ENABLED)  // 混合序列可能会打断instance？
        #if defined(_FLIPBOOKBLENDING_ON)
            float4 texcoords: TEXCOORD0;       //texcoords.zw就是粒子那边新建的UV2
            float3 texcoordBlend: TEXCOORD3;//注意，假如需要UI支持，則Canvas要開放相關Channel
        #else
            float4 texcoords: TEXCOORD0;
        #endif

        #ifdef _PARALLAX_MAPPING
            float4 tangentOS     : TANGENT;
        #endif
        
        float4 Custom1: TEXCOORD1;
        float4 Custom2: TEXCOORD2;
        
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
    struct VaryingsParticle//即URP语境下的v2f
    {
        float4 clipPos: SV_POSITION;
        
        half4 color: COLOR;
        float4 texcoord: TEXCOORD0;  // 主帖图 和 mask
        
        #if defined (_EMISSION)   || defined(_COLORMAPBLEND)
            float4 emissionColorBlendTexcoord: TEXCOORD1;  // 流光
        #endif

        #ifdef _NOISEMAP
            float4 noisemapTexcoord:TEXCOORD2;//Noise
        #endif
 
        #if defined(_DISSOLVE) 

            float4 dissolveTexcoord:TEXCOORD15;
            float4 dissolveNoiseTexcoord: TEXCOORD5;

        #endif

        
        float4 positionWS: TEXCOORD3;
        float4 positionOS: TEXCOORD12;
        // float3 texcoord2AndBlend1: TEXCOORD4;  //三个数据留给美术自定义数据传给粒子,前面参数描述为PerticleCustomData
        
        
        
        // #if defined(_FLIPBOOKBLENDING_ON)
        //同时也给脚本用，就不区分了。
        // #endif
        float4 texcoord2AndSpecialUV: TEXCOORD6;  // UV2和SpecialUV

        float4 positionNDC: TEXCOORD7;
        
        
        float4 VaryingsP_Custom1: TEXCOORD8;
        float4 VaryingsP_Custom2: TEXCOORD9;
        

        float4 normalWSAndAnimBlend: TEXCOORD10;
        
        float3 fresnelViewDir :TEXCOORD11;
        
        float3 viewDirWS :TEXCOORD13;
        float4 texcoordMaskMap2 : TEXCOORD14;

        #ifdef _PARALLAX_MAPPING
          half3  tangentViewDir : TEXCOORD16;
        #endif
        
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    bool isProcessUVInFrag()
    {
        if(CheckLocalFlags(FLAG_BIT_PARTICLE_POLARCOORDINATES_ON) || CheckLocalFlags(FLAG_BIT_PARTICLE_UTWIRL_ON)) 
        {
            return true;
        }
        #if defined(_DEPTH_DECAL) || defined(_PARALLAX_MAPPING) || defined(_SCREEN_DISTORT_MODE)
            return true;
        #endif
        return false;
    }
    
    
    ///////////////////////////////////////////////////////////////////////////////
    //                  Vertex and Fragment functions                            //

    
    VaryingsParticle vertParticleUnlit(AttributesParticle input)
    {
        VaryingsParticle output = (VaryingsParticle)0;

        output.VaryingsP_Custom1 = input.Custom1; //xy主贴图流动，z溶解强度，w色相
        output.VaryingsP_Custom2 = input.Custom2; //xy Mask图流动 z菲尼尔偏移
        
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        // time = _Time.y % 1000;
        time = _Time.y;
        // UNITY_FLATTEN
        // if (CheckLocalFlags(FLAG_BIT_PARTICLE_UNSCALETIME_ON))
        // {
        //     // time = _UnscaleTime.y % 1000;
        //     time = _UnscaleTime.y;
        // }
        // else if(CheckLocalFlags(FLAG_BIT_PARTICLE_SCRIPTABLETIME_ON))
        // {
        //     // time = _ScriptableTime % 1000;
        //     time = _ScriptableTime;
        // }

        float4 positionOS = input.vertex;

        if(CheckLocalFlags(FLAG_BIT_PARTICLE_VERTEX_OFFSET_ON))
        {
            // if(CheckLocalFlags1(FLAG_BIT_PARTICLE_CUSTOMDATA2X_VERTEXOFFSETX))
            // {
            //     _VertexOffset_Map_ST.z += input.Custom2.x;
            // }
            // if(CheckLocalFlags1(FLAG_BIT_PARTICLE_CUSTOMDATA2Y_VERTEXOFFSETY))
            // {
            //     _VertexOffset_Map_ST.w += input.Custom2.y;
            // }
            // if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_CUSTOMDATA2Z_VERTEXOFFSET_INTENSITY))
            // {
            //     _VertexOffset_Vec.z = input.Custom2.z;
            // }
            _VertexOffset_Map_ST.z += GetCustomData(_W9ParticleCustomDataFlag1,FLAGBIT_POS_1_CUSTOMDATA_VERTEX_OFFSET_X,0,input.Custom1,input.Custom2);
            _VertexOffset_Map_ST.w += GetCustomData(_W9ParticleCustomDataFlag1,FLAGBIT_POS_1_CUSTOMDATA_VERTEX_OFFSET_Y,0,input.Custom1,input.Custom2);
            _VertexOffset_Vec.z = GetCustomData(_W9ParticleCustomDataFlag1,FLAGBIT_POS_1_CUSTOMDATA_VERTEXOFFSET_INTENSITY,_VertexOffset_Vec.z,input.Custom1,input.Custom2);
            
            positionOS.xyz = VetexOffset(positionOS,input.texcoords.xy,input.normalOS);
        }
        
        
        // position ws is used to compute eye depth in vertFading
        output.positionWS.xyz = mul(unity_ObjectToWorld, positionOS).xyz;
        output.positionOS.xyz = positionOS;

        output.clipPos = TransformObjectToHClip(positionOS);
        
        #ifdef _PARALLAX_MAPPING
            //视差贴图，需要在Tangent空间下计算。
            float3x3 objectToTangent =
                float3x3(
                    input.tangentOS.xyz,
                    cross(input.normalOS,input.tangentOS.xyz)  * input.tangentOS.w,//Bitangent
                    input.normalOS
                );
            output.tangentViewDir = mul(objectToTangent,GetObjectSpaceNormalizeViewDir(positionOS));
        #endif
        
        // float unityFogFactor = UNITY_Z_0_FAR_FROM_CLIPSPACE(output.clipPos.z) * unity_FogParams.z + unity_FogParams.w; //Unity内置管线的雾效Factor做法，会定义一个unityFogFactor变量并赋值。传入的是裁剪空间的z分量。
//
        float unityFogFactor = ComputeFogFactor(output.clipPos.z);

        output.positionWS.w = unityFogFactor;
        
        output.color = TryLinearize(input.color);

        // //UI线性空间Fix对文字单独进行的矫正
        // UNITY_FLATTEN
        // if (CheckLocalFlags(FLAG_BIT_PARTICLE_UIEFFECT_ON))
        // {
        //     output.color.rgb = LinearToGammaSpace(output.color.rgb);
        // }

        output.viewDirWS = GetWorldSpaceNormalizeViewDir(output.positionWS.xyz);
        output.normalWSAndAnimBlend.xyz = TransformObjectToWorldNormal(input.normalOS.xyz);
        
        
        UNITY_FLATTEN
        if(CheckLocalFlags(FLAG_BIT_PARTICLE_FRESNEL_ON))
        {
            // output.normalWSAndAnimBlend.xyz = TransformObjectToWorldNormal(input.normalOS.xyz);
            // output.fresnelViewDir = Rotation(normalize(output.viewDirWS),_FresnelRotation.xyz); 
            output.fresnelViewDir = output.viewDirWS; 
        }

        
        // if(CheckLocalFlags(FLAG_BIT_PARTICLE_USETEXCOORD2))
        // {
        //     input.texcoords.xy = input.Custom2.xy;
        // }
        output.texcoord.xy = input.texcoords.xy;

     
  
        
        
        //顶点处理的原则：
        //Twirl和极坐标,贴花处理，在片段着色器层处理UV。
        //BaseMap，遮罩Mask，Noise，高光（自发光） 和极坐标处理相关。
        if(!isProcessUVInFrag())
        {

            float2 specialUVInTexcoord3 = 0;
            //如果同时在粒子系统里开启序列帧融帧和特殊UV通道模式。
            #if _FLIPBOOKBLENDING_ON
                if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_IS_PARTICLE_SYSTEM) & (CheckLocalFlags1(FLAG_BIT_PARTICLE_1_USE_TEXCOORD1)|CheckLocalFlags1(FLAG_BIT_PARTICLE_1_USE_TEXCOORD2)))
                {
                    specialUVInTexcoord3 = input.texcoordBlend.yz;
                    output.texcoord2AndSpecialUV.zw = specialUVInTexcoord3;
                }
            #endif
            ParticleUVs particleUVs = (ParticleUVs)0;
            float2 screenUV = 0;
            // float4 uv1uv2 = float4(output.texcoord.xy,output.texcoord2AndBlend.xy);
            
            ParticleProcessUV(input.texcoords, specialUVInTexcoord3,particleUVs,output.VaryingsP_Custom1,output.VaryingsP_Custom2,screenUV,output.positionOS.xyz);
            output.texcoord2AndSpecialUV.xy = particleUVs.animBlendUV;
            output.texcoord2AndSpecialUV.zw= particleUVs.specUV;
            output.texcoord.xy = particleUVs.mainTexUV;
            output.texcoord.zw = particleUVs.maskMapUV;
           
            output.texcoordMaskMap2.xy = particleUVs.maskMap2UV;
            output.texcoordMaskMap2.zw = particleUVs.maskMap3UV;
            #if defined (_EMISSION)   || defined(_COLORMAPBLEND)
                output.emissionColorBlendTexcoord.xy = particleUVs.emissionUV;
                output.emissionColorBlendTexcoord.zw = particleUVs.colorBlendUV;
            #endif

            #ifdef _NOISEMAP
                output.noisemapTexcoord.xy = particleUVs.noiseMapUV;
                output.noisemapTexcoord.zw = particleUVs.noiseMaskMapUV;
            #endif
            #if defined(_DISSOLVE) 
                output.dissolveTexcoord.xy = particleUVs.dissolve_uv;
                output.dissolveTexcoord.zw = particleUVs.dissolve_mask_uv;
                output.dissolveNoiseTexcoord.xy = particleUVs.dissolve_noise1_UV;
                output.dissolveNoiseTexcoord.zw = particleUVs.dissolve_noise2_UV;
            #endif
        }
        else
        {
            output.texcoord = input.texcoords;
            #if _FLIPBOOKBLENDING_ON
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_IS_PARTICLE_SYSTEM) & CheckLocalFlags1(FLAG_BIT_PARTICLE_1_USE_TEXCOORD2))
            {
                output.texcoord2AndSpecialUV.zw = input.texcoordBlend.yz;
            }
            #endif
        }
        #ifdef _FLIPBOOKBLENDING_ON
            //粒子帧融合的情况，兼容一下。
            output.normalWSAndAnimBlend.w = input.texcoordBlend.x;
        #endif

        


        
        UNITY_BRANCH
        if(needEyeDepth())
        {
            float4 ndc = output.clipPos*0.5f;
            output.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
            output.positionNDC.zw = output.clipPos.zw;
        }
 
        return output;
    }


    ///////////////////////Fragment functions  ////////////////////////
    
    half4 fragParticleUnlit(VaryingsParticle input, half facing : VFACE): SV_Target
    {

        input.viewDirWS = normalize(input.viewDirWS );
        
        
        UNITY_SETUP_INSTANCE_ID(input);
        //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        // time = _Time.y % 1000;
        time = _Time.y;
        // UNITY_FLATTEN
        // if (CheckLocalFlags(FLAG_BIT_PARTICLE_UNSCALETIME_ON))
        // {
        //     // time = _UnscaleTime.y % 1000;
        //     time = _UnscaleTime.y;
        // }
        //
        // if (CheckLocalFlags(FLAG_BIT_PARTICLE_SCRIPTABLETIME_ON))
        // {
        //     // time = _ScriptableTime % 1000;
        //     time = _ScriptableTime;
        // }
        
        
        // UNITY_FLATTEN
        // if (CheckLocalFlags(FLAG_BIT_PARTICLE_CUSTOMDATA1_ON))
        // {
        //     _CustomData1X = input.VaryingsP_Custom1.x;
        //     _CustomData1Y = input.VaryingsP_Custom1.y;
        //     _CustomData1Z = input.VaryingsP_Custom1.z;
        //     _CustomData1W = input.VaryingsP_Custom1.w;
        // }
        //
        //
        // UNITY_FLATTEN
        // if (CheckLocalFlags(FLAG_BIT_PARTICLE_CUSTOMDATA2_ON))
        // {
        //      _CustomData2X = input.VaryingsP_Custom2.x;
        //      _CustomData2Y = input.VaryingsP_Custom2.y;
        //      _CustomData2Z = input.VaryingsP_Custom2.z;
        //      // _CustomData2W = input.VaryingsP_Custom2.w;
        // }  

        

        float2 screenUV = input.clipPos.xy / _ScaledScreenParams.xy;
        
        real sceneZBufferDepth = 0;
        real sceneZ = 0;
        
        UNITY_BRANCH
        if(needSceneDepth())
        {
            #if UNITY_REVERSED_Z
            // return half4(1,0,0,1);
            sceneZBufferDepth = SampleSceneDepth(screenUV);
            #else
            // Adjust z to match NDC for OpenGL
            sceneZBufferDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
            #endif
            sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(sceneZBufferDepth, _ZBufferParams) : LinearDepthToEyeDepth(sceneZBufferDepth);//场景当前深度
        }
        
        real thisZ = 0;
        if(needEyeDepth())
        {
            thisZ = LinearEyeDepth(input.positionNDC.z / input.positionNDC.w, _ZBufferParams);//当前Frag深度。
        }
        
        // half3 fragViewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS.xyz);
        // half3 fragWorldPos = _WorldSpaceCameraPos - fragViewDirWS*sceneZ;
        

        #ifdef _DEPTH_DECAL
            float3 fragWorldPos = ComputeWorldSpacePosition(screenUV, sceneZBufferDepth, UNITY_MATRIX_I_VP);
            float3 fragobjectPos = TransformWorldToObject(fragWorldPos);
            
            
            // clip(float3(0.5, 0.5, 0.5) - abs(fragobjectPos));
            float3 absFragObjectPos = abs(fragobjectPos);
            half clipValue = step(absFragObjectPos.x,0.5);
            clipValue *= step(absFragObjectPos.y,0.5);
            clipValue *= step(absFragObjectPos.z,0.5);
            half decalAlpha = Mh2Remap (abs(fragobjectPos.y),0.1,0.5,1,0);
            decalAlpha *= clipValue;
            float2 decalUV = fragobjectPos.xz + 0.5;

        #endif
        //#region 片段着色器uv处理部分

        float4 uv = input.texcoord;
        #ifdef _DEPTH_DECAL
            uv.xy = decalUV;
        #endif
        // #else
        // uv.xy = input.texcoord.xy; //主贴图UV
        // #endif

        float3 blendUv;
        blendUv.xy = input.texcoord2AndSpecialUV.xy;
        blendUv.z = input.normalWSAndAnimBlend.w;
        float2 MaskMapuv;
        float2 MaskMapuv2;
        float2 MaskMapuv3;
        float2 noiseMap_uv;
        float2 noiseMaskMap_uv;
        float2 colorBlendMap_uv;
        float2 emission_uv;
        float2 dissolve_uv;
        float2 dissolve_mask_uv;
        float4 dissolve_noise_uv;

        //如果同时在粒子系统里开启序列帧融帧和特殊UV通道模式。
        
        if(isProcessUVInFrag())
        {
            float2 specialUVInTexcoord3 = 0;
            #if _FLIPBOOKBLENDING_ON
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_IS_PARTICLE_SYSTEM) & (CheckLocalFlags1(FLAG_BIT_PARTICLE_1_USE_TEXCOORD2)))
            {
                specialUVInTexcoord3 = input.texcoord2AndSpecialUV.zw;
            }
            
            #endif
            ParticleUVs particleUVs = (ParticleUVs)0;
            ParticleProcessUV(uv,specialUVInTexcoord3,particleUVs,input.VaryingsP_Custom1,input.VaryingsP_Custom2,screenUV,input.positionOS.xyz);
            uv.xy = particleUVs.mainTexUV;
            blendUv.xy = particleUVs.animBlendUV;
            MaskMapuv = particleUVs.maskMapUV;
            MaskMapuv2 = particleUVs.maskMap2UV;
            MaskMapuv3 = particleUVs.maskMap3UV;
            emission_uv = particleUVs.emissionUV;
            dissolve_uv = particleUVs.dissolve_uv;
            dissolve_mask_uv = particleUVs.dissolve_mask_uv;
            colorBlendMap_uv = particleUVs.colorBlendUV;
            noiseMap_uv = particleUVs.noiseMapUV;
            noiseMaskMap_uv = particleUVs.noiseMaskMapUV;
            dissolve_noise_uv = float4(particleUVs.dissolve_noise1_UV,particleUVs.dissolve_noise2_UV);
            
        }
        else
        {
            MaskMapuv = input.texcoord.zw;
            MaskMapuv2 = input.texcoordMaskMap2.xy;
            MaskMapuv3 = input.texcoordMaskMap2.zw;
            #ifdef _NOISEMAP
                noiseMap_uv = input.noisemapTexcoord.xy;
                noiseMaskMap_uv = input.noisemapTexcoord.zw;
            #endif
            
            #if defined (_EMISSION)   || defined(_COLORMAPBLEND)
                emission_uv = input.emissionColorBlendTexcoord.xy;
                colorBlendMap_uv = input.emissionColorBlendTexcoord.zw;
            #endif
            
            #ifdef _DISSOLVE
                dissolve_uv = input.dissolveTexcoord.xy;
                dissolve_mask_uv = input.dissolveTexcoord.zw;
                dissolve_noise_uv = input.dissolveNoiseTexcoord;
            #endif
        }
        // return half4(MaskMapuv,0,1);
        half2 originUV = uv;

        #ifdef _PARALLAX_MAPPING
            uv.xy = ParallaxOcclusionMapping(uv,input.tangentViewDir);
            // uv = ParallaxMappingSimple(uv,input.tangentViewDir);
            // uv = ParallaxMappingPeelDepth(uv,input.tangentViewDir);
        #endif
        
        half2 cum_noise = 0;
        half2 cum_noise_xy = 0.5;
        #if defined(_NOISEMAP)
            cum_noise = SampleNoise(_NoiseOffset, _NoiseMap, noiseMap_uv, input.positionWS.xyz);
            UNITY_FLATTEN
            if(CheckLocalFlags(FLAG_BIT_PARTICLE_NOISEMAP_NORMALIZEED_ON))
            {
                cum_noise = cum_noise * 2 - 1;
            }
            UNITY_BRANCH
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_NOISE_MASKMAP))
            {
                cum_noise *= SampleTexture2DWithWrapFlags(_NoiseMaskMap,noiseMaskMap_uv,FLAG_BIT_WRAPMODE_NOISE_MASKMAP).r;
            }
            // if(CheckLocalFlags1(FLAG_BIT_PARTICLE_CUSTOMDATA1Z_NOISE_INTENSITY))
            // {
            //     _TexDistortion_intensity = input.VaryingsP_Custom1.z;
            // }
            _TexDistortion_intensity = GetCustomData(_W9ParticleCustomDataFlag1,FLAGBIT_POS_1_CUSTOMDATA_NOISE_INTENSITY,_TexDistortion_intensity,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
    
            _DistortionDirection.x += GetCustomData(_W9ParticleCustomDataFlag2,FLAGBIT_POS_2_CUSTOMDATA_NOISE_DIRECTION_X,0,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
            _DistortionDirection.y += GetCustomData(_W9ParticleCustomDataFlag2,FLAGBIT_POS_2_CUSTOMDATA_NOISE_DIRECTION_Y,0,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
            // 将扭曲放到post去做
            #if defined(_SCREEN_DISTORT_MODE)
                cum_noise_xy = cum_noise * _TexDistortion_intensity * _DistortionDirection.xy;
                cum_noise_xy = cum_noise_xy * 1.25 + 0.5;
            #endif

            float2 mainTexNoise =  cum_noise * _TexDistortion_intensity * _DistortionDirection.xy;
            uv.xy += mainTexNoise;//主贴图纹理扭曲
            blendUv.xy += mainTexNoise;
        #endif
        
        // SampleAlbedo--------------------
        half4 albedo = 0;

        #if defined(_SCREEN_DISTORT_MODE)

        albedo = half4(cum_noise_xy, 1.0, 1.0);

        #else

        UNITY_FLATTEN
        if(CheckLocalFlags(FLAG_BIT_PARTICLE_BACKCOLOR))
        {
            _BaseColor = facing > 0 ? _BaseColor : _BaseBackColor;
        }


        Texture2D baseMap;
        
        #ifdef _SCREEN_DISTORT_MODE
            baseMap = _ScreenColorCopy1;
        #else
            baseMap = _BaseMap;
        #endif
        
        UNITY_BRANCH
        if (CheckLocalFlags(FLAG_BIT_PARTICLE_UIEFFECT_ON) & !CheckLocalFlags1(FLAG_BIT_PARTICLE_1_UIEFFECT_BASEMAP_MODE))
        {
            albedo = BlendTexture(_MainTex, uv, blendUv) * _Color;
        }
        else if (CheckLocalFlags(FLAG_BIT_PARTICLE_CHORATICABERRAT))
        {
            // if(CheckLocalFlags1(FLAG_BIT_PARTICLE_CUSTOMDATA2W_CHORATICABERRAT_INTENSITY))
            // {
            //     _DistortionDirection.z = input.VaryingsP_Custom2.w;
            // }
            _DistortionDirection.z = GetCustomData(_W9ParticleCustomDataFlag0,FLAGBIT_POS_0_CUSTOMDATA_CHORATICABERRAT_INTENSITY,_DistortionDirection.z,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
            // #if defined(_NOISEMAP)
            albedo = DistortionChoraticaberrat(baseMap,originUV,uv,_DistortionDirection.z,FLAG_BIT_WRAPMODE_BASEMAP);
            // #endif
        }
        else
        {
             albedo = BlendTexture(baseMap, uv, blendUv,FLAG_BIT_WRAPMODE_BASEMAP);
            
        }
        // return half4(blendUv.zzz,1);
        albedo *= _BaseColor ;
        albedo.rgb *= _BaseColorIntensityForTimeline;

        #endif


        
        half alpha = albedo.a;
        half3 result = albedo.rgb;
        UNITY_BRANCH
        if(CheckLocalFlags(FLAG_BIT_HUESHIFT_ON))
        {
            half3 hsv = RgbToHsv(result);
            // UNITY_FLATTEN
            // if(CheckLocalFlags(FLAG_BIT_PARTICLE_CUSTOMDATA1W_HUESHIFT))
            // {
            //     // _HueShift += _CustomData1W;
            //     _HueShift = input.VaryingsP_Custom1.w;
            // }
            _HueShift = GetCustomData(_W9ParticleCustomDataFlag0,FLAGBIT_POS_0_CUSTOMDATA_HUESHIFT,_HueShift,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
            hsv.r += _HueShift;
            result = HsvToRgb(hsv);
        }
        

        
        // return half4(result,1);
        
        
        //流光部分
        half4 emission = half4(0, 0, 0,1);
        #if defined(_EMISSION)
            #ifdef _NOISEMAP
                emission_uv += cum_noise * _Emi_Distortion_intensity;
            #endif
            // emission = tex2D_TryLinearizeWithoutAlphaFX(_EmissionMap,emission_uv);
            emission = SampleTexture2DWithWrapFlags(_EmissionMap,emission_uv,FLAG_BIT_WRAPMODE_EMISSIONMAP);
            emission.xyz *= emission.a;
            _EmissionMapColor *=  _EmissionMapColorIntensity;
            emission.xyz *= _EmissionMapColor;
        
            // half3 emission = Liuguang(emission_uv, _CustomData2W,_EmissionMap,_uvRapSoft, uvTexColor, cum_noise * _Emi_Distortion_intensity);
            
            // alpha = saturate(alpha + emission.x * _EmissionSelfAlphaWeight);    //让有流光的地方A通道更实一些
     
        #endif
        
        result += emission;

        //溶解部分
        #if defined(_DISSOLVE)
            #ifdef _NOISEMAP
                dissolve_uv += cum_noise * _DissolveOffsetRotateDistort.w;

                UNITY_FLATTEN
                if(CheckLocalFlags(FLAG_BIT_PARTICLE_DISSOLVE_MASK))
                {
                    dissolve_mask_uv += cum_noise * _DissolveOffsetRotateDistort.w;
                }
            #endif
            half dissolveValue;
            
            // dissolveValue  = tex2D_TryLinearizeWithoutAlphaFX(_DissolveMap,dissolve_uv);
            dissolveValue  = SampleTexture2DWithWrapFlags(_DissolveMap,dissolve_uv,FLAG_BIT_WRAPMODE_DISSOLVE_MAP);

            UNITY_BRANCH
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_DISSOVLE_VORONOI))
            {
                // half2 noiseUV = abs(dissolve_uv-0.5);
                // half2 noiseUV = dissolve_uv;
                // // noiseMap_uv.x
                //
                // float halfUV = (0.5*_DissolveMap_ST.x +_DissolveMap_ST.z)*_DissolveVoronoi_Vec.x;
                // noiseUV.x = abs(dissolve_uv*_DissolveVoronoi_Vec.x - halfUV);
                // noiseUV.y *=_DissolveVoronoi_Vec.y;
                // return half4(noiseUV,0,1);
                
                
                // voroniForgraphfunc_half(dissolve_uv,_Time.y,1,dissolveValue);
                half cell;
                half noise1;
                // Unity_Voronoi_float(dissolve_uv,_Time.y*_DissolveVoronoi_Vec2.z,_DissolveVoronoi_Vec.xy,noise1,cell);
                noise1 = SimplexNoise(dissolve_noise_uv.xy,_Time.y*_DissolveVoronoi_Vec2.z);
                // return half4(noise1.rrr,1);
                half noise2;
                Unity_Voronoi_float(dissolve_noise_uv.zw,_Time.y*_DissolveVoronoi_Vec2.w,_DissolveVoronoi_Vec.zw,noise2,cell);
                // noise2 = SimplexNoise(dissolve_uv*_DissolveVoronoi_Vec.zw,_Time.y*_DissolveVoronoi_Vec2.w);
                half overlayVoroni;
          
                half dissolveSample = dissolveValue;
                Unity_Blend_HardLight_half(noise1,noise2,_DissolveVoronoi_Vec2.x,overlayVoroni);
                
                Unity_Blend_HardLight_half(overlayVoroni,dissolveSample,_DissolveVoronoi_Vec2.y,dissolveValue);

                
            }

            dissolveValue = SimpleSmoothstep(_Dissolve_Vec2.x,_Dissolve_Vec2.y,dissolveValue);

            #ifdef _DISSOLVE_EDITOR_TEST      //后续Test类的关键字要找机会排除
                return half4(dissolveValue.rrr,1);
            #endif
               

            half dissolveMaskValue = 0;
            UNITY_BRANCH
            if(CheckLocalFlags(FLAG_BIT_PARTICLE_DISSOLVE_MASK))
            {
                // dissolveMaskValue = tex2D_TryLinearizeWithoutAlphaFX(_DissolveMaskMap,dissolve_mask_uv);
                dissolveMaskValue = SampleTexture2DWithWrapFlags(_DissolveMaskMap,dissolve_mask_uv,FLAG_BIT_WRAPMODE_DISSOLVE_MASKMAP);
                _Dissolve.z += GetCustomData(_W9ParticleCustomDataFlag1,FLAGBIT_POS_1_CUSTOMDATA_DISSOLVE_MASK_INTENSITY,0,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
                dissolveMaskValue *= _Dissolve.z;
                dissolveValue = lerp(dissolveValue,1.01,dissolveMaskValue);
            }
            half originDissolve = dissolveValue;
            
            // UNITY_FLATTEN
            // if(CheckLocalFlags(FLAG_BIT_PARTICLE_CUSTOMDATA1Z_DISSOLVE_ON))
            // {
            //     // _Dissolve.x +=  _CustomData1Z;
            //     _Dissolve.x += input.VaryingsP_Custom1.z;
            // }
            _Dissolve.x += GetCustomData(_W9ParticleCustomDataFlag0,FLAGBIT_POS_0_CUSTOMDATA_DISSOLVE_INTENSITY,0,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
        
            // half3 dissolveRampColor = tex2D_TryLinearizeWithoutAlphaFX(_DissolveRampMap,half2(dissolveValue,0.5));
            dissolveValue = dissolveValue-_Dissolve.x;
            half dissolveValueBeforeSoftStep = dissolveValue;
            half softStep = _Dissolve.w;
            dissolveValue = SimpleSmoothstep(0,softStep,(dissolveValue));

            alpha  *= dissolveValue;
        // return half4(originDissolve.rrr,1);
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_DISSOVLE_USE_RAMP))
            {
                // half rampRange =1-(dissolveValueBeforeSoftStep - softStep);
                half rampRange =1-(originDissolve );
                // rampRange = SimpleSmoothstep(1- _Dissolve.y,1,rampRange);
                rampRange = rampRange * _DissolveRampMap_ST.x +_DissolveRampMap_ST.z;
                // half4 rampSample = tex2D_TryLinearizeWithoutAlphaFX(_DissolveRampMap,half2(rampRange,0.5));
                half4 rampSample = SampleTexture2DWithWrapFlags(_DissolveRampMap,half2(rampRange,0.5),FLAG_BIT_WRAPMODE_DISSOLVE_RAMPMAP);
                result = lerp(result,rampSample.rgb*_DissolveRampColor.rgb,rampSample.a*_DissolveRampColor.a);
            }
           
            half lineMask = 1 - smoothstep(0,softStep,alpha * (dissolveValueBeforeSoftStep - _Dissolve.y));
            result = lerp(result,_DissolveLineColor.rgb,lineMask*_DissolveLineColor.a);
            
            
        
        #endif
     
        //颜色渐变
        #ifdef _COLORMAPBLEND
            // half4 colorBlend = tex2D_TryLinearizeWithoutAlphaFX(_ColorBlendMap,colorBlendMap_uv);
            half4 colorBlend = SampleTexture2DWithWrapFlags(_ColorBlendMap,colorBlendMap_uv,FLAG_BIT_WRAPMODE_COLORBLENDMAP);
            colorBlend.rgb = colorBlend.rgb * _ColorBlendColor.rgb;
            result.rgb  = lerp(result.rgb,result.rgb * colorBlend.rgb,_ColorBlendColor.a);
        #endif

        //菲涅
        
            UNITY_BRANCH
            if(CheckLocalFlags(FLAG_BIT_PARTICLE_FRESNEL_ON))
            {
                half fresnelValue = 0;
                if(!ignoreFresnel())
                {
                    half3 fresnelDir = normalize(input.fresnelViewDir);
                    // half FresnelValue = Unity_FresnelEffect(input.normalWSAndAnimBlend.xyz, fresnelDir, _FrePower, _FresnelInOutSlider,_FresnelRotation.w);
                    // half4 cubeMap = half4(1,1,1,1);
                    // half3 FresnelColor = FresnelValue*cubeMap.rgb* _FresnelColor.rgb ;
                    // FresnelColor *= _FresnelColor.a;
                    // result +=  FresnelColor;
                    //
                    // alpha = saturate(alpha + FresnelValue * _FresnelColor.a*_FresnelSelfAlphaWeight) * _BaseColorIntensityForTimeline;

                    half dotNV = dot(fresnelDir,input.normalWSAndAnimBlend.xyz) ;
                    fresnelValue =  dotNV;

                    // UNITY_FLATTEN
                    // if(CheckLocalFlags(FLAG_BIT_PARTICLE_CUSTOMDATA2Z_FRESNELOFFSET))
                    // {
                    //     // _FresnelUnit.x += _CustomData2Z;
                    //     _FresnelUnit.x += input.VaryingsP_Custom2.z;
                    // }
                    _FresnelUnit.x += GetCustomData(_W9ParticleCustomDataFlag0,FLAGBIT_POS_0_CUSTOMDATA_FRESNEL_OFFSET,0,input.VaryingsP_Custom1,input.VaryingsP_Custom2);;
                            
                    fresnelValue = Mh2Remap(fresnelValue,_FresnelUnit.x,1,0,1);
                    UNITY_BRANCH
                    if(!CheckLocalFlags(FLAG_BIT_PARTICLE_FRESNEL_INVERT_ON))
                    {
                        fresnelValue = 1- fresnelValue;
                    }
                    // return half4(fresnelValue.rrr,1);
                    fresnelValue = pow(fresnelValue,_FresnelUnit.y);

                    half fresnelHardness = (1 - _FresnelUnit.w)*0.5;
                    
                    fresnelValue = smoothstep(0.5-fresnelHardness,0.5+fresnelHardness,fresnelValue);
                }
                //把旋转部分挪到顶点着色器以节省性能。
                // half3 viewDirWS =normalize(UnityWorldSpaceViewDir(input.positionWS.xyz));
                // half3 fresnelDir = Rotation(viewDirWS,_FresnelRotation.xyz);

                UNITY_BRANCH
                if(CheckLocalFlags(FLAG_BIT_PARTICLE_FRESNEL_COLOR_ON))
                {
                    
                    result = lerp(result,_FresnelColor.rgb,fresnelValue*_FresnelColor.a*_FresnelUnit.z);
                }

                UNITY_BRANCH
                if(CheckLocalFlags(FLAG_BIT_PARTICLE_FRESNEL_FADE_ON))
                {
                    fresnelValue *= alpha;
                    alpha = lerp(alpha,fresnelValue,_FresnelUnit.z);
                }
                // return  half4(fresnelValue.rrr,1);
                
            }
        
            UNITY_BRANCH
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_DEPTH_OUTLINE))
            {
                half depthOutlineValue = 1- SoftParticles(_DepthOutline_Vec.x, _DepthOutline_Vec.y, sceneZ,thisZ);
                depthOutlineValue *= _DepthOutline_Color.a;
                half3 originResult = result;
                //如何在一个pass里，完美的给出两个颜色的Fade。这个问题，没有想清楚。 
                result = lerp(result,_DepthOutline_Color.rgb,clamp(depthOutlineValue*3,0,1));
                result = lerp(result,originResult,clamp(alpha-depthOutlineValue,0,1));
                alpha = max(alpha,depthOutlineValue);
                //
                // depthOutlineValue = clamp(depthOutlineValue,0,1);
                //
                
            }
        
        
        
        //遮罩部分
        #if defined(_MASKMAP_ON)

            #if defined(_NOISEMAP)
                MaskMapuv += cum_noise * _MaskDistortion_intensity; //加入扭曲效果
            #endif
            // half4 maskmap1 = tex2D_TryLinearizeWithoutAlphaFX(_MaskMap, MaskMapuv);
            half4 maskmap1 = SampleTexture2DWithWrapFlags(_MaskMap, MaskMapuv,FLAG_BIT_WRAPMODE_MASKMAP);
        
            UNITY_BRANCH
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_MASK_MAP2))
            {
                half maskMap2 = SampleTexture2DWithWrapFlags(_MaskMap2, MaskMapuv2,FLAG_BIT_WRAPMODE_MASKMAP2).r;
                maskmap1 *= maskMap2;
                // return half4(maskMap2.rrr,1);
            }

            UNITY_BRANCH
            if(CheckLocalFlags1(FLAG_BIT_PARTICLE_1_MASK_MAP3))
            {
                half maskMap3 = SampleTexture2DWithWrapFlags(_MaskMap3, MaskMapuv3,FLAG_BIT_WRAPMODE_MASKMAP3).r;
                maskmap1 *= maskMap3;
            }

            maskmap1 = lerp(1,maskmap1,_MaskMapVec.x);
        
            maskmap1.rgb *= maskmap1.a;//预乘
        
            alpha *= maskmap1.r;  //mask边缘
        #endif
        

        // 受性能优化影响，没有渲染_CameraDepthTexture。需要解决这个问题后才能开启这些功能。|0821开启回来了。

        //可以看https://www.cyanilux.com/tutorials/depth/
        // float4 projectedPosition = input.positionNDC;
        // float thisZ1 = LinearEyeDepth(projectedPosition.z / projectedPosition.w, _ZBufferParams);

        
        UNITY_BRANCH
        if(CheckLocalFlags(FLAG_BIT_PARTICLE_DISTANCEFADE_ON))
        {
            half fade = DepthFactor(thisZ, _Fade.x, _Fade.y);
            alpha *= fade; 
        }
        
        
        #if defined(_SOFTPARTICLES_ON)
  
        half softAlpha = SoftParticles(SOFT_PARTICLE_NEAR_FADE, SOFT_PARTICLE_INV_FADE_DISTANCE, sceneZ,thisZ);
        alpha *= softAlpha;
        
        #endif
        
        
        

        
        UNITY_BRANCH
        if(CheckLocalFlags(FLAG_BIT_SATURABILITY_ON))
        {
            half3 resultWB = luminance(result);
            // if(CheckLocalFlags1(FLAG_BIT_PARTICLE_CUSTOMDATA1W_SATURATE))
            // {
            //     _Saturability = input.VaryingsP_Custom1.w;
            // }
            _Saturability = GetCustomData(_W9ParticleCustomDataFlag1,FLAGBIT_POS_1_CUSTOMDATA_SATURATE,_Saturability,input.VaryingsP_Custom1,input.VaryingsP_Custom2);
            result.rgb = lerp(resultWB.rgb, result.rgb, _Saturability);
        }
        

        //和粒子颜色信息运算。雨轩：乘顶点色。
        if(!CheckLocalFlags1(FLAG_BIT_PARTICLE_1_IGNORE_VERTEX_COLOR))
        {
            result *= input.color.rgb;
            alpha *= input.color.a;
        }
        // 程序额外的颜色
        result *= _ColorA.rgb;
        alpha *= _ColorA.a;
        // // alpha *= _ColorA * 0.8;


        #ifdef _DEPTH_DECAL
        alpha *= decalAlpha;
        #endif
        
    
        
        half3 beforeFogResult = result;
        result = MixFog(result,input.positionWS.w);
        // return half4(input.positionWS.www,1);
        result = lerp(beforeFogResult, result, _fogintensity);

        //古早代码
        // #ifdef UNITY_UI_CLIP_RECT
        // alpha *= UnityGet2DClipping(input.positionOS.xy, _ClipRect);
        // #endif
        //
        // #ifdef SOFT_UI_FRAME
        // alpha *= SoftUIFrame(_SoftUIFrameMask,LB_RT,input.clipPos);
        // #endif
        //
        // #ifdef SOFTMASK_EDITOR
        // alpha *= SoftMask(input.clipPos,input.positionWS);
        // #endif

        
        //     UNITY_BRANCH
        //     if(CheckLocalFlags(FLAG_BIT_PARTICLE_FRESNEL_FADE_ON))
        //     {
        //         alpha *= clamp(dot(input.normalWSAndAnimBlend.xyz * facing, input.viewDirWS) * _FresnelFadeDistance, 0, 1);
        //         alpha *= Mh2Remap(1-dot(input.normalWSAndAnimBlend.xyz * facing, input.viewDirWS),
        //             0, 1, 0.1, 1);
        //     }
       
        //     UNITY_BRANCH
        //     if(CheckLocalFlags(FLAG_BIT_PARTICLE_FRESNEL_COLOR_ON))
        //     {
        //         half NdotV = lerp(dot(input.normalWSAndAnimBlend.xyz * facing, input.viewDirWS),
        //             1-dot(input.normalWSAndAnimBlend.xyz * facing, input.viewDirWS), _FresnelUnit2.x);
        //         alpha *= Mh2Remap(NdotV,
        //             _FresnelUnit.x, _FresnelUnit.y, _FresnelUnit.z, _FresnelUnit.w);
        //     }
        
        
        // result = result.rgb * alpha * 2 - (result.rgb * alpha * 2) * 0.5; //zxz
        

        #ifndef _SCREEN_DISTORT_MODE
            result.rgb = result.rgb * alpha;
        #endif
        
            UNITY_FLATTEN
            if(CheckLocalFlags(FLAG_BIT_PARTICLE_LINEARTOGAMMA_ON))
            {
                result.rgb = LinearToGammaSpace(result.rgb);
            }
        

        alpha *= _AlphaAll;

        half4 color = half4(result, alpha);

        #ifdef _ALPHATEST_ON
        clip(color.a - _Cutoff);

        #endif

        // return half4(result,alpha);
        return color;
    }
    
#endif
