// UE4的环境高光BRDF
vec3 EnvBRDFApprox( vec3 SpecularColor, float Roughness, float NoV )
{
	// [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
	// Adaptation to fit our G term.
	const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
	const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
	vec4 r = Roughness * c0 + c1;
	float a004 = min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
	vec2 AB = vec2( -1.04, 1.04 ) * a004 + r.zw;

	// Anything less than 2% is physically impossible and is instead considered to be shadowing
	// Note: this is needed for the 'specular' show flag to work, since it uses a SpecularColor of 0
	AB.y *= saturate( 50.0 * SpecularColor.g );

	return SpecularColor * AB.x + AB.y;
}

vec3 GetLightingColor(vec3 diffuseColor, vec3 specularColor, float roughness, float perceptualRoughness, vec3 normalDirection, vec3 viewDirection, vec3 lightDirection, float NdotV
#ifdef USES_ANISOTROPY
    , float XdotV, float YdotV, float ax, float ay, vec3 X, vec3 Y
#endif
)
{
// necessary preprocess
    vec3 lightVec = normalize(lightDirection);
    vec3 halfDirection = normalize(viewDirection + lightDirection);

    float VdotH = clamp(dot(viewDirection, halfDirection), M_EPSILON, 1.0);
    float NdotH = clamp(dot(normalDirection, halfDirection), M_EPSILON, 1.0);
    float NdotL = clamp(dot(normalDirection, lightVec), M_EPSILON, 1.0);
    float LdotH = clamp(dot(lightVec, halfDirection), M_EPSILON, 1.0);

#ifdef USES_ANISOTROPY
    float VdotL = dot(viewDirection, lightVec);
    float InvLenH = rsqrt( 2.0 + 2.0 * VdotL );

    #if 0
        float XdotL = clamp(dot(X, lightVec), M_EPSILON, 1.0);
        float YdotL = clamp(dot(Y, lightVec), M_EPSILON, 1.0);
    #else
        float XdotL = dot(X, lightVec);
        float YdotL = dot(Y, lightVec);
    #endif

    // float XdotH = clamp(dot(X, halfDirection), M_EPSILON, 1.0);
    // float YdotH = clamp(dot(Y, halfDirection), M_EPSILON, 1.0);
    float XdotH = (XdotL + XdotV) * InvLenH;
    float YdotH = (YdotL + YdotV) * InvLenH;
#endif

// Diffuse
#if USE_DIFFUSE_LAMBERT_BRDF
    vec3 directDiffuse = diffuseColor * M_INV_PI;
#else
    vec3 directDiffuse = DisneyDiffuse(NdotV, NdotL, LdotH, perceptualRoughness) * diffuseColor * M_INV_PI;
#endif // USE_DIFFUSE_LAMBERT_BRDF

// 低画质关闭动态光的pbr高光计算
#if RENDER_QUALITY > RENDER_QUALITY_LOW
// VDF高光项
    #ifdef USES_ANISOTROPY
        roughness = max(roughness, 0.002);
        float V = Vis_SmithJointAniso(ax, ay, NdotV, NdotL, XdotV, XdotL, YdotV, YdotL);
        float D = D_GGXaniso(ax, ay, NdotH, XdotH, YdotH);
    #elif UNITY_BRDF_GGX
        roughness = max(roughness, 0.002);
        float V = SmithJointGGXVisibilityTerm(NdotL, NdotV, roughness);
        float D = GGXTerm(NdotH, roughness);
    #else
        float V = SmithBeckmannVisibilityTerm(NdotL, NdotV, roughness);
        float D = NDFBlinnPhongNormalizedTerm(NdotH, PerceptualRoughnessToSpecPower(perceptualRoughness));
    #endif
    vec3 F = FresnelTerm(specularColor, LdotH);
    
// Specular
    vec3 directSpecular = V * D * F;
#else
    vec3 directSpecular = vec3_splat(0.0);
#endif // RENDER_QUALITY > RENDER_QUALITY_LOW

// Diffuse + Specular, NdotL挪到最后乘了
    return (directDiffuse + directSpecular) * NdotL;
    // return (directSpecular) * NdotL;
}

