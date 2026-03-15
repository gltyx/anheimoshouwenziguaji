vec3 MetallicPBR(vec3 diffuseColor, float metallic, float specular, float roughness, hvec3 worldPos, vec3 normalDirection, vec3 viewDirection, vec3 shadow, float occlusion
#ifdef USES_ANISOTROPY
    , float anisotropy
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
)
{
#ifdef WEATHER_EFFECT
    WeatherEffect(diffuseColor, roughness, metallic, normalDirection);
#endif

    roughness = mix(roughness, cGlobalRoughness, cGlobalRoughnessOn);

    float oneMinusReflectivity;
    vec3 specularColor = vec3(specular, specular, specular);
    diffuseColor = DiffuseAndSpecularFromMetallicEx(diffuseColor, metallic, specularColor, oneMinusReflectivity);
    return Standard_BRDF(diffuseColor, specularColor, oneMinusReflectivity, 1.0 - roughness, worldPos, normalDirection, viewDirection, shadow, occlusion
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

#ifdef SPLIT_LIGHTING
/**
 * @brief Metallic PBR Split Output Version
 * Separates scene lighting from environment specular for SSR reflection hierarchy.
 *
 * @param outSceneLighting Output: Scene lighting (direct_diffuse + direct_specular + IBL_diffuse)
 * @param outEnvSpecular   Output: Environment specular only (IBL specular, replaced by SSR)
 */
void MetallicPBR_Split(
    vec3 diffuseColor, float metallic, float specular, float roughness, hvec3 worldPos,
    vec3 normalDirection, vec3 viewDirection, vec3 shadow, float occlusion
#ifdef USES_ANISOTROPY
    , float anisotropy
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
#ifdef CLUSTER_VS
    , vec4 vecIrrR, vec4 vecIrrG, vec4 mrpIntensity, vec4 mrpDir
#endif
    , out vec3 outSceneLighting
    , out vec3 outEnvSpecular
)
{
#ifdef WEATHER_EFFECT
    WeatherEffect(diffuseColor, roughness, metallic, normalDirection);
#endif

    roughness = mix(roughness, cGlobalRoughness, cGlobalRoughnessOn);

    float oneMinusReflectivity;
    vec3 specularColor = vec3(specular, specular, specular);
    diffuseColor = DiffuseAndSpecularFromMetallicEx(diffuseColor, metallic, specularColor, oneMinusReflectivity);

    Standard_BRDF_Split(diffuseColor, specularColor, oneMinusReflectivity, 1.0 - roughness, worldPos,
        normalDirection, viewDirection, shadow, occlusion
#ifdef USES_ANISOTROPY
        , anisotropy
#endif
#ifdef DEFERRED_CLUSTER
        , sceneDepth
#endif
#ifdef CLUSTER_VS
        , vecIrrR, vecIrrG, mrpIntensity, mrpDir
#endif
        , outSceneLighting
        , outEnvSpecular
    );
}
#endif // SPLIT_LIGHTING