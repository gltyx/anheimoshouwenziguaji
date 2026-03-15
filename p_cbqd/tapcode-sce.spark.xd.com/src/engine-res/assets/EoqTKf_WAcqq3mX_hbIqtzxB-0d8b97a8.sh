#include "PBR/PBRCommon.glsl"
#ifdef COMPILEPS
#include "PBR/GI.sh"

//cluster的时候由引擎定义，pbr的时候这里设置
#define NONPUNCTUAL_LIGHTING RENDER_QUALITY > RENDER_QUALITY_HIGH

#if defined (CLUSTER)
#include "Cluster/clusterlights.sh"
#include "Cluster/clusters.sh"
#endif


#ifdef NONPUNCTUAL_LIGHTING
#include "PBR/CapsuleLight.sh"
#endif

#if defined(DISNEY_BRDF)

#include "PBR/DisneyBRDF.glsl"
#define Standard_BRDF Disney_BRDF

#elif defined(COOKTORRANCE_BRDF)

#include "PBR/CookTorranceBRDF.glsl"
#define Standard_BRDF CookTorrance_BRDF

#else

// 默认用迪士尼BRDF
#include "PBR/DisneyBRDF.glsl"
#define Standard_BRDF Disney_BRDF

#endif

// Split lighting support for reflection hierarchy system
#ifdef SPLIT_LIGHTING
    #ifdef DISNEY_BRDF
        #define Standard_BRDF_Split Disney_BRDF_Split
    #elif defined(COOKTORRANCE_BRDF)
        // CookTorrance Split not implemented, fallback to Disney
        #define Standard_BRDF_Split Disney_BRDF_Split
    #else
        #define Standard_BRDF_Split Disney_BRDF_Split
    #endif
#endif // SPLIT_LIGHTING

#endif