vec3 GetSpecularColor(vec3 specularColor, float roughness, float perceptualRoughness, vec3 normalDirection, vec3 viewDirection, vec3 lightDirection, float NdotV)
{
// necessary preprocess
    vec3 lightVec = normalize(lightDirection);
    vec3 halfDirection = normalize(viewDirection + lightVec);

    //float NdotH = clamp(dot(normalDirection, halfDirection), M_EPSILON, 1.0);
    float NdotL = clamp(dot(normalDirection, lightVec), M_EPSILON, 1.0);
    //float LdotH = clamp(dot(lightVec, halfDirection), M_EPSILON, 1.0);


// 低画质关闭动态光的pbr高光计算
#if RENDER_QUALITY > RENDER_QUALITY_LOW
// VDF高光项
    #if UNITY_BRDF_GGX
        roughness = max(roughness, 0.002);
        float VD = SmithJointGGXVisibilityTerm(NdotL, NdotV, roughness) * NdotL; //V * NdotL
        NdotL = clamp(dot(normalDirection, halfDirection), M_EPSILON, 1.0); //NdotL = NdotH
        VD = GGXTerm(NdotL, roughness) * VD; //V*D*NdotL
    #else
        float VD = SmithBeckmannVisibilityTerm(NdotL, NdotV, roughness) * NdotL;
        NdotL = clamp(dot(normalDirection, halfDirection), M_EPSILON, 1.0); //NdotL = NdotH
        VD = NDFBlinnPhongNormalizedTerm(NdotL, PerceptualRoughnessToSpecPower(perceptualRoughness)) * VD;
    #endif
    NdotL = clamp(dot(lightVec, halfDirection), M_EPSILON, 1.0);//NdotL = LdotH
    specularColor = FresnelTerm(specularColor, NdotL); //specularColor = F
    
// Specular
    specularColor = VD * specularColor;
#else
    specularColor = vec3_splat(0.0);
#endif // RENDER_QUALITY > RENDER_QUALITY_LOW

    return specularColor;
}

/**
 * @brief 从Unity改一版的的迪士尼BRDF
          注意：为了节省计算量，目前只对主光做各向异性
 * 之所以不直接用Unity源码是因为计算灯光衰减、间接光照这部分每个引擎都不太一样
 * 综上来说，BRDF部分还是Unity代码，只不过gi部分适配了Urho3D
 * @param diffuseColor              - 已经经过能量守恒的漫反色颜色（和高光做了比例）
 * @param spefularColor             - 高光颜色
 * @param oneMinusReflectivity      - 1.0 - 反色率
 * @param gloss                     - 光滑度（perceptualRoughness => 粗糙度比例（等价于1 - 光滑度，光滑度为贴图输入或者shader参数））
 * @param normalDirection           - 法线向量
 * @param viewDirection             - 物体到相机的向量
 * @param shadow                    - 阴影衰减
 * @param occlusion                 - 材质传入的环境光遮蔽
 */
vec3 Disney_BRDF(vec3 diffuseColor, vec3 specularColor, float oneMinusReflectivity, float gloss, hvec3 worldPos, vec3 normalDirection, vec3 viewDirection, vec3 shadow, float occlusion
#ifdef USES_ANISOTROPY
    , float anisotropy
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
#ifdef CLUSTER_VS
, vec4 vecIrrR, vec4 vecIrrG, vec4 mrpIntensity, vec4 mrpDir
#endif
)
{
    vec3 finalColor = vec3_splat(0.0);

// roughness
    float perceptualRoughness = 1.0 - gloss;
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    
    float NdotV = abs(dot(normalDirection, viewDirection));

#ifdef USES_ANISOTROPY
    float ax = 0;
    float ay = 0;
    GetAnisotropicRoughness(perceptualRoughness, anisotropy, ax, ay);

    // X: Tangent => vTangent.xyz
    // Y: Bnormal => vTexCoord.zw vTangent.w
    vec3 X = vTangent.xyz;
    vec3 Y = vec3(vTexCoord.zw, vTangent.w);

    float XdotV = dot(X, viewDirection);
    float YdotV = dot(Y, viewDirection);
#endif

#if defined(PERPIXEL)
    hvec3 lightColor;
    vec3 lightDirection;
    hfloat attenuation;
    hvec3 lightingColor;

#if defined(DIRLIGHT) || !defined(CLUSTER)
// GI => light color, light dir, light attenuation
    lightColor = GI_GetLightColor();
    attenuation = GI_GetAttenAndLightDir(worldPos, lightDirection);

    lightingColor = GetLightingColor(diffuseColor, specularColor, roughness, perceptualRoughness, normalDirection, viewDirection, lightDirection, NdotV
    #ifdef USES_ANISOTROPY
        , XdotV, YdotV, ax, ay, X, Y
    #endif
    );
    finalColor += lightingColor * lightColor * (attenuation * shadow);
#endif // DIRLIGHT || !CLUSTER

#if defined(LIGHTMAP)

#if defined(SPEED_GRASS)
    vec4 lightMapColor = GetLambertGrassLightMapColor(vLightMapUV.xy, normalDirection, worldPos);
    finalColor += diffuseColor * lightMapColor.rgb;
#else// SPEED_GRASS

#if RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)
    vec3 lightMapDir;
    vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normalDirection, lightMapDir);
    finalColor += lightMapColor.rgb * (diffuseColor + M_PI * GetSpecularColor(specularColor, roughness, perceptualRoughness, normalDirection, viewDirection, lightMapDir, NdotV));
