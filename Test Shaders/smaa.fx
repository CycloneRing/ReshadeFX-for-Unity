/**
 *                  _______  ___  ___       ___           ___
 *                 /       ||   \/   |     /   \         /   \
 *                |   (---- |  \  /  |    /  ^  \       /  ^  \
 *                 \   \    |  |\/|  |   /  /_\  \     /  /_\  \
 *              ----)   |   |  |  |  |  /  _____  \   /  _____  \
 *             |_______/    |__|  |__| /__/     \__\ /__/     \__\
 *
 *                               E N H A N C E D
 *       S U B P I X E L   M O R P H O L O G I C A L   A N T I A L I A S I N G
 *
 *                               for ReShade 3.0+
 */

//------------------- Preprocessor Settings -------------------

#if !defined(SMAA_PRESET_LOW) && !defined(SMAA_PRESET_MEDIUM) && !defined(SMAA_PRESET_HIGH) && !defined(SMAA_PRESET_ULTRA)
#define SMAA_PRESET_CUSTOM // Do not use a quality preset by default
#endif

//----------------------- UI Variables ------------------------
uniform int EdgeDetectionType = 1;

#ifdef SMAA_PRESET_CUSTOM
uniform float EdgeDetectionThreshold = 0.10;

uniform float DepthEdgeDetectionThreshold = 0.01;

uniform int MaxSearchSteps = 32;

uniform int MaxSearchStepsDiagonal  = 16;

uniform int CornerRounding = 25;

uniform bool PredicationEnabled = false;

uniform float PredicationThreshold = 0.01;

uniform float PredicationScale = 2.0;

uniform float PredicationStrength = 0.4;
#endif

uniform int DebugOutput = false;

#ifdef SMAA_PRESET_CUSTOM
	#define SMAA_PREDICATION PredicationEnabled
	#define SMAA_THRESHOLD EdgeDetectionThreshold
	#define SMAA_DEPTH_THRESHOLD DepthEdgeDetectionThreshold
	#define SMAA_MAX_SEARCH_STEPS MaxSearchSteps
	#define SMAA_MAX_SEARCH_STEPS_DIAG MaxSearchStepsDiagonal
	#define SMAA_CORNER_ROUNDING CornerRounding
	#define SMAA_PREDICATION_THRESHOLD PredicationThreshold
	#define SMAA_PREDICATION_SCALE PredicationScale
	#define SMAA_PREDICATION_STRENGTH PredicationStrength
#endif

#define SMAA_RT_METRICS float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define SMAA_CUSTOM_SL 1

#define SMAATexture2D(tex) sampler tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, coord))
#define SMAASampleLevelZeroPoint(tex, coord) SMAASampleLevelZero(tex, coord)
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex2Dlodoffset(tex, float4(coord, coord), offset)
#define SMAASample(tex, coord) tex2D(tex, coord)
#define SMAASamplePoint(tex, coord) SMAASample(tex, coord)
#define SMAASampleOffset(tex, coord, offset) tex2Doffset(tex, coord, offset)
#define SMAA_BRANCH [branch]
#define SMAA_FLATTEN [flatten]

#if (__RENDERER__ == 0xb000 || __RENDERER__ == 0xb100)
	#define SMAAGather(tex, coord) tex2Dgather(tex, coord, 0)
#endif

#if defined(SMAA_PRESET_LOW)
#define SMAA_THRESHOLD 0.15
#define SMAA_MAX_SEARCH_STEPS 4
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif defined(SMAA_PRESET_MEDIUM)
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 8
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif defined(SMAA_PRESET_HIGH)
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 16
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#define SMAA_CORNER_ROUNDING 25
#elif defined(SMAA_PRESET_ULTRA)
#define SMAA_THRESHOLD 0.05
#define SMAA_MAX_SEARCH_STEPS 32
#define SMAA_MAX_SEARCH_STEPS_DIAG 16
#define SMAA_CORNER_ROUNDING 25
#endif

//-----------------------------------------------------------------------------
// Configurable Defines

/**
 * SMAA_THRESHOLD specifies the threshold or sensitivity to edges.
 * Lowering this value you will be able to detect more edges at the expense of
 * performance. 
 *
 * Range: [0, 0.5]
 *   0.1 is a reasonable value, and allows to catch most visible edges.
 *   0.05 is a rather overkill value, that allows to catch 'em all.
 *
 *   If temporal supersampling is used, 0.2 could be a reasonable value, as low
 *   contrast edges are properly filtered by just 2x.
 */
#ifndef SMAA_THRESHOLD
#define SMAA_THRESHOLD 0.1
#endif

/**
 * SMAA_DEPTH_THRESHOLD specifies the threshold for depth edge detection.
 * 
 * Range: depends on the depth range of the scene.
 */
#ifndef SMAA_DEPTH_THRESHOLD
#define SMAA_DEPTH_THRESHOLD (0.1 * SMAA_THRESHOLD)
#endif

/**
 * SMAA_MAX_SEARCH_STEPS specifies the maximum steps performed in the
 * horizontal/vertical pattern searches, at each side of the pixel.
 *
 * In number of pixels, it's actually the double. So the maximum line length
 * perfectly handled by, for example 16, is 64 (by perfectly, we meant that
 * longer lines won't look as good, but still antialiased).
 *
 * Range: [0, 112]
 */
#ifndef SMAA_MAX_SEARCH_STEPS
#define SMAA_MAX_SEARCH_STEPS 16
#endif

/**
 * SMAA_MAX_SEARCH_STEPS_DIAG specifies the maximum steps performed in the
 * diagonal pattern searches, at each side of the pixel. In this case we jump
 * one pixel at time, instead of two.
 *
 * Range: [0, 20]
 *
 * On high-end machines it is cheap (between a 0.8x and 0.9x slower for 16 
 * steps), but it can have a significant impact on older machines.
 *
 * Define SMAA_DISABLE_DIAG_DETECTION to disable diagonal processing.
 */
#ifndef SMAA_MAX_SEARCH_STEPS_DIAG
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#endif

/**
 * SMAA_CORNER_ROUNDING specifies how much sharp corners will be rounded.
 *
 * Range: [0, 100]
 *
 * Define SMAA_DISABLE_CORNER_DETECTION to disable corner processing.
 */
#ifndef SMAA_CORNER_ROUNDING
#define SMAA_CORNER_ROUNDING 25
#endif

/**
 * If there is an neighbor edge that has SMAA_LOCAL_CONTRAST_FACTOR times
 * bigger contrast than current edge, current edge will be discarded.
 *
 * This allows to eliminate spurious crossing edges, and is based on the fact
 * that, if there is too much contrast in a direction, that will hide
 * perceptually contrast in the other neighbors.
 */
#ifndef SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR
#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0
#endif

/**
 * Predicated thresholding allows to better preserve texture details and to
 * improve performance, by decreasing the number of detected edges using an
 * additional buffer like the light accumulation buffer, object ids or even the
 * depth buffer (the depth buffer usage may be limited to indoor or short range
 * scenes).
 *
 * It locally decreases the luma or color threshold if an edge is found in an
 * additional buffer (so the global threshold can be higher).
 *
 * This method was developed by Playstation EDGE MLAA team, and used in 
 * Killzone 3, by using the light accumulation buffer. More information here:
 *     http://iryoku.com/aacourse/downloads/06-MLAA-on-PS3.pptx 
 */
