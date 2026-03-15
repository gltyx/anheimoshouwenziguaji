vec3 SpecularPBR(vec3 diffuseColor, vec3 specularColor, float gloss, hvec3 worldPos, vec3 normalDirection, vec3 viewDirection, vec3 shadow, float occlusion
#ifdef USES_ANISOTROPY
    , float anisotropy
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
)
{
    float oneMinusReflectivity;
    diffuseColor = EnergyConservationBetweenDiffuseAndSpecular(diffuseColor, specularColor, oneMinusReflectivity);
    return Standard_BRDF(diffuseColor, specularColor, oneMinusReflectivity, gloss, worldPos, normalDirection, viewDirection, shadow, occlusion
#ifdef USES_ANISOTROPY
    , anisotropy
#endif
#ifdef DEFERRED_CLUSTER
    , sceneDepth
#endif
#ifdef CLUSTER_VS
    , vVecIrrR, vVecIrrG, vMrp, vMrpDir
#endif
    );
}