#else// RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)
    vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normalDirection);
    finalColor += diffuseColor * lightMapColor.rgb;
#endif// RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)

#endif// SPEED_GRASS

#endif// LIGHTMAP

#if defined(CLUSTER)
// Cluster render for pointlight

#ifdef CLUSTER_VS
    if (mrpIntensity.w > 0.0) {
        vec3 Ndote = vec3(dot(normalDirection, vecIrrR.rgb), dot(normalDirection, vecIrrG.rgb), dot(normalDirection, vec3(vecIrrR.w, vecIrrG.w, mrpDir.w)));
        finalColor += Ndote * diffuseColor * M_INV_PI;
        finalColor += mrpIntensity.xyz * GetSpecularColor(specularColor, roughness, perceptualRoughness, normalDirection, viewDirection, mrpDir.xyz, NdotV);
    }
#else
    #ifdef DEFERRED_CLUSTER
        uint cluster = getDeferredClusterIndex(gl_FragCoord.xy, sceneDepth);
    #else
        // 这里从gl_FragCoord减去viewport的起点，得到viewport坐标
        hvec4 realCoord = getRealCoord(gl_FragCoord);
        uint cluster = getClusterIndex(realCoord);
    #endif
    LightGrid grid = getLightGrid(cluster);
    for (uint i = 0u; i < grid.pointLights; ++i)
    {
        uint lightIndex = GetGridLightIndex(grid.offset, i);
#ifdef CLUSTER_SPOTLIGHT
        SpotLight light = GetSpotLight(lightIndex);
#else
        PointLight light = GetPointLight(lightIndex);
#endif

    // GI => light color, light dir, light attenuation
        lightColor = light.intensity;
        attenuation = GI_PointLight_GetAttenAndLightDir(worldPos, light.position, light.range, lightDirection);

#ifdef CLUSTER_SPOTLIGHT
        attenuation *= GetLightDirectionFalloff(lightDirection, light.direction, light.cosOuterCone, light.invCosConeDiff);
#endif
        lightingColor = GetLightingColor(diffuseColor, specularColor, roughness, perceptualRoughness, normalDirection, viewDirection, lightDirection, NdotV
        #ifdef USES_ANISOTROPY
            , XdotV, YdotV, ax, ay, X, Y
        #endif
        );

        finalColor += lightingColor * lightColor * attenuation;
    }

#ifdef NONPUNCTUAL_LIGHTING
    for (uint i = 0u; i < grid.nonPunctualPointLights; ++i)
    {
        uint lightIndex = GetGridLightIndex(grid.nonPunctualPointLightsOffset, i);
        NonPunctualPointLight light = GetNonPunctualPointLight(lightIndex);

        //capsule light
        if (light.length > 0.0)
        {
            finalColor += GetCapsuleLighting(light, worldPos, normalDirection, viewDirection, diffuseColor, specularColor, roughness, perceptualRoughness);
        }
        else if (light.packRadius > 0.0)
        {
            finalColor += GetSphereLighting(light, worldPos, normalDirection, viewDirection, diffuseColor, specularColor, roughness, perceptualRoughness);
        }
    }
#endif

#endif //CLUSTER_VS
#endif // CLUSTER
#endif // PERPIXEL