#ifndef SMAA_PREDICATION
#define SMAA_PREDICATION 0
#endif

/**
 * Threshold to be used in the additional predication buffer. 
 *
 * Range: depends on the input, so you'll have to find the magic number that
 * works for you.
 */
#ifndef SMAA_PREDICATION_THRESHOLD
#define SMAA_PREDICATION_THRESHOLD 0.01
#endif

/**
 * How much to scale the global threshold used for luma or color edge
 * detection when using predication.
 *
 * Range: [1, 16]
 */
#ifndef SMAA_PREDICATION_SCALE
#define SMAA_PREDICATION_SCALE 2.0
#endif

/**
 * How much to locally decrease the threshold.
 *
 * Range: [0, 4]
 */
#ifndef SMAA_PREDICATION_STRENGTH
#define SMAA_PREDICATION_STRENGTH 0.4
#endif

/**
 * Temporal reprojection allows to remove ghosting artifacts when using
 * temporal supersampling. We use the CryEngine 3 method which also introduces
 * velocity weighting. This feature is of extreme importance for totally
 * removing ghosting. More information here:
 *    http://iryoku.com/aacourse/downloads/13-Anti-Aliasing-Methods-in-CryENGINE-3.pdf
 *
 * Note that you'll need to setup a velocity buffer for enabling reprojection.
 * For static geometry, saving the previous depth buffer is a viable
 * alternative.
 */
#ifndef SMAA_REPROJECTION
#define SMAA_REPROJECTION 0
#endif

/**
 * SMAA_REPROJECTION_WEIGHT_SCALE controls the velocity weighting. It allows to
 * remove ghosting trails behind the moving object, which are not removed by
 * just using reprojection. Using low values will exhibit ghosting, while using
 * high values will disable temporal supersampling under motion.
 *
 * Behind the scenes, velocity weighting removes temporal supersampling when
 * the velocity of the subsamples differs (meaning they are different objects).
 *
 * Range: [0, 80]
 */
#ifndef SMAA_REPROJECTION_WEIGHT_SCALE
#define SMAA_REPROJECTION_WEIGHT_SCALE 30.0
#endif

/**
 * On some compilers, discard cannot be used in vertex shaders. Thus, they need
 * to be compiled separately.
 */
#ifndef SMAA_INCLUDE_VS
#define SMAA_INCLUDE_VS 1
#endif
#ifndef SMAA_INCLUDE_PS
#define SMAA_INCLUDE_PS 1
#endif

//-----------------------------------------------------------------------------
// Texture Access Defines

#ifndef SMAA_AREATEX_SELECT
#if defined(SMAA_HLSL_3)
#define SMAA_AREATEX_SELECT(sample) sample.ra
#else
#define SMAA_AREATEX_SELECT(sample) sample.rg
#endif
#endif

#ifndef SMAA_SEARCHTEX_SELECT
#define SMAA_SEARCHTEX_SELECT(sample) sample.r
#endif

#ifndef SMAA_DECODE_VELOCITY
#define SMAA_DECODE_VELOCITY(sample) sample.rg
#endif

//-----------------------------------------------------------------------------
// Non-Configurable Defines

#define SMAA_AREATEX_MAX_DISTANCE 16
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / float2(160.0, 560.0))
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
#define SMAA_SEARCHTEX_SIZE float2(66.0, 33.0)
#define SMAA_SEARCHTEX_PACKED_SIZE float2(64.0, 16.0)
#define SMAA_CORNER_ROUNDING_NORM (float(SMAA_CORNER_ROUNDING) / 100.0)

//-----------------------------------------------------------------------------
// Porting Functions

#if defined(SMAA_HLSL_3)
#define SMAATexture2D(tex) sampler2D tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
#define SMAASampleLevelZeroPoint(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex2Dlod(tex, float4(coord + offset * SMAA_RT_METRICS.xy, 0.0, 0.0))
#define SMAASample(tex, coord) tex2D(tex, coord)
#define SMAASamplePoint(tex, coord) tex2D(tex, coord)
#define SMAASampleOffset(tex, coord, offset) tex2D(tex, coord + offset * SMAA_RT_METRICS.xy)
#define SMAA_FLATTEN [flatten]
#define SMAA_BRANCH [branch]
#endif
#if defined(SMAA_HLSL_4) || defined(SMAA_HLSL_4_1)
SamplerState LinearSampler { Filter = MIN_MAG_LINEAR_MIP_POINT; AddressU = Clamp; AddressV = Clamp; };
SamplerState PointSampler { Filter = MIN_MAG_MIP_POINT; AddressU = Clamp; AddressV = Clamp; };
#define SMAATexture2D(tex) Texture2D tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex.SampleLevel(LinearSampler, coord, 0)
#define SMAASampleLevelZeroPoint(tex, coord) tex.SampleLevel(PointSampler, coord, 0)
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex.SampleLevel(LinearSampler, coord, 0, offset)
#define SMAASample(tex, coord) tex.Sample(LinearSampler, coord)
#define SMAASamplePoint(tex, coord) tex.Sample(PointSampler, coord)
#define SMAASampleOffset(tex, coord, offset) tex.Sample(LinearSampler, coord, offset)
#define SMAA_FLATTEN [flatten]
#define SMAA_BRANCH [branch]
#define SMAATexture2DMS2(tex) Texture2DMS<float4, 2> tex
#define SMAALoad(tex, pos, sample) tex.Load(pos, sample)
#if defined(SMAA_HLSL_4_1)
#define SMAAGather(tex, coord) tex.Gather(LinearSampler, coord, 0)
#endif
#endif
#if defined(SMAA_GLSL_3) || defined(SMAA_GLSL_4)
#define SMAATexture2D(tex) sampler2D tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) textureLod(tex, coord, 0.0)
#define SMAASampleLevelZeroPoint(tex, coord) textureLod(tex, coord, 0.0)
#define SMAASampleLevelZeroOffset(tex, coord, offset) textureLodOffset(tex, coord, 0.0, offset)
#define SMAASample(tex, coord) texture(tex, coord)
#define SMAASamplePoint(tex, coord) texture(tex, coord)
#define SMAASampleOffset(tex, coord, offset) texture(tex, coord, offset)
#define SMAA_FLATTEN
#define SMAA_BRANCH
#define lerp(a, b, t) mix(a, b, t)
#define saturate(a) clamp(a, 0.0, 1.0)
#if defined(SMAA_GLSL_4)
#define mad(a, b, c) fma(a, b, c)
#define SMAAGather(tex, coord) textureGather(tex, coord)
#else
#define mad(a, b, c) (a * b + c)
#endif
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define int2 ivec2
#define int3 ivec3
#define int4 ivec4
#define bool2 bvec2
#define bool3 bvec3
#define bool4 bvec4
#endif

#if !defined(SMAA_HLSL_3) && !defined(SMAA_HLSL_4) && !defined(SMAA_HLSL_4_1) && !defined(SMAA_GLSL_3) && !defined(SMAA_GLSL_4) && !defined(SMAA_CUSTOM_SL)
#error you must define the shading language: SMAA_HLSL_*, SMAA_GLSL_* or SMAA_CUSTOM_SL
#endif

//-----------------------------------------------------------------------------
// Misc functions

