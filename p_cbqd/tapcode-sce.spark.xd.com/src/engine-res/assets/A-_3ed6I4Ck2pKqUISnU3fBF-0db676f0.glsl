#include "brdf.sh"

vec3 CookTorrance_BRDF(vec3 diffuseColor, vec3 specularColor, float oneMinusReflectivity, float gloss, vec3 normalDirection, vec3 viewDirection, float shadow)
{
// GI => light color, light dir, light attenuation
    vec3 lightColor = GI_GetLightColor();
    vec3 lightDirection;
    float attenuation = GI_GetAttenAndLightDir(normalDirection, vWorldPos.xyz, lightDirection);
    vec3 attenColor = attenuation * lightColor * shadow;

// roughness
    float perceptualRoughness = 1.0 - gloss;
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

// necessary preprocess
    vec3 lightVec = normalize(lightDirection);
    vec3 halfDirection = normalize(viewDirection + lightDirection);

    float VdotH = clamp(dot(viewDirection, halfDirection), M_EPSILON, 1.0);
    float NdotH = clamp(dot(normalDirection, halfDirection), M_EPSILON, 1.0);
    float NdotL = clamp(dot(normalDirection, lightVec), M_EPSILON, 1.0);
    float LdotH = clamp(dot(lightVec, halfDirection), M_EPSILON, 1.0);
    float NdotV = abs(dot(normalDirection, viewDirection)) + 1e-5;

// Indirect Diffuse, Indirect Specular
    vec3 indirectDiffuse;
    vec3 indirectSpecular;
    GI_Indirect(normalDirection, viewDirection, perceptualRoughness, 1.0, indirectDiffuse, indirectSpecular);

// Diffuse
    vec3 directDiffuse = Diffuse(diffuseColor, roughness, NdotV, NdotL, VdotH);

// VDF高光项
    vec3 fresnelTerm = Fresnel(specularColor, VdotH, LdotH);
    float distTerm = Distribution(NdotH, roughness);
    float visTerm = Visibility(NdotL, NdotV, roughness);

// Specular
    vec3 directSpecular = fresnelTerm * distTerm * visTerm  * M_INV_PI;

// Diffuse + Specular
    vec3 finalColor = (directDiffuse + directSpecular) * attenColor * M_INV_PI + indirectDiffuse + indirectSpecular;

    return finalColor;
}