#if defined(AMBIENT)
    // AO
    #if defined(AO) && !defined(CLOSE_AO)
        #if defined(DEFERRED)
            occlusion = occlusion * texture2D(sAOMap, vScreenPos).r;
        #else
            #if defined(SSAO)
                // 这里有一个trick，hlslcc翻译的时候，gl_FragCoord是当作dx标准，所以gl_FragCoord.w并不是gl文档描述的1/w，它就是w
                // https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/gl_FragCoord.xhtml
                // gl_FragCoord is an input variable that contains the window relative coordinate (x, y, z, 1/w) values for the fragment
                #if !BGFX_SHADER_LANGUAGE_GLSL
                    occlusion = occlusion * texture2D(sAOMap, vAOUV / gl_FragCoord.w * 0.5 + 0.5).r;
                #else
                    occlusion = occlusion * texture2D(sAOMap, vAOUV * gl_FragCoord.w * 0.5 + 0.5).r;
                #endif
            #else
                occlusion = occlusion * texture2D(sAOMap, vAOUV).r;
            #endif
        #endif
    #endif

// Indirect Diffuse, Indirect Specular
    vec3 indirectDiffuse;
    vec3 indirectSpecular;
    GI_Indirect(normalDirection, viewDirection, perceptualRoughness, occlusion, indirectDiffuse, indirectSpecular);

// Indirect Diffuse
    indirectDiffuse *= diffuseColor;

    #if UNITY_ENV_BRDF
    // Indirect Specular (Unity3D EnvBRDFApprox)
        float surfaceReduction = 1.0 / (roughness * roughness + 1.0);
        // float grazingTerm = saturate(gloss + (1.0 - oneMinusReflectivity));
        // 菲尼尔边缘颜色过大问题：增加参数sce_EnvFresnelEdgeStrength限制边缘菲尼的最大强度
        float grazingTerm = clamp(gloss + (1.0 - oneMinusReflectivity), 0.0, sce_EnvFresnelEdgeStrength);
        indirectSpecular = indirectSpecular * surfaceReduction * FresnelLerp(specularColor, vec3_splat(grazingTerm), NdotV);
    #else
    // Indirect Specular (UE4 EnvBRDFApprox)
        indirectSpecular = indirectSpecular * EnvBRDFApprox(specularColor, perceptualRoughness, NdotV);
    #endif // UNITY_ENV_BRDF

    finalColor += indirectDiffuse + indirectSpecular;
#endif // AMBIENT

    return finalColor;
}

#ifdef SPLIT_LIGHTING
/**
 * @brief Disney BRDF Split Output Version
 * Separates scene lighting from environment specular for SSR reflection hierarchy.
 * Used by deferred lighting pass when SPLIT_LIGHTING is defined.
 *
 * @param outSceneLighting Output: Scene lighting (direct_diffuse + direct_specular + IBL_diffuse)
 * @param outEnvSpecular   Output: Environment specular only (IBL specular, replaced by SSR)
 */