/**
 * Gathers current pixel, and the top-left neighbors.
 */
float3 SMAAGatherNeighbours(float2 texcoord,
                            float4 offset[3],
                            SMAATexture2D(tex)) {
    #ifdef SMAAGather
    return SMAAGather(tex, texcoord + SMAA_RT_METRICS.xy * float2(-0.5, -0.5)).grb;
    #else
    float P = SMAASamplePoint(tex, texcoord).r;
    float Pleft = SMAASamplePoint(tex, offset[0].xy).r;
    float Ptop  = SMAASamplePoint(tex, offset[0].zw).r;
    return float3(P, Pleft, Ptop);
    #endif
}

/**
 * Adjusts the threshold by means of predication.
 */
float2 SMAACalculatePredicatedThreshold(float2 texcoord,
                                        float4 offset[3],
                                        SMAATexture2D(predicationTex)) {
    float3 neighbours = SMAAGatherNeighbours(texcoord, offset, SMAATexturePass2D(predicationTex));
    float2 delta = abs(neighbours.xx - neighbours.yz);
    float2 edges = step(SMAA_PREDICATION_THRESHOLD, delta);
    return SMAA_PREDICATION_SCALE * SMAA_THRESHOLD * (1.0 - SMAA_PREDICATION_STRENGTH * edges);
}

/**
 * Conditional move:
 */
void SMAAMovc(bool2 cond, inout float2 variable, float2 value) {
    SMAA_FLATTEN if (cond.x) variable.x = value.x;
    SMAA_FLATTEN if (cond.y) variable.y = value.y;
}

void SMAAMovc(bool4 cond, inout float4 variable, float4 value) {
    SMAAMovc(cond.xy, variable.xy, value.xy);
    SMAAMovc(cond.zw, variable.zw, value.zw);
}


#if SMAA_INCLUDE_VS
//-----------------------------------------------------------------------------
// Vertex Shaders

/**
 * Edge Detection Vertex Shader
 */
void SMAAEdgeDetectionVS(float2 texcoord,
                         out float4 offset[3]) {
    offset[0] = mad(SMAA_RT_METRICS.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
    offset[1] = mad(SMAA_RT_METRICS.xyxy, float4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy);
    offset[2] = mad(SMAA_RT_METRICS.xyxy, float4(-2.0, 0.0, 0.0, -2.0), texcoord.xyxy);
}

/**
 * Blend Weight Calculation Vertex Shader
 */
void SMAABlendingWeightCalculationVS(float2 texcoord,
                                     out float2 pixcoord,
                                     out float4 offset[3]) {
    pixcoord = texcoord * SMAA_RT_METRICS.zw;

    // We will use these offsets for the searches later on (see @PSEUDO_GATHER4):
    offset[0] = mad(SMAA_RT_METRICS.xyxy, float4(-0.25, -0.125,  1.25, -0.125), texcoord.xyxy);
    offset[1] = mad(SMAA_RT_METRICS.xyxy, float4(-0.125, -0.25, -0.125,  1.25), texcoord.xyxy);

    // And these for the searches, they indicate the ends of the loops:
    offset[2] = mad(SMAA_RT_METRICS.xxyy,
                    float4(-2.0, 2.0, -2.0, 2.0) * float(SMAA_MAX_SEARCH_STEPS),
                    float4(offset[0].xz, offset[1].yw));
}

/**
 * Neighborhood Blending Vertex Shader
 */
void SMAANeighborhoodBlendingVS(float2 texcoord,
                                out float4 offset) {
    offset = mad(SMAA_RT_METRICS.xyxy, float4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy);
}
#endif // SMAA_INCLUDE_VS

#if SMAA_INCLUDE_PS
//-----------------------------------------------------------------------------
// Edge Detection Pixel Shaders (First Pass)

/**
 * Luma Edge Detection
 *
 * IMPORTANT NOTICE: luma edge detection requires gamma-corrected colors, and
 * thus 'colorTex' should be a non-sRGB texture.
 */
float2 SMAALumaEdgeDetectionPS(float2 texcoord,
                               float4 offset[3],
                               SMAATexture2D(colorTex)
                               ) {
    // Calculate the threshold:
    float2 threshold = float2(SMAA_THRESHOLD, SMAA_THRESHOLD);

    // Calculate lumas:
    float3 weights = float3(0.2126, 0.7152, 0.0722);
    float L = dot(SMAASamplePoint(colorTex, texcoord).rgb, weights);

    float Lleft = dot(SMAASamplePoint(colorTex, offset[0].xy).rgb, weights);
    float Ltop  = dot(SMAASamplePoint(colorTex, offset[0].zw).rgb, weights);

    // We do the usual threshold:
    float4 delta;
    delta.xy = abs(L - float2(Lleft, Ltop));
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, float2(1.0, 1.0)) == 0.0)
        discard;

    // Calculate right and bottom deltas:
    float Lright = dot(SMAASamplePoint(colorTex, offset[1].xy).rgb, weights);
    float Lbottom  = dot(SMAASamplePoint(colorTex, offset[1].zw).rgb, weights);
    delta.zw = abs(L - float2(Lright, Lbottom));

    // Calculate the maximum delta in the direct neighborhood:
    float2 maxDelta = max(delta.xy, delta.zw);

    // Calculate left-left and top-top deltas:
    float Lleftleft = dot(SMAASamplePoint(colorTex, offset[2].xy).rgb, weights);
    float Ltoptop = dot(SMAASamplePoint(colorTex, offset[2].zw).rgb, weights);
    delta.zw = abs(float2(Lleft, Ltop) - float2(Lleftleft, Ltoptop));

    // Calculate the final maximum delta:
    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    // Local contrast adaptation:
    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);

    return edges;
}

float2 SMAALumaEdgePredicationDetectionPS(float2 texcoord,
                               float4 offset[3],
                               SMAATexture2D(colorTex)
                               , SMAATexture2D(predicationTex)
                               ) {
    // Calculate the threshold:
	float2 threshold = SMAACalculatePredicatedThreshold(texcoord, offset, SMAATexturePass2D(predicationTex));

    // Calculate lumas:
    float3 weights = float3(0.2126, 0.7152, 0.0722);
    float L = dot(SMAASamplePoint(colorTex, texcoord).rgb, weights);

    float Lleft = dot(SMAASamplePoint(colorTex, offset[0].xy).rgb, weights);
    float Ltop  = dot(SMAASamplePoint(colorTex, offset[0].zw).rgb, weights);

    // We do the usual threshold:
    float4 delta;
    delta.xy = abs(L - float2(Lleft, Ltop));
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, float2(1.0, 1.0)) == 0.0)
        discard;

    // Calculate right and bottom deltas:
    float Lright = dot(SMAASamplePoint(colorTex, offset[1].xy).rgb, weights);
    float Lbottom  = dot(SMAASamplePoint(colorTex, offset[1].zw).rgb, weights);
    delta.zw = abs(L - float2(Lright, Lbottom));

    // Calculate the maximum delta in the direct neighborhood:
    float2 maxDelta = max(delta.xy, delta.zw);

    // Calculate left-left and top-top deltas:
    float Lleftleft = dot(SMAASamplePoint(colorTex, offset[2].xy).rgb, weights);
    float Ltoptop = dot(SMAASamplePoint(colorTex, offset[2].zw).rgb, weights);
    delta.zw = abs(float2(Lleft, Ltop) - float2(Lleftleft, Ltoptop));

    // Calculate the final maximum delta:
    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    // Local contrast adaptation:
    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);

    return edges;
}

