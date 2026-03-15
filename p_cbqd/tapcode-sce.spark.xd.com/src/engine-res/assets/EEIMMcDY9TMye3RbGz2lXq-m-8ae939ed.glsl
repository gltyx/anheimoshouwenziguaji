#define WRITE_CLUSTERS
#ifdef COMPILECS
#ifdef BGFX_SHADER
#include "varying_cluster.def.sc"

#include "Cluster/clustercommon.sh"
#include "Common/bgfx_compute.sh"
#include "Cluster/clusters.sh"
#include "Cluster/clusterutil.sh"

#define gl_WorkGroupSize uvec3(CLUSTERS_X_THREADS, CLUSTERS_Y_THREADS, CLUSTERS_Z_THREADS)


NUM_THREADS(CLUSTERS_X_THREADS, CLUSTERS_Y_THREADS, CLUSTERS_Z_THREADS)
void main()
{
    uint clusterIndex = gl_GlobalInvocationID.z * gl_WorkGroupSize.x * gl_WorkGroupSize.y +
                        gl_GlobalInvocationID.y * gl_WorkGroupSize.x +
                        gl_GlobalInvocationID.x;

    vec4 minScreen = vec4( vec2(gl_GlobalInvocationID.xy)              * u_clusterSizes.xy, 1.0, 1.0);
    vec4 maxScreen = vec4((vec2(gl_GlobalInvocationID.xy) + vec2(1, 1)) * u_clusterSizes.xy, 1.0, 1.0);

    vec3 minEye = screen2Eye(minScreen).xyz;
    vec3 maxEye = screen2Eye(maxScreen).xyz;

#ifdef ORTHOGRAPHIC
    float clusterNear = lerp(u_zNear, u_zFar, float(gl_GlobalInvocationID.z) / float(CLUSTERS_Z));
    float clusterFar = lerp(u_zNear, u_zFar, float(gl_GlobalInvocationID.z + 1.0) / float(CLUSTERS_Z));

    vec3 minNear = vec3(minEye.xy, clusterNear);
    vec3 minFar  = vec3(minEye.xy, clusterFar);
    vec3 maxNear = vec3(maxEye.xy, clusterNear);
    vec3 maxFar  = vec3(maxEye.xy, clusterFar);
#else    
    float clusterNear = u_zNear * pow(u_zFar / u_zNear,  float(gl_GlobalInvocationID.z)      / float(CLUSTERS_Z));
    float clusterFar  = u_zNear * pow(u_zFar / u_zNear, (float(gl_GlobalInvocationID.z) + 1.0) / float(CLUSTERS_Z));

    vec3 minNear = minEye * clusterNear / minEye.z;
    vec3 minFar  = minEye * clusterFar  / minEye.z;
    vec3 maxNear = maxEye * clusterNear / maxEye.z;
    vec3 maxFar  = maxEye * clusterFar  / maxEye.z;
#endif

    vec3 minBounds = min(min(minNear, minFar), min(maxNear, maxFar));
    vec3 maxBounds = max(max(minNear, minFar), max(maxNear, maxFar));

    b_clusters[2 * int(clusterIndex) + 0] = vec4(minBounds, 1.0);
    b_clusters[2 * int(clusterIndex) + 1] = vec4(maxBounds, 1.0);
}

#endif
#endif