void Disney_BRDF_Split(
    vec3 diffuseColor, vec3 specularColor, float oneMinusReflectivity, float gloss,
    hvec3 worldPos, vec3 normalDirection, vec3 viewDirection, vec3 shadow, float occlusion
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
    outSceneLighting = vec3_splat(0.0);
    outEnvSpecular = vec3_splat(0.0);

// roughness
    float perceptualRoughness = 1.0 - gloss;
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    float NdotV = abs(dot(normalDirection, viewDirection));

#ifdef USES_ANISOTROPY
    float ax = 0;
    float ay = 0;
    GetAnisotropicRoughness(perceptualRoughness, anisotropy, ax, ay);
    vec3 X = vTangent.xyz;
    vec3 Y = vec3(vTexCoord.zw, vTangent.w);
    float XdotV = dot(X, viewDirection);
    float YdotV = dot(Y, viewDirection);
#endif

#if defined(PERPIXEL)
    hvec3 lightColor;
    vec3 lightDirection;
    hfloat attenuation;

#if defined(DIRLIGHT) || !defined(CLUSTER)
    lightColor = GI_GetLightColor();
    attenuation = GI_GetAttenAndLightDir(worldPos, lightDirection);

    // Calculate direct lighting with separated diffuse/specular
    vec3 lightVec = normalize(lightDirection);
    vec3 halfDirection = normalize(viewDirection + lightDirection);
    float VdotH = clamp(dot(viewDirection, halfDirection), M_EPSILON, 1.0);
    float NdotH = clamp(dot(normalDirection, halfDirection), M_EPSILON, 1.0);
    float NdotL = clamp(dot(normalDirection, lightVec), M_EPSILON, 1.0);
    float LdotH = clamp(dot(lightVec, halfDirection), M_EPSILON, 1.0);

#ifdef USES_ANISOTROPY
    float VdotL = dot(viewDirection, lightVec);
    float InvLenH = rsqrt(2.0 + 2.0 * VdotL);
    float XdotL = dot(X, lightVec);
    float YdotL = dot(Y, lightVec);
    float XdotH = (XdotL + XdotV) * InvLenH;
    float YdotH = (YdotL + YdotV) * InvLenH;
#endif

    // Direct Diffuse
#if USE_DIFFUSE_LAMBERT_BRDF
    vec3 directDiffuse = diffuseColor * M_INV_PI;
#else
    vec3 directDiffuse = DisneyDiffuse(NdotV, NdotL, LdotH, perceptualRoughness) * diffuseColor * M_INV_PI;
#endif

    // Direct Specular
#if RENDER_QUALITY > RENDER_QUALITY_LOW
    #ifdef USES_ANISOTROPY
        roughness = max(roughness, 0.002);
        float V = Vis_SmithJointAniso(ax, ay, NdotV, NdotL, XdotV, XdotL, YdotV, YdotL);
        float D = D_GGXaniso(ax, ay, NdotH, XdotH, YdotH);
    #elif UNITY_BRDF_GGX
        roughness = max(roughness, 0.002);
        float V = SmithJointGGXVisibilityTerm(NdotL, NdotV, roughness);
        float D = GGXTerm(NdotH, roughness);
    #else
        float V = SmithBeckmannVisibilityTerm(NdotL, NdotV, roughness);
        float D = NDFBlinnPhongNormalizedTerm(NdotH, PerceptualRoughnessToSpecPower(perceptualRoughness));
    #endif
    vec3 F = FresnelTerm(specularColor, LdotH);
    vec3 directSpecular = V * D * F;
#else
    vec3 directSpecular = vec3_splat(0.0);
#endif

    vec3 lightAtten = lightColor * (attenuation * shadow) * NdotL;
    outSceneLighting += (directDiffuse + directSpecular) * lightAtten;
#endif // DIRLIGHT || !CLUSTER

#if defined(LIGHTMAP)
    // Lightmap contribution
#if defined(SPEED_GRASS)
    vec4 lightMapColor = GetLambertGrassLightMapColor(vLightMapUV.xy, normalDirection, worldPos);
    outSceneLighting += diffuseColor * lightMapColor.rgb;
#else
#if RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)
    vec3 lightMapDir;
    vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normalDirection, lightMapDir);
    outSceneLighting += lightMapColor.rgb * diffuseColor;
    outSceneLighting += lightMapColor.rgb * M_PI * GetSpecularColor(specularColor, roughness, perceptualRoughness, normalDirection, viewDirection, lightMapDir, NdotV);
#else
    vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normalDirection);
    outSceneLighting += diffuseColor * lightMapColor.rgb;
#endif
#endif
#endif // LIGHTMAP

#if defined(CLUSTER)
    // Cluster lights
#ifdef CLUSTER_VS
    if (mrpIntensity.w > 0.0) {
        vec3 Ndote = vec3(dot(normalDirection, vecIrrR.rgb), dot(normalDirection, vecIrrG.rgb), dot(normalDirection, vec3(vecIrrR.w, vecIrrG.w, mrpDir.w)));
        outSceneLighting += Ndote * diffuseColor * M_INV_PI;
        // Cluster VS specular is direct lighting → goes to outSceneLighting
        outSceneLighting += mrpIntensity.xyz * GetSpecularColor(specularColor, roughness, perceptualRoughness, normalDirection, viewDirection, mrpDir.xyz, NdotV);
    }