/**
 * Color Edge Detection
 *
 * IMPORTANT NOTICE: color edge detection requires gamma-corrected colors, and
 * thus 'colorTex' should be a non-sRGB texture.
 */
float2 SMAAColorEdgeDetectionPS(float2 texcoord,
                                float4 offset[3],
                                SMAATexture2D(colorTex)
                                ) {
    // Calculate the threshold:
    float2 threshold = float2(SMAA_THRESHOLD, SMAA_THRESHOLD);

    // Calculate color deltas:
    float4 delta;
    float3 C = SMAASamplePoint(colorTex, texcoord).rgb;

    float3 Cleft = SMAASamplePoint(colorTex, offset[0].xy).rgb;
    float3 t = abs(C - Cleft);
    delta.x = max(max(t.r, t.g), t.b);

    float3 Ctop  = SMAASamplePoint(colorTex, offset[0].zw).rgb;
    t = abs(C - Ctop);
    delta.y = max(max(t.r, t.g), t.b);

    // We do the usual threshold:
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, float2(1.0, 1.0)) == 0.0)
        discard;

    // Calculate right and bottom deltas:
    float3 Cright = SMAASamplePoint(colorTex, offset[1].xy).rgb;
    t = abs(C - Cright);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Cbottom  = SMAASamplePoint(colorTex, offset[1].zw).rgb;
    t = abs(C - Cbottom);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the maximum delta in the direct neighborhood:
    float2 maxDelta = max(delta.xy, delta.zw);

    // Calculate left-left and top-top deltas:
    float3 Cleftleft  = SMAASamplePoint(colorTex, offset[2].xy).rgb;
    t = abs(Cleft - Cleftleft);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Ctoptop = SMAASamplePoint(colorTex, offset[2].zw).rgb;
    t = abs(Ctop - Ctoptop);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the final maximum delta:
    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    // Local contrast adaptation:
    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);

    return edges;
}

float2 SMAAColorEdgePredicationDetectionPS(float2 texcoord,
                                float4 offset[3],
                                SMAATexture2D(colorTex)
                                , SMAATexture2D(predicationTex)
                                ) {
    // Calculate the threshold:
    float2 threshold = SMAACalculatePredicatedThreshold(texcoord, offset, predicationTex);

    // Calculate color deltas:
    float4 delta;
    float3 C = SMAASamplePoint(colorTex, texcoord).rgb;

    float3 Cleft = SMAASamplePoint(colorTex, offset[0].xy).rgb;
    float3 t = abs(C - Cleft);
    delta.x = max(max(t.r, t.g), t.b);

    float3 Ctop  = SMAASamplePoint(colorTex, offset[0].zw).rgb;
    t = abs(C - Ctop);
    delta.y = max(max(t.r, t.g), t.b);

    // We do the usual threshold:
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, float2(1.0, 1.0)) == 0.0)
        discard;

    // Calculate right and bottom deltas:
    float3 Cright = SMAASamplePoint(colorTex, offset[1].xy).rgb;
    t = abs(C - Cright);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Cbottom  = SMAASamplePoint(colorTex, offset[1].zw).rgb;
    t = abs(C - Cbottom);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the maximum delta in the direct neighborhood:
    float2 maxDelta = max(delta.xy, delta.zw);

    // Calculate left-left and top-top deltas:
    float3 Cleftleft  = SMAASamplePoint(colorTex, offset[2].xy).rgb;
    t = abs(Cleft - Cleftleft);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Ctoptop = SMAASamplePoint(colorTex, offset[2].zw).rgb;
    t = abs(Ctop - Ctoptop);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the final maximum delta:
    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    // Local contrast adaptation:
    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);

    return edges;
}

/**
 * Depth Edge Detection
 */
float2 SMAADepthEdgeDetectionPS(float2 texcoord,
                                float4 offset[3],
                                SMAATexture2D(depthTex)) {
    float3 neighbours = SMAAGatherNeighbours(texcoord, offset, SMAATexturePass2D(depthTex));
    float2 delta = abs(neighbours.xx - float2(neighbours.y, neighbours.z));
    float2 edges = step(SMAA_DEPTH_THRESHOLD, delta);

    if (dot(edges, float2(1.0, 1.0)) == 0.0)
        discard;

    return edges;
}

//-----------------------------------------------------------------------------
// Diagonal Search Functions

#if !defined(SMAA_DISABLE_DIAG_DETECTION)

/**
 * Allows to decode two binary values from a bilinear-filtered access.
 */
float2 SMAADecodeDiagBilinearAccess(float2 e) {
    // Bilinear access for fetching 'e' have a 0.25 offset, and we are
    // interested in the R and G edges:
    //
    // +---G---+-------+
    // |   x o R   x   |
    // +-------+-------+
    //
    // Then, if one of these edge is enabled:
    //   Red:   (0.75 * X + 0.25 * 1) => 0.25 or 1.0
    //   Green: (0.75 * 1 + 0.25 * X) => 0.75 or 1.0
    //
    // This function will unpack the values (mad + mul + round):
    // wolframalpha.com: round(x * abs(5 * x - 5 * 0.75)) plot 0 to 1
    e.r = e.r * abs(5.0 * e.r - 5.0 * 0.75);
    return round(e);
}

float4 SMAADecodeDiagBilinearAccess(float4 e) {
    e.rb = e.rb * abs(5.0 * e.rb - 5.0 * 0.75);
    return round(e);
}

/**
 * These functions allows to perform diagonal pattern searches.
 */
float2 SMAASearchDiag1(SMAATexture2D(edgesTex), float2 texcoord, float2 dir, out float2 e) {
    float4 coord = float4(texcoord, -1.0, 1.0);
    float3 t = float3(SMAA_RT_METRICS.xy, 1.0);
    while (coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) &&
           coord.w > 0.9) {
        coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);
        e = SMAASampleLevelZero(edgesTex, coord.xy).rg;
        coord.w = dot(e, float2(0.5, 0.5));
    }
    return coord.zw;
}

float2 SMAASearchDiag2(SMAATexture2D(edgesTex), float2 texcoord, float2 dir, out float2 e) {
    float4 coord = float4(texcoord, -1.0, 1.0);
    coord.x += 0.25 * SMAA_RT_METRICS.x; // See @SearchDiag2Optimization
    float3 t = float3(SMAA_RT_METRICS.xy, 1.0);
    while (coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) &&
           coord.w > 0.9) {
        coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);

        // @SearchDiag2Optimization
        // Fetch both edges at once using bilinear filtering:
        e = SMAASampleLevelZero(edgesTex, coord.xy).rg;
        e = SMAADecodeDiagBilinearAccess(e);

        // Non-optimized version:
        // e.g = SMAASampleLevelZero(edgesTex, coord.xy).g;
        // e.r = SMAASampleLevelZeroOffset(edgesTex, coord.xy, int2(1, 0)).r;

        coord.w = dot(e, float2(0.5, 0.5));
    }
    return coord.zw;
}

/** 
 * Similar to SMAAArea, this calculates the area corresponding to a certain
 * diagonal distance and crossing edges 'e'.
 */
