#ifndef SIX_WAY_SMOKE_LIT_HLSL
#define SIX_WAY_SMOKE_LIT_HLSL
//这部分尽量借鉴 UnityEditor.VFX.HDRP.SixWaySmokeLit

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "ParticlesUnlitInputNew.hlsl"


// Generated from UnityEditor.VFX.HDRP.SixWaySmokeLit+BSDFData
// PackingRules = Exact
struct BSDFData
{
    uint materialFeatures;
    float absorptionRange;
    real4 diffuseColor;
    real3 fresnel0;
    real ambientOcclusion;
    float3 normalWS;
    float4 tangentWS;
    real3 geomNormalWS;
    real3 rigRTBk;
    real3 rigLBtF;
    real3 bakeDiffuseLighting0;//rigRTBk.x
    real3 bakeDiffuseLighting1;//rigRTBk.y
    real3 bakeDiffuseLighting2;// bsdfData.tangentWS.w > 0.0f ? rigRTBk.z : rigLBtF.z
    real3 backBakeDiffuseLighting0;//rigLBtF.x
    real3 backBakeDiffuseLighting1;//rigLBtF.y
    real3 backBakeDiffuseLighting2;// bsdfData.tangentWS.w > 0.0f ? rigLBtF.z : rigRTBk.z

    //-----NBShaders-----
    real3 emission;
    real emissionInput;//NegativeTex.a
    real alpha;//PositiveTex.a
    
};


float3 GetTransmissionWithAbsorption(float transmission, float4 absorptionColor, float absorptionRange)
{
    // absorptionColor.rgb = max(VFX_EPSILON, absorptionColor.rgb);//这只是一个限定值
    #if VFX_SIX_WAY_ABSORPTION
    #if VFX_BLENDMODE_PREMULTIPLY
    transmission /= (absorptionColor.a > 0) ? absorptionColor.a : 1.0f  ;
    #endif

    // Empirical value used to parametrize absorption from color
    const float absorptionStrength = 0.2f;
    float3 densityScales = 1.0f + log2(absorptionColor.rgb) / log2(absorptionStrength);
    // Recompute transmission based on density scaling
    float3 outTransmission = pow(saturate(transmission / absorptionRange), densityScales) * absorptionRange;

    #if VFX_BLENDMODE_PREMULTIPLY
    outTransmission *= (absorptionColor.a > 0) ? absorptionColor.a : 1.0f  ;
    #endif

    return min(absorptionRange, outTransmission); // clamp values out of range
    #else
    return transmission.xxx * absorptionColor.rgb; // simple multiply
    #endif
}

void ModifyBakedDiffuseLighting(BSDFData bsdfData, inout float3 bakeDiffuseLighting)
{
    bakeDiffuseLighting = 0;

    // Scale to be energy conserving: Total energy = 4*pi; divided by 6 directions
    float scale = 4.0f * PI / 6.0f;

    float3 frontBakeDiffuseLighting = bsdfData.tangentWS.w > 0.0f ? bsdfData.bakeDiffuseLighting2 : bsdfData.backBakeDiffuseLighting2;
    float3 backBakeDiffuseLighting = bsdfData.tangentWS.w > 0.0f ? bsdfData.backBakeDiffuseLighting2 : bsdfData.bakeDiffuseLighting2;

    float3x3 bakeDiffuseLightingMat;
    bakeDiffuseLightingMat[0] = bsdfData.bakeDiffuseLighting0;
    bakeDiffuseLightingMat[1] = bsdfData.bakeDiffuseLighting1;
    bakeDiffuseLightingMat[2] = frontBakeDiffuseLighting;
    bakeDiffuseLighting += GetTransmissionWithAbsorption(bsdfData.rigRTBk.x, bsdfData.diffuseColor, bsdfData.absorptionRange) * bakeDiffuseLightingMat[0];
    bakeDiffuseLighting += GetTransmissionWithAbsorption(bsdfData.rigRTBk.y, bsdfData.diffuseColor, bsdfData.absorptionRange) * bakeDiffuseLightingMat[1];
    bakeDiffuseLighting += GetTransmissionWithAbsorption(bsdfData.rigRTBk.z, bsdfData.diffuseColor, bsdfData.absorptionRange) * bakeDiffuseLightingMat[2];

    bakeDiffuseLightingMat[0] = bsdfData.backBakeDiffuseLighting0;
    bakeDiffuseLightingMat[1] = bsdfData.backBakeDiffuseLighting1;
    bakeDiffuseLightingMat[2] = backBakeDiffuseLighting;
    bakeDiffuseLighting += GetTransmissionWithAbsorption(bsdfData.rigLBtF.x, bsdfData.diffuseColor, bsdfData.absorptionRange) * bakeDiffuseLightingMat[0];
    bakeDiffuseLighting += GetTransmissionWithAbsorption(bsdfData.rigLBtF.y, bsdfData.diffuseColor, bsdfData.absorptionRange) * bakeDiffuseLightingMat[1];
    bakeDiffuseLighting += GetTransmissionWithAbsorption(bsdfData.rigLBtF.z, bsdfData.diffuseColor, bsdfData.absorptionRange) * bakeDiffuseLightingMat[2];

    bakeDiffuseLighting *= scale;
    
}

