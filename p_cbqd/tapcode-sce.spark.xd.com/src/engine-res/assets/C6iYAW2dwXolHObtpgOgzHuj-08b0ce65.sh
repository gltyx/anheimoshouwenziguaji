#ifndef CLUSTER_LIGHTS_SH_HEADER_GUARD
#define CLUSTER_LIGHTS_SH_HEADER_GUARD

#include <Common/bgfx_compute.sh>
#include "Cluster/clustersamplers.sh"

uniform hvec4 u_lightCountVec;
#define u_pointLightCount uint(u_lightCountVec.x + 0.1)
#define u_spotLightCount uint(u_lightCountVec.y + 0.1)
#define u_nonPunctualPointLightCount uint(u_lightCountVec.z + 0.1)

uniform hvec4 u_lightOffsetVec;
#define u_pointLightOffset uint(u_lightOffsetVec.x + 0.1)
#define u_spotLightOffset uint(u_lightOffsetVec.y + 0.1)
#define u_nonPunctualPointLightOffset uint(u_lightOffsetVec.z + 0.1)


// for each light:
//   vec4 position (w is padding)
//   vec4 intensity + radius (xyz is intensity, w is radius)
#if BGFX_SHADER_LANGUAGE_METAL || BX_PLATFORM_WINDOWS_DIRECTX
    BUFFER_RO(b_clusterLights, hvec4, SAMPLER_LIGHTS_POINTLIGHTS);
#else
    UNIFORM_BUFFER_OBJECT(b_clusterLights, hvec4, SAMPLER_LIGHTS_POINTLIGHTS, 600u);
#endif


struct PointLight
{
    hvec3 position;
    hfloat range;
    hvec3 intensity;
    hfloat radius;
};

struct AmbientLight
{
    vec3 irradiance;
};

// primary source:
// https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
// also really good:
// https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf

float distanceAttenuation(float distance)
{
    // only for point lights

    // physics: inverse square falloff
    // to keep irradiance from reaching infinity at really close distances, stop at 1cm
    return 1.0 / max(distance * distance, 0.01 * 0.01);
}

float smoothAttenuation(float distance, float radius)
{
    // window function with smooth transition to 0
    // radius is arbitrary (and usually artist controlled)
    float nom = saturate(1.0 - pow(distance / radius, 4.0));
    return nom * nom * distanceAttenuation(distance);
}

uint GetPointLightCount()
{
    return u_pointLightCount;
}

PointLight GetPointLight(uint i)
{
    PointLight light;
    hvec4 positionRangeVec = b_clusterLights[2 * int(i) + 0];
    light.position = positionRangeVec.xyz;
    light.range = positionRangeVec.w;
    hvec4 intensityRadiusVec = b_clusterLights[2 * int(i) + 1];
    light.intensity = intensityRadiusVec.xyz;
    light.radius = intensityRadiusVec.w;
    return light;
}

#ifdef CLUSTER_SPOTLIGHT
struct SpotLight
{    
    hvec3 position;
    hfloat range;
    hvec3 intensity;
    hfloat cosOuterCone;
    hvec3 direction;
    hfloat invCosConeDiff;
};

SpotLight GetSpotLight(uint i)
{
    SpotLight light;
    hvec4 v1 = b_clusterLights[3 * int(i) + 0];
    hvec4 v2 = b_clusterLights[3 * int(i) + 1];
    hvec4 v3 = b_clusterLights[3 * int(i) + 2];
    light.position = v1.xyz;
    light.range = v1.w;
    light.intensity = v2.xyz;
    light.cosOuterCone = v2.w;
    light.direction = v3.xyz;
    light.invCosConeDiff = v3.w;
    return light;
}
#endif

#ifdef NONPUNCTUAL_LIGHTING

struct NonPunctualPointLight
{
    hvec3 position;
    hfloat range;
    hvec3 intensity;
    hfloat packRadius;
    hvec3 direction;
    hfloat length;
};

NonPunctualPointLight GetNonPunctualPointLight(uint i)
{
    NonPunctualPointLight light;
    hvec4 positionRangeVec = b_clusterLights[u_nonPunctualPointLightOffset + 3 * int(i) + 0];
    light.position = positionRangeVec.xyz;
    light.range = positionRangeVec.w;
    hvec4 intensityRadiusVec = b_clusterLights[u_nonPunctualPointLightOffset + 3 * int(i) + 1];
    light.intensity = intensityRadiusVec.xyz;
    light.packRadius = intensityRadiusVec.w;
    hvec4 directionLengthVec = b_clusterLights[u_nonPunctualPointLightOffset + 3 * int(i) + 2];
    light.direction = directionLengthVec.xyz;
    light.length = directionLengthVec.w;
    return light;
}

#endif

#endif // LIGHTS_SH_HEADER_GUARD