float2 SMAAAreaDiag(SMAATexture2D(areaTex), float2 dist, float2 e, float offset) {
    float2 texcoord = mad(float2(SMAA_AREATEX_MAX_DISTANCE_DIAG, SMAA_AREATEX_MAX_DISTANCE_DIAG), e, dist);

    // We do a scale and bias for mapping to texel space:
    texcoord = mad(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);

    // Diagonal areas are on the second half of the texture:
    texcoord.x += 0.5;

    // Move to proper place, according to the subpixel offset:
    texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;

    // Do it!
    return SMAA_AREATEX_SELECT(SMAASampleLevelZero(areaTex, texcoord));
}

/**
 * This searches for diagonal patterns and returns the corresponding weights.
 */
float2 SMAACalculateDiagWeights(SMAATexture2D(edgesTex), SMAATexture2D(areaTex), float2 texcoord, float2 e, float4 subsampleIndices) {
    float2 weights = float2(0.0, 0.0);

    // Search for the line ends:
    float4 d;
    float2 end;
    if (e.r > 0.0) {
        d.xz = SMAASearchDiag1(SMAATexturePass2D(edgesTex), texcoord, float2(-1.0,  1.0), end);
        d.x += float(end.y > 0.9);
    } else
        d.xz = float2(0.0, 0.0);
    d.yw = SMAASearchDiag1(SMAATexturePass2D(edgesTex), texcoord, float2(1.0, -1.0), end);

    SMAA_BRANCH
    if (d.x + d.y > 2.0) { // d.x + d.y + 1 > 3
        // Fetch the crossing edges:
        float4 coords = mad(float4(-d.x + 0.25, d.x, d.y, -d.y - 0.25), SMAA_RT_METRICS.xyxy, texcoord.xyxy);
        float4 c;
        c.xy = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-1,  0)).rg;
        c.zw = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1,  0)).rg;
        c.yxwz = SMAADecodeDiagBilinearAccess(c.xyzw);

        // Non-optimized version:
        // float4 coords = mad(float4(-d.x, d.x, d.y, -d.y), SMAA_RT_METRICS.xyxy, texcoord.xyxy);
        // float4 c;
        // c.x = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-1,  0)).g;
        // c.y = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2( 0,  0)).r;
        // c.z = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1,  0)).g;
        // c.w = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1, -1)).r;

        // Merge crossing edges at each side into a single value:
        float2 cc = mad(float2(2.0, 2.0), c.xz, c.yw);

        // Remove the crossing edge if we didn't found the end of the line:
        SMAAMovc(bool2(step(0.9, d.zw)), cc, float2(0.0, 0.0));

        // Fetch the areas for this line:
        weights += SMAAAreaDiag(SMAATexturePass2D(areaTex), d.xy, cc, subsampleIndices.z);
    }

    // Search for the line ends:
    d.xz = SMAASearchDiag2(SMAATexturePass2D(edgesTex), texcoord, float2(-1.0, -1.0), end);
    if (SMAASampleLevelZeroOffset(edgesTex, texcoord, int2(1, 0)).r > 0.0) {
        d.yw = SMAASearchDiag2(SMAATexturePass2D(edgesTex), texcoord, float2(1.0, 1.0), end);
        d.y += float(end.y > 0.9);
    } else
        d.yw = float2(0.0, 0.0);

    SMAA_BRANCH
    if (d.x + d.y > 2.0) { // d.x + d.y + 1 > 3
        // Fetch the crossing edges:
        float4 coords = mad(float4(-d.x, -d.x, d.y, d.y), SMAA_RT_METRICS.xyxy, texcoord.xyxy);
        float4 c;
        c.x  = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-1,  0)).g;
        c.y  = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2( 0, -1)).r;
        c.zw = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1,  0)).gr;
        float2 cc = mad(float2(2.0, 2.0), c.xz, c.yw);

        // Remove the crossing edge if we didn't found the end of the line:
        SMAAMovc(bool2(step(0.9, d.zw)), cc, float2(0.0, 0.0));

        // Fetch the areas for this line:
        weights += SMAAAreaDiag(SMAATexturePass2D(areaTex), d.xy, cc, subsampleIndices.w).gr;
    }

    return weights;
}
#endif

//-----------------------------------------------------------------------------
// Horizontal/Vertical Search Functions

/**
 * This allows to determine how much length should we add in the last step
 * of the searches. It takes the bilinearly interpolated edge (see 
 * @PSEUDO_GATHER4), and adds 0, 1 or 2, depending on which edges and
 * crossing edges are active.
 */
float SMAASearchLength(SMAATexture2D(searchTex), float2 e, float offset) {
    // The texture is flipped vertically, with left and right cases taking half
    // of the space horizontally:
    float2 scale = SMAA_SEARCHTEX_SIZE * float2(0.5, -1.0);
    float2 bias = SMAA_SEARCHTEX_SIZE * float2(offset, 1.0);

    // Scale and bias to access texel centers:
    scale += float2(-1.0,  1.0);
    bias  += float2( 0.5, -0.5);

    // Convert from pixel coordinates to texcoords:
    // (We use SMAA_SEARCHTEX_PACKED_SIZE because the texture is cropped)
    scale *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;
    bias *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;

    // Lookup the search texture:
    return SMAA_SEARCHTEX_SELECT(SMAASampleLevelZero(searchTex, mad(scale, e, bias)));
}

/**
 * Horizontal/vertical search functions for the 2nd pass.
 */
float SMAASearchXLeft(SMAATexture2D(edgesTex), SMAATexture2D(searchTex), float2 texcoord, float end) {
    /**
     * @PSEUDO_GATHER4
     * This texcoord has been offset by (-0.25, -0.125) in the vertex shader to
     * sample between edge, thus fetching four edges in a row.
     * Sampling with different offsets in each direction allows to disambiguate
     * which edges are active from the four fetched ones.
     */
    float2 e = float2(0.0, 1.0);
    while (texcoord.x > end && 
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord = mad(-float2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
    }

    float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e, 0.0), 3.25);
    return mad(SMAA_RT_METRICS.x, offset, texcoord.x);

    // Non-optimized version:
    // We correct the previous (-0.25, -0.125) offset we applied:
    // texcoord.x += 0.25 * SMAA_RT_METRICS.x;

    // The searches are bias by 1, so adjust the coords accordingly:
    // texcoord.x += SMAA_RT_METRICS.x;

    // Disambiguate the length added by the last step:
    // texcoord.x += 2.0 * SMAA_RT_METRICS.x; // Undo last step
    // texcoord.x -= SMAA_RT_METRICS.x * (255.0 / 127.0) * SMAASearchLength(SMAATexturePass2D(searchTex), e, 0.0);
    // return mad(SMAA_RT_METRICS.x, offset, texcoord.x);
}

float SMAASearchXRight(SMAATexture2D(edgesTex), SMAATexture2D(searchTex), float2 texcoord, float end) {
    float2 e = float2(0.0, 1.0);
    while (texcoord.x < end && 
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord = mad(float2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e, 0.5), 3.25);
    return mad(-SMAA_RT_METRICS.x, offset, texcoord.x);
}