//世界空间到切线空间方向转换
float3 TransformToLocalFrame(float3 L, BSDFData bsdfData)
{
    float3 zVec = -bsdfData.normalWS;
    float3 xVec = bsdfData.tangentWS.xyz;
    float3 yVec = -cross(zVec, xVec) * bsdfData.tangentWS.w;//原代码没有负值，实际测试需要负值
    float3x3 tbn = float3x3(xVec, yVec, zVec);
    return mul(tbn, L);
}

CBSDF EvaluateBSDF(float3 L, BSDFData bsdfData)
{
    CBSDF cbsdf;
    ZERO_INITIALIZE(CBSDF, cbsdf);

    float3 dir = TransformToLocalFrame(L, bsdfData);
    float3 weights = dir >= 0 ? bsdfData.rigRTBk.xyz : bsdfData.rigLBtF.xyz;
    float3 sqrDir = dir*dir;

    cbsdf.diffR = GetTransmissionWithAbsorption(dot(sqrDir, weights), bsdfData.diffuseColor, bsdfData.absorptionRange);

    return cbsdf;
}




//---------NBShaderUtility-----------

//UseInVerTex
void GetSixWayBakeDiffuseLight(real3 normalWS,real3 tangentWS,real3 biTangentWS,
    inout  half3 bakeDiffuseLighting0,inout half3 bakeDiffuseLighting1,inout half3 bakeDiffuseLighting2,
    inout half3 backBakeDiffuseLighting0,inout half3 backBakeDiffuseLighting1,inout half3 backBakeDiffuseLighting2)
{
    bakeDiffuseLighting0 = SampleSHVertex(tangentWS);
    bakeDiffuseLighting1 = SampleSHVertex(biTangentWS);
    bakeDiffuseLighting2 = SampleSHVertex(-normalWS);
    backBakeDiffuseLighting0 = SampleSHVertex(-tangentWS);
    backBakeDiffuseLighting1 = SampleSHVertex(-biTangentWS);
    backBakeDiffuseLighting2 = SampleSHVertex(normalWS);
}

LightingData CreateSixWayLightingData(InputData inputData, half3 emission)
{
    LightingData lightingData;

    lightingData.giColor = inputData.bakedGI;
    lightingData.emissionColor = emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}

void  GetSixWayEmission(inout  BSDFData bsdfData,Texture2D rampMap,half4 emissionColor)
{
    half3 emission = rampMap.Sample(sampler_linear_clamp,half2(bsdfData.emissionInput,0.5));
    emission *= emissionColor;
    emission *= emissionColor.a;
    bsdfData.emission = emission;
}

half3 LightingSixWay(Light light,InputData inputData, BSDFData bsdfData)
{
     return EvaluateBSDF(light.direction,bsdfData).diffR*light.color;
}


//光照流程--->原型为UniversalFragmentBlinnPhong
half4 UniversalFragmentSixWay(InputData inputData,BSDFData bsdfData)
{
    // #if defined(DEBUG_DISPLAY)
    // half4 debugColor;
    //
    // if (CanDebugOverrideOutputColor(inputData, surfaceData, debugColor))
    // {
    //     return debugColor;
    // }
    // #endif

    uint meshRenderingLayers = GetMeshRenderingLayer();
    half4 shadowMask = CalculateShadowMask(inputData);
    // AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    AmbientOcclusionFactor aoFactor;
    aoFactor.directAmbientOcclusion = 1;
    aoFactor.indirectAmbientOcclusion = 1;
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, aoFactor);

    // inputData.bakedGI *= surfaceData.albedo;

    // LightingData lightingData = CreateLightingData(inputData, surfaceData);
    LightingData lightingData = CreateSixWayLightingData(inputData,bsdfData.emission);
    
#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
        lightingData.mainLightColor += LightingSixWay(mainLight, inputData, bsdfData);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += LightingSixWay(light, inputData, bsdfData);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += LightingSixWay(light, inputData, bsdfData);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * surfaceData.albedo;
    #endif

    return CalculateFinalColor(lightingData, bsdfData.alpha);
}
#endif