#else
    #ifdef DEFERRED_CLUSTER
        uint cluster = getDeferredClusterIndex(gl_FragCoord.xy, sceneDepth);
    #else
        hvec4 realCoord = getRealCoord(gl_FragCoord);
        uint cluster = getClusterIndex(realCoord);
    #endif
    LightGrid grid = getLightGrid(cluster);
    for (uint i = 0u; i < grid.pointLights; ++i)
    {
        uint lightIndex = GetGridLightIndex(grid.offset, i);
#ifdef CLUSTER_SPOTLIGHT
        SpotLight light = GetSpotLight(lightIndex);
#else
        PointLight light = GetPointLight(lightIndex);
#endif
        lightColor = light.intensity;
        attenuation = GI_PointLight_GetAttenAndLightDir(worldPos, light.position, light.range, lightDirection);

#ifdef CLUSTER_SPOTLIGHT
        attenuation *= GetLightDirectionFalloff(lightDirection, light.direction, light.cosOuterCone, light.invCosConeDiff);
#endif
        vec3 lightingColor = GetLightingColor(diffuseColor, specularColor, roughness, perceptualRoughness, normalDirection, viewDirection, lightDirection, NdotV
        #ifdef USES_ANISOTROPY
            , XdotV, YdotV, ax, ay, X, Y
        #endif
        );
        // Cluster lights are direct lighting → all goes to outSceneLighting
        vec3 clusterContrib = lightingColor * lightColor * attenuation;
        outSceneLighting += clusterContrib;
    }

#ifdef NONPUNCTUAL_LIGHTING
    for (uint i = 0u; i < grid.nonPunctualPointLights; ++i)
    {
        uint lightIndex = GetGridLightIndex(grid.nonPunctualPointLightsOffset, i);
        NonPunctualPointLight light = GetNonPunctualPointLight(lightIndex);

        vec3 nonPunctualContrib = vec3_splat(0.0);
        if (light.length > 0.0)
        {
            nonPunctualContrib = GetCapsuleLighting(light, worldPos, normalDirection, viewDirection, diffuseColor, specularColor, roughness, perceptualRoughness);
        }
        else if (light.packRadius > 0.0)
        {
            nonPunctualContrib = GetSphereLighting(light, worldPos, normalDirection, viewDirection, diffuseColor, specularColor, roughness, perceptualRoughness);
        }
        // Non-punctual lights are direct lighting → all goes to outSceneLighting
        outSceneLighting += nonPunctualContrib;
    }
#endif
#endif // !CLUSTER_VS
#endif // CLUSTER
#endif // PERPIXEL

#if defined(AMBIENT)
    // AO
    #if defined(AO) && !defined(CLOSE_AO)
        #if defined(DEFERRED)
            occlusion = occlusion * texture2D(sAOMap, vScreenPos).r;
        #else
            #if defined(SSAO)
                #if !BGFX_SHADER_LANGUAGE_GLSL
                    occlusion = occlusion * texture2D(sAOMap, vAOUV / gl_FragCoord.w * 0.5 + 0.5).r;
                #else
                    occlusion = occlusion * texture2D(sAOMap, vAOUV * gl_FragCoord.w * 0.5 + 0.5).r;
                #endif
            #else
                occlusion = occlusion * texture2D(sAOMap, vAOUV).r;
            #endif
        #endif
    #endif

    // Indirect Diffuse, Indirect Specular
    vec3 indirectDiffuse;
    vec3 indirectSpecular;
    GI_Indirect(normalDirection, viewDirection, perceptualRoughness, occlusion, indirectDiffuse, indirectSpecular);

    // Indirect Diffuse
    indirectDiffuse *= diffuseColor;

    #if UNITY_ENV_BRDF
        float surfaceReduction = 1.0 / (roughness * roughness + 1.0);
        float grazingTerm = clamp(gloss + (1.0 - oneMinusReflectivity), 0.0, sce_EnvFresnelEdgeStrength);
        indirectSpecular = indirectSpecular * surfaceReduction * FresnelLerp(specularColor, vec3_splat(grazingTerm), NdotV);
    #else
        indirectSpecular = indirectSpecular * EnvBRDFApprox(specularColor, perceptualRoughness, NdotV);
    #endif

    outSceneLighting += indirectDiffuse;
    outEnvSpecular += indirectSpecular;  // This is the IBL Specular, serves as SSR fallback
#endif // AMBIENT
}
#endif // SPLIT_LIGHTING