float SMAASearchYUp(SMAATexture2D(edgesTex), SMAATexture2D(searchTex), float2 texcoord, float end) {
    float2 e = float2(1.0, 0.0);
    while (texcoord.y > end && 
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord = mad(-float2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e.gr, 0.0), 3.25);
    return mad(SMAA_RT_METRICS.y, offset, texcoord.y);
}

float SMAASearchYDown(SMAATexture2D(edgesTex), SMAATexture2D(searchTex), float2 texcoord, float end) {
    float2 e = float2(1.0, 0.0);
    while (texcoord.y < end && 
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord = mad(float2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e.gr, 0.5), 3.25);
    return mad(-SMAA_RT_METRICS.y, offset, texcoord.y);
}

/** 
 * Ok, we have the distance and both crossing edges. So, what are the areas
 * at each side of current edge?
 */
float2 SMAAArea(SMAATexture2D(areaTex), float2 dist, float e1, float e2, float offset) {
    // Rounding prevents precision errors of bilinear filtering:
    float2 texcoord = mad(float2(SMAA_AREATEX_MAX_DISTANCE, SMAA_AREATEX_MAX_DISTANCE), round(4.0 * float2(e1, e2)), dist);
    
    // We do a scale and bias for mapping to texel space:
    texcoord = mad(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);

    // Move to proper place, according to the subpixel offset:
    texcoord.y = mad(SMAA_AREATEX_SUBTEX_SIZE, offset, texcoord.y);

    // Do it!
    return SMAA_AREATEX_SELECT(SMAASampleLevelZero(areaTex, texcoord));
}

//-----------------------------------------------------------------------------
// Corner Detection Functions

void SMAADetectHorizontalCornerPattern(SMAATexture2D(edgesTex), inout float2 weights, float4 texcoord, float2 d) {
    #if !defined(SMAA_DISABLE_CORNER_DETECTION)
    float2 leftRight = step(d.xy, d.yx);
    float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;

    rounding /= leftRight.x + leftRight.y; // Reduce blending for pixels in the center of a line.

    float2 factor = float2(1.0, 1.0);
    factor.x -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2(0,  1)).r;
    factor.x -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2(1,  1)).r;
    factor.y -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2(0, -2)).r;
    factor.y -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2(1, -2)).r;

    weights *= saturate(factor);
    #endif
}

void SMAADetectVerticalCornerPattern(SMAATexture2D(edgesTex), inout float2 weights, float4 texcoord, float2 d) {
    #if !defined(SMAA_DISABLE_CORNER_DETECTION)
    float2 leftRight = step(d.xy, d.yx);
    float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;

    rounding /= leftRight.x + leftRight.y;

    float2 factor = float2(1.0, 1.0);
    factor.x -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2( 1, 0)).g;
    factor.x -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2( 1, 1)).g;
    factor.y -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2(-2, 0)).g;
    factor.y -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2(-2, 1)).g;

    weights *= saturate(factor);
    #endif
}

//-----------------------------------------------------------------------------
// Blending Weight Calculation Pixel Shader (Second Pass)

float4 SMAABlendingWeightCalculationPS(float2 texcoord,
                                       float2 pixcoord,
                                       float4 offset[3],
                                       SMAATexture2D(edgesTex),
                                       SMAATexture2D(areaTex),
                                       SMAATexture2D(searchTex),
                                       float4 subsampleIndices) { // Just pass zero for SMAA 1x, see @SUBSAMPLE_INDICES.
    float4 weights = float4(0.0, 0.0, 0.0, 0.0);

    float2 e = SMAASample(edgesTex, texcoord).rg;

    SMAA_BRANCH
    if (e.g > 0.0) { // Edge at north
        #if !defined(SMAA_DISABLE_DIAG_DETECTION)
        // Diagonals have both north and west edges, so searching for them in
        // one of the boundaries is enough.
        weights.rg = SMAACalculateDiagWeights(SMAATexturePass2D(edgesTex), SMAATexturePass2D(areaTex), texcoord, e, subsampleIndices);

        // We give priority to diagonals, so if we find a diagonal we skip 
        // horizontal/vertical processing.
        SMAA_BRANCH
        if (weights.r == -weights.g) { // weights.r + weights.g == 0.0
        #endif

        float2 d;

        // Find the distance to the left:
        float3 coords;
        coords.x = SMAASearchXLeft(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[0].xy, offset[2].x);
        coords.y = offset[1].y; // offset[1].y = texcoord.y - 0.25 * SMAA_RT_METRICS.y (@CROSSING_OFFSET)
        d.x = coords.x;

        // Now fetch the left crossing edges, two at a time using bilinear
        // filtering. Sampling at -0.25 (see @CROSSING_OFFSET) enables to
        // discern what value each edge has:
        float e1 = SMAASampleLevelZero(edgesTex, coords.xy).r;

        // Find the distance to the right:
        coords.z = SMAASearchXRight(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[0].zw, offset[2].y);
        d.y = coords.z;

        // We want the distances to be in pixel units (doing this here allow to
        // better interleave arithmetic and memory accesses):
        d = abs(round(mad(SMAA_RT_METRICS.zz, d, -pixcoord.xx)));

        // SMAAArea below needs a sqrt, as the areas texture is compressed
        // quadratically:
        float2 sqrt_d = sqrt(d);

        // Fetch the right crossing edges:
        float e2 = SMAASampleLevelZeroOffset(edgesTex, coords.zy, int2(1, 0)).r;

        // Ok, we know how this pattern looks like, now it is time for getting
        // the actual area:
        weights.rg = SMAAArea(SMAATexturePass2D(areaTex), sqrt_d, e1, e2, subsampleIndices.y);

        // Fix corners:
        coords.y = texcoord.y;
        SMAADetectHorizontalCornerPattern(SMAATexturePass2D(edgesTex), weights.rg, coords.xyzy, d);

        #if !defined(SMAA_DISABLE_DIAG_DETECTION)
        } else
            e.r = 0.0; // Skip vertical processing.
        #endif
    }

    SMAA_BRANCH
    if (e.r > 0.0) { // Edge at west
        float2 d;

        // Find the distance to the top:
        float3 coords;
        coords.y = SMAASearchYUp(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[1].xy, offset[2].z);
        coords.x = offset[0].x; // offset[1].x = texcoord.x - 0.25 * SMAA_RT_METRICS.x;
        d.x = coords.y;

        // Fetch the top crossing edges:
        float e1 = SMAASampleLevelZero(edgesTex, coords.xy).g;

        // Find the distance to the bottom:
        coords.z = SMAASearchYDown(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[1].zw, offset[2].w);
        d.y = coords.z;

        // We want the distances to be in pixel units:
        d = abs(round(mad(SMAA_RT_METRICS.ww, d, -pixcoord.yy)));

        // SMAAArea below needs a sqrt, as the areas texture is compressed 
        // quadratically:
        float2 sqrt_d = sqrt(d);

        // Fetch the bottom crossing edges:
        float e2 = SMAASampleLevelZeroOffset(edgesTex, coords.xz, int2(0, 1)).g;

        // Get the area for this direction:
        weights.ba = SMAAArea(SMAATexturePass2D(areaTex), sqrt_d, e1, e2, subsampleIndices.x);

        // Fix corners:
        coords.x = texcoord.x;
        SMAADetectVerticalCornerPattern(SMAATexturePass2D(edgesTex), weights.ba, coords.xyxz, d);
    }

    return weights;
}

//-----------------------------------------------------------------------------
// Neighborhood Blending Pixel Shader (Third Pass)

float4 SMAANeighborhoodBlendingPS(float2 texcoord,
                                  float4 offset,
                                  SMAATexture2D(colorTex),
                                  SMAATexture2D(blendTex)
                                  #if SMAA_REPROJECTION
                                  , SMAATexture2D(velocityTex)
                                  #endif
                                  ) {
    // Fetch the blending weights for current pixel:
    float4 a;
    a.x = SMAASample(blendTex, offset.xy).a; // Right
    a.y = SMAASample(blendTex, offset.zw).g; // Top
    a.wz = SMAASample(blendTex, texcoord).xz; // Bottom / Left

    // Is there any blending weight with a value greater than 0.0?
    SMAA_BRANCH
    if (dot(a, float4(1.0, 1.0, 1.0, 1.0)) < 1e-5) {
        float4 color = SMAASampleLevelZero(colorTex, texcoord);

        #if SMAA_REPROJECTION
        float2 velocity = SMAA_DECODE_VELOCITY(SMAASampleLevelZero(velocityTex, texcoord));

        // Pack velocity into the alpha channel:
        color.a = sqrt(5.0 * length(velocity));
        #endif

        return color;
    } else {
        bool h = max(a.x, a.z) > max(a.y, a.w); // max(horizontal) > max(vertical)

        // Calculate the blending offsets:
        float4 blendingOffset = float4(0.0, a.y, 0.0, a.w);
        float2 blendingWeight = a.yw;
        SMAAMovc(bool4(h, h, h, h), blendingOffset, float4(a.x, 0.0, a.z, 0.0));
        SMAAMovc(bool2(h, h), blendingWeight, a.xz);
        blendingWeight /= dot(blendingWeight, float2(1.0, 1.0));

        // Calculate the texture coordinates:
        float4 blendingCoord = mad(blendingOffset, float4(SMAA_RT_METRICS.xy, -SMAA_RT_METRICS.xy), texcoord.xyxy);

        // We exploit bilinear filtering to mix current pixel with the chosen
        // neighbor:
        float4 color = blendingWeight.x * SMAASampleLevelZero(colorTex, blendingCoord.xy);
        color += blendingWeight.y * SMAASampleLevelZero(colorTex, blendingCoord.zw);

        #if SMAA_REPROJECTION
        // Antialias velocity for proper reprojection in a later stage:
        float2 velocity = blendingWeight.x * SMAA_DECODE_VELOCITY(SMAASampleLevelZero(velocityTex, blendingCoord.xy));
        velocity += blendingWeight.y * SMAA_DECODE_VELOCITY(SMAASampleLevelZero(velocityTex, blendingCoord.zw));

        // Pack velocity into the alpha channel:
        color.a = sqrt(5.0 * length(velocity));
        #endif

        return color;
    }
}

//-----------------------------------------------------------------------------
// Temporal Resolve Pixel Shader (Optional Pass)

float4 SMAAResolvePS(float2 texcoord,
                     SMAATexture2D(currentColorTex),
                     SMAATexture2D(previousColorTex)
                     #if SMAA_REPROJECTION
                     , SMAATexture2D(velocityTex)
                     #endif
                     ) {
    #if SMAA_REPROJECTION
    // Velocity is assumed to be calculated for motion blur, so we need to
    // inverse it for reprojection:
    float2 velocity = -SMAA_DECODE_VELOCITY(SMAASamplePoint(velocityTex, texcoord).rg);

    // Fetch current pixel:
    float4 current = SMAASamplePoint(currentColorTex, texcoord);

    // Reproject current coordinates and fetch previous pixel:
    float4 previous = SMAASamplePoint(previousColorTex, texcoord + velocity);

    // Attenuate the previous pixel if the velocity is different:
    float delta = abs(current.a * current.a - previous.a * previous.a) / 5.0;
    float weight = 0.5 * saturate(1.0 - sqrt(delta) * SMAA_REPROJECTION_WEIGHT_SCALE);

    // Blend the pixels according to the calculated weight:
    return lerp(current, previous, weight);
    #else
    // Just blend the pixels:
    float4 current = SMAASamplePoint(currentColorTex, texcoord);
    float4 previous = SMAASamplePoint(previousColorTex, texcoord);
    return lerp(current, previous, 0.5);
    #endif
}

//-----------------------------------------------------------------------------
// Separate Multisamples Pixel Shader (Optional Pass)

#ifdef SMAALoad
void SMAASeparatePS(float4 position,
                    float2 texcoord,
                    out float4 target0,
                    out float4 target1,
                    SMAATexture2DMS2(colorTexMS)) {
    int2 pos = int2(position.xy);
    target0 = SMAALoad(colorTexMS, pos, 0);
    target1 = SMAALoad(colorTexMS, pos, 1);
}
#endif

//-----------------------------------------------------------------------------
#endif // SMAA_INCLUDE_PS



#if !defined(__RESHADE__) || __RESHADE__ < 30000
	#error "ReShade 3.0+ is required to use this header file"
#endif

#ifndef RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
	#define RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN 0
#endif
#ifndef RESHADE_DEPTH_INPUT_IS_REVERSED
	#define RESHADE_DEPTH_INPUT_IS_REVERSED 1
#endif
#ifndef RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
	#define RESHADE_DEPTH_INPUT_IS_LOGARITHMIC 0
#endif

#ifndef RESHADE_DEPTH_MULTIPLIER
	#define RESHADE_DEPTH_MULTIPLIER 1
#endif
#ifndef RESHADE_DEPTH_LINEARIZATION_FAR_PLANE
	#define RESHADE_DEPTH_LINEARIZATION_FAR_PLANE 1000.0
#endif

// Above 1 expands coordinates, below 1 contracts and 1 is equal to no scaling on any axis
#ifndef RESHADE_DEPTH_INPUT_Y_SCALE
	#define RESHADE_DEPTH_INPUT_Y_SCALE 1
#endif
#ifndef RESHADE_DEPTH_INPUT_X_SCALE
	#define RESHADE_DEPTH_INPUT_X_SCALE 1
#endif
// An offset to add to the Y coordinate, (+) = move up, (-) = move down
#ifndef RESHADE_DEPTH_INPUT_Y_OFFSET
	#define RESHADE_DEPTH_INPUT_Y_OFFSET 0
#endif
#ifndef RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET
	#define RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET 0
#endif
// An offset to add to the X coordinate, (+) = move right, (-) = move left
#ifndef RESHADE_DEPTH_INPUT_X_OFFSET
	#define RESHADE_DEPTH_INPUT_X_OFFSET 0
#endif
#ifndef RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET
	#define RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET 0
#endif

#define BUFFER_PIXEL_SIZE float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define BUFFER_SCREEN_SIZE float2(BUFFER_WIDTH, BUFFER_HEIGHT)
#define BUFFER_ASPECT_RATIO (BUFFER_WIDTH * BUFFER_RCP_HEIGHT)

namespace ReShade
{
#if defined(__RESHADE_FXC__)
	float GetAspectRatio() { return BUFFER_WIDTH * BUFFER_RCP_HEIGHT; }
	float2 GetPixelSize() { return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT); }
	float2 GetScreenSize() { return float2(BUFFER_WIDTH, BUFFER_HEIGHT); }
	#define AspectRatio GetAspectRatio()
	#define PixelSize GetPixelSize()
	#define ScreenSize GetScreenSize()
#else
	// These are deprecated and will be removed eventually.
	static const float AspectRatio = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
	static const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
	static const float2 ScreenSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
#endif

	// Global textures and samplers
	texture BackBufferTex : COLOR;
	texture DepthBufferTex : DEPTH;

	sampler BackBuffer { Texture = BackBufferTex; };
	sampler DepthBuffer { Texture = DepthBufferTex; };

	// Helper functions
	float GetLinearizedDepth(float2 texcoord)
	{
#if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
		texcoord.y = 1.0 - texcoord.y;
#endif
		texcoord.x /= RESHADE_DEPTH_INPUT_X_SCALE;
		texcoord.y /= RESHADE_DEPTH_INPUT_Y_SCALE;
#if RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET
		texcoord.x -= RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET * BUFFER_RCP_WIDTH;
#else // Do not check RESHADE_DEPTH_INPUT_X_OFFSET, since it may be a decimal number, which the preprocessor cannot handle
		texcoord.x -= RESHADE_DEPTH_INPUT_X_OFFSET / 2.000000001;
#endif
#if RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET
		texcoord.y += RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET * BUFFER_RCP_HEIGHT;
#else
		texcoord.y += RESHADE_DEPTH_INPUT_Y_OFFSET / 2.000000001;
#endif
		float depth = tex2Dlod(DepthBuffer, float4(texcoord, 0, 0)).x * RESHADE_DEPTH_MULTIPLIER;

#if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
		const float C = 0.01;
		depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
#endif
#if RESHADE_DEPTH_INPUT_IS_REVERSED
		depth = 1.0 - depth;
#endif
		const float N = 1.0;
		depth /= RESHADE_DEPTH_LINEARIZATION_FAR_PLANE - depth * (RESHADE_DEPTH_LINEARIZATION_FAR_PLANE - N);

		return depth;
	}
}

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}


// Textures

texture depthTex < pooled = true; >
{ 
	Width = BUFFER_WIDTH;   
	Height = BUFFER_HEIGHT;   
	Format = R16F;  
};

texture edgesTex < pooled = true; >
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG8;
};
texture blendTex < pooled = true; >
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA8;
};

texture areaTex < source = "./Resources/AreaTex.png"; >
{
	Width = 160;
	Height = 560;
	Format = RG8;
};
texture searchTex < source = "./Resources/SearchTex.png"; >
{
	Width = 64;
	Height = 16;
	Format = R8;
};

// Samplers

sampler depthLinearSampler
{
	Texture = depthTex;
};

sampler colorGammaSampler
{
	Texture = ReShade::BackBufferTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Point; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler colorLinearSampler
{
	Texture = ReShade::BackBufferTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Point; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = true;
};
sampler edgesSampler
{
	Texture = edgesTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Linear; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler blendSampler
{
	Texture = blendTex;
	AddressU = Clamp; AddressV = Clamp;
	MipFilter = Linear; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler areaSampler
{
	Texture = areaTex;
	AddressU = Clamp; AddressV = Clamp; AddressW = Clamp;
	MipFilter = Linear; MinFilter = Linear; MagFilter = Linear;
	SRGBTexture = false;
};
sampler searchSampler
{
	Texture = searchTex;
	AddressU = Clamp; AddressV = Clamp; AddressW = Clamp;
	MipFilter = Point; MinFilter = Point; MagFilter = Point;
	SRGBTexture = false;
};

// Vertex shaders

void SMAAEdgeDetectionWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float4 offset[3] : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	SMAAEdgeDetectionVS(texcoord, offset);
}
void SMAABlendingWeightCalculationWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float2 pixcoord : TEXCOORD1,
	out float4 offset[3] : TEXCOORD2)
{
	PostProcessVS(id, position, texcoord);
	SMAABlendingWeightCalculationVS(texcoord, pixcoord, offset);
}
void SMAANeighborhoodBlendingWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float4 offset : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	SMAANeighborhoodBlendingVS(texcoord, offset);
}

// Pixel shaders

float SMAADepthLinearizationPS(
	float4 position : SV_Position,
	float2 texcoord : TEXCOORD) : SV_Target
{
	return ReShade::GetLinearizedDepth(texcoord);
}

float2 SMAAEdgeDetectionWrapPS(
	float4 position : SV_Position,
	float2 texcoord : TEXCOORD0,
	float4 offset[3] : TEXCOORD1) : SV_Target
{
	if (EdgeDetectionType == 0 && SMAA_PREDICATION == true)
		return SMAALumaEdgePredicationDetectionPS(texcoord, offset, colorGammaSampler, depthLinearSampler);
	else if (EdgeDetectionType == 0)
		return SMAALumaEdgeDetectionPS(texcoord, offset, colorGammaSampler);

	if (EdgeDetectionType == 2)
		return SMAADepthEdgeDetectionPS(texcoord, offset, depthLinearSampler);

	if (SMAA_PREDICATION)
		return SMAAColorEdgePredicationDetectionPS(texcoord, offset, colorGammaSampler, depthLinearSampler);
	else
		return SMAAColorEdgeDetectionPS(texcoord, offset, colorGammaSampler);
}
float4 SMAABlendingWeightCalculationWrapPS(
	float4 position : SV_Position,
	float2 texcoord : TEXCOORD0,
	float2 pixcoord : TEXCOORD1,
	float4 offset[3] : TEXCOORD2) : SV_Target
{
	return SMAABlendingWeightCalculationPS(texcoord, pixcoord, offset, edgesSampler, areaSampler, searchSampler, 0.0);
}

float3 SMAANeighborhoodBlendingWrapPS(
	float4 position : SV_Position,
	float2 texcoord : TEXCOORD0,
	float4 offset : TEXCOORD1) : SV_Target
{
	if (DebugOutput == 1)
		return tex2D(edgesSampler, texcoord).rgb;
	if (DebugOutput == 2)
		return tex2D(blendSampler, texcoord).rgb;

	return SMAANeighborhoodBlendingPS(texcoord, offset, colorLinearSampler, blendSampler).rgb;
}

// Rendering passes

technique SMAA
{
	pass LinearizeDepthPass
	{
		VertexShader = PostProcessVS;
		PixelShader = SMAADepthLinearizationPS;
		RenderTarget = depthTex;
	}
	pass EdgeDetectionPass
	{
		VertexShader = SMAAEdgeDetectionWrapVS;
		PixelShader = SMAAEdgeDetectionWrapPS;
		RenderTarget = edgesTex;
		ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = REPLACE;
		StencilRef = 1;
	}
	pass BlendWeightCalculationPass
	{
		VertexShader = SMAABlendingWeightCalculationWrapVS;
		PixelShader = SMAABlendingWeightCalculationWrapPS;
		RenderTarget = blendTex;
		ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = KEEP;
		StencilFunc = EQUAL;
		StencilRef = 1;
	}
	pass NeighborhoodBlendingPass
	{
		VertexShader = SMAANeighborhoodBlendingWrapVS;
		PixelShader = SMAANeighborhoodBlendingWrapPS;
		StencilEnable = false;
		SRGBWriteEnable = true;
	}
}
