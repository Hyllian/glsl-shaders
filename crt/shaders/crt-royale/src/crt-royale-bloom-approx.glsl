#version 130

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA

// compatibility macros for transparently converting HLSLisms into GLSLisms
#define mul(a,b) (b*a)
#define lerp(a,b,c) mix(a,b,c)
#define saturate(c) clamp(c, 0.0, 1.0)
#define frac(x) (fract(x))
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define bool2 bvec2
#define bool3 bvec3
#define bool4 bvec4
#define float2x2 mat2x2
#define float3x3 mat3x3
#define float4x4 mat4x4
#define float4x3 mat4x3
#define float2x4 mat2x4
#define IN params
#define texture_size TextureSize.xy
#define video_size InputSize.xy
#define output_size OutputSize.xy
#define frame_count FrameCount
#define static  
#define inline  
#define const  
#define fmod(x,y) mod(x,y)
#define ddx(c) dFdx(c)
#define ddy(c) dFdy(c)
#define atan2(x,y) atan(y,x)
#define rsqrt(c) inversesqrt(c)

#define ORIG_LINEARIZEDvideo_size PassPrev2InputSize.xy
#define ORIG_LINEARIZEDtexture_size PassPrev2TextureSize.xy

#if defined(GL_ES)
	#define COMPAT_PRECISION mediump
#else
	#define COMPAT_PRECISION
#endif

#if __VERSION__ >= 130
	#define COMPAT_TEXTURE texture
#else
	#define COMPAT_TEXTURE texture2D
#endif

///////////////////////////////  VERTEX INCLUDES  ///////////////////////////////

//#include "../include/user-settings.h"
/***************** BEGIN user-settings.h ******************/

#ifndef USER_SETTINGS_H
#define USER_SETTINGS_H

/////////////////////////////  DRIVER CAPABILITIES  ////////////////////////////

//  The Cg compiler uses different "profiles" with different capabilities.
//  This shader requires a Cg compilation profile >= arbfp1, but a few options
//  require higher profiles like fp30 or fp40.  The shader can't detect profile
//  or driver capabilities, so instead you must comment or uncomment the lines
//  below with "//" before "#define."  Disable an option if you get compilation
//  errors resembling those listed.  Generally speaking, all of these options
//  will run on nVidia cards, but only DRIVERS_ALLOW_TEX2DBIAS (if that) is
//  likely to run on ATI/AMD, due to the Cg compiler's profile limitations.

//  Derivatives: Unsupported on fp20, ps_1_1, ps_1_2, ps_1_3, and arbfp1.
//  Among other things, derivatives help us fix anisotropic filtering artifacts
//  with curved manually tiled phosphor mask coords.  Related errors:
//  error C3004: function "float2 ddx(float2);" not supported in this profile
//  error C3004: function "float2 ddy(float2);" not supported in this profile
    //#define DRIVERS_ALLOW_DERIVATIVES

//  Fine derivatives: Unsupported on older ATI cards.
//  Fine derivatives enable 2x2 fragment block communication, letting us perform
//  fast single-pass blur operations.  If your card uses coarse derivatives and
//  these are enabled, blurs could look broken.  Derivatives are a prerequisite.
    #ifdef DRIVERS_ALLOW_DERIVATIVES
        #define DRIVERS_ALLOW_FINE_DERIVATIVES
    #endif

//  Dynamic looping: Requires an fp30 or newer profile.
//  This makes phosphor mask resampling faster in some cases.  Related errors:
//  error C5013: profile does not support "for" statements and "for" could not
//  be unrolled
    //#define DRIVERS_ALLOW_DYNAMIC_BRANCHES

//  Without DRIVERS_ALLOW_DYNAMIC_BRANCHES, we need to use unrollable loops.
//  Using one static loop avoids overhead if the user is right, but if the user
//  is wrong (loops are allowed), breaking a loop into if-blocked pieces with a
//  binary search can potentially save some iterations.  However, it may fail:
//  error C6001: Temporary register limit of 32 exceeded; 35 registers
//  needed to compile program
    //#define ACCOMODATE_POSSIBLE_DYNAMIC_LOOPS

//  tex2Dlod: Requires an fp40 or newer profile.  This can be used to disable
//  anisotropic filtering, thereby fixing related artifacts.  Related errors:
//  error C3004: function "float4 tex2Dlod(sampler2D, float4);" not supported in
//  this profile
    //#define DRIVERS_ALLOW_TEX2DLOD

//  tex2Dbias: Requires an fp30 or newer profile.  This can be used to alleviate
//  artifacts from anisotropic filtering and mipmapping.  Related errors:
//  error C3004: function "float4 tex2Dbias(sampler2D, float4);" not supported
//  in this profile
    //#define DRIVERS_ALLOW_TEX2DBIAS

//  Integrated graphics compatibility: Integrated graphics like Intel HD 4000
//  impose stricter limitations on register counts and instructions.  Enable
//  INTEGRATED_GRAPHICS_COMPATIBILITY_MODE if you still see error C6001 or:
//  error C6002: Instruction limit of 1024 exceeded: 1523 instructions needed
//  to compile program.
//  Enabling integrated graphics compatibility mode will automatically disable:
//  1.) PHOSPHOR_MASK_MANUALLY_RESIZE: The phosphor mask will be softer.
//      (This may be reenabled in a later release.)
//  2.) RUNTIME_GEOMETRY_MODE
//  3.) The high-quality 4x4 Gaussian resize for the bloom approximation
    //#define INTEGRATED_GRAPHICS_COMPATIBILITY_MODE


////////////////////////////  USER CODEPATH OPTIONS  ///////////////////////////

//  To disable a #define option, turn its line into a comment with "//."

//  RUNTIME VS. COMPILE-TIME OPTIONS (Major Performance Implications):
//  Enable runtime shader parameters in the Retroarch (etc.) GUI?  They override
//  many of the options in this file and allow real-time tuning, but many of
//  them are slower.  Disabling them and using this text file will boost FPS.
#define RUNTIME_SHADER_PARAMS_ENABLE
//  Specify the phosphor bloom sigma at runtime?  This option is 10% slower, but
//  it's the only way to do a wide-enough full bloom with a runtime dot pitch.
#define RUNTIME_PHOSPHOR_BLOOM_SIGMA
//  Specify antialiasing weight parameters at runtime?  (Costs ~20% with cubics)
#define RUNTIME_ANTIALIAS_WEIGHTS
//  Specify subpixel offsets at runtime? (WARNING: EXTREMELY EXPENSIVE!)
//#define RUNTIME_ANTIALIAS_SUBPIXEL_OFFSETS
//  Make beam_horiz_filter and beam_horiz_linear_rgb_weight into runtime shader
//  parameters?  This will require more math or dynamic branching.
#define RUNTIME_SCANLINES_HORIZ_FILTER_COLORSPACE
//  Specify the tilt at runtime?  This makes things about 3% slower.
#define RUNTIME_GEOMETRY_TILT
//  Specify the geometry mode at runtime?
#define RUNTIME_GEOMETRY_MODE
//  Specify the phosphor mask type (aperture grille, slot mask, shadow mask) and
//  mode (Lanczos-resize, hardware resize, or tile 1:1) at runtime, even without
//  dynamic branches?  This is cheap if mask_resize_viewport_scale is small.
#define FORCE_RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT

//  PHOSPHOR MASK:
//  Manually resize the phosphor mask for best results (slower)?  Disabling this
//  removes the option to do so, but it may be faster without dynamic branches.
    #define PHOSPHOR_MASK_MANUALLY_RESIZE
//  If we sinc-resize the mask, should we Lanczos-window it (slower but better)?
    #define PHOSPHOR_MASK_RESIZE_LANCZOS_WINDOW
//  Larger blurs are expensive, but we need them to blur larger triads.  We can
//  detect the right blur if the triad size is static or our profile allows
//  dynamic branches, but otherwise we use the largest blur the user indicates
//  they might need:
    #define PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
    //#define PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
    //#define PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
    //#define PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
    //  Here's a helpful chart:
    //  MaxTriadSize    BlurSize    MinTriadCountsByResolution
    //  3.0             9.0         480/640/960/1920 triads at 1080p/1440p/2160p/4320p, 4:3 aspect
    //  6.0             17.0        240/320/480/960 triads at 1080p/1440p/2160p/4320p, 4:3 aspect
    //  9.0             25.0        160/213/320/640 triads at 1080p/1440p/2160p/4320p, 4:3 aspect
    //  12.0            31.0        120/160/240/480 triads at 1080p/1440p/2160p/4320p, 4:3 aspect
    //  18.0            43.0        80/107/160/320 triads at 1080p/1440p/2160p/4320p, 4:3 aspect


///////////////////////////////  USER PARAMETERS  //////////////////////////////

//  Note: Many of these static parameters are overridden by runtime shader
//  parameters when those are enabled.  However, many others are static codepath
//  options that were cleaner or more convert to code as static constants.

//  GAMMA:
    static const float crt_gamma_static = 2.5;                  //  range [1, 5]
    static const float lcd_gamma_static = 2.2;                  //  range [1, 5]

//  LEVELS MANAGEMENT:
    //  Control the final multiplicative image contrast:
    static const float levels_contrast_static = 1.0;            //  range [0, 4)
    //  We auto-dim to avoid clipping between passes and restore brightness
    //  later.  Control the dim factor here: Lower values clip less but crush
    //  blacks more (static only for now).
    static const float levels_autodim_temp = 0.5;               //  range (0, 1] default is 0.5 but that was unnecessarily dark for me, so I set it to 1.0

//  HALATION/DIFFUSION/BLOOM:
    //  Halation weight: How much energy should be lost to electrons bounding
    //  around under the CRT glass and exciting random phosphors?
    static const float halation_weight_static = 0.0;            //  range [0, 1]
    //  Refractive diffusion weight: How much light should spread/diffuse from
    //  refracting through the CRT glass?
    static const float diffusion_weight_static = 0.075;         //  range [0, 1]
    //  Underestimate brightness: Bright areas bloom more, but we can base the
    //  bloom brightpass on a lower brightness to sharpen phosphors, or a higher
    //  brightness to soften them.  Low values clip, but >= 0.8 looks okay.
    static const float bloom_underestimate_levels_static = 0.8; //  range [0, 5]
    //  Blur all colors more than necessary for a softer phosphor bloom?
    static const float bloom_excess_static = 0.0;               //  range [0, 1]
    //  The BLOOM_APPROX pass approximates a phosphor blur early on with a small
    //  blurred resize of the input (convergence offsets are applied as well).
    //  There are three filter options (static option only for now):
    //  0.) Bilinear resize: A fast, close approximation to a 4x4 resize
    //      if min_allowed_viewport_triads and the BLOOM_APPROX resolution are sane
    //      and beam_max_sigma is low.
    //  1.) 3x3 resize blur: Medium speed, soft/smeared from bilinear blurring,
    //      always uses a static sigma regardless of beam_max_sigma or
    //      mask_num_triads_desired.
    //  2.) True 4x4 Gaussian resize: Slowest, technically correct.
    //  These options are more pronounced for the fast, unbloomed shader version.
#ifndef RADEON_FIX
    static const float bloom_approx_filter_static = 2.0;
#else
    static const float bloom_approx_filter_static = 1.0;
#endif

//  ELECTRON BEAM SCANLINE DISTRIBUTION:
    //  How many scanlines should contribute light to each pixel?  Using more
    //  scanlines is slower (especially for a generalized Gaussian) but less
    //  distorted with larger beam sigmas (especially for a pure Gaussian).  The
    //  max_beam_sigma at which the closest unused weight is guaranteed <
    //  1.0/255.0 (for a 3x antialiased pure Gaussian) is:
    //      2 scanlines: max_beam_sigma = 0.2089; distortions begin ~0.34; 141.7 FPS pure, 131.9 FPS generalized
    //      3 scanlines, max_beam_sigma = 0.3879; distortions begin ~0.52; 137.5 FPS pure; 123.8 FPS generalized
    //      4 scanlines, max_beam_sigma = 0.5723; distortions begin ~0.70; 134.7 FPS pure; 117.2 FPS generalized
    //      5 scanlines, max_beam_sigma = 0.7591; distortions begin ~0.89; 131.6 FPS pure; 112.1 FPS generalized
    //      6 scanlines, max_beam_sigma = 0.9483; distortions begin ~1.08; 127.9 FPS pure; 105.6 FPS generalized
    static const float beam_num_scanlines = 3.0;                //  range [2, 6]
    //  A generalized Gaussian beam varies shape with color too, now just width.
    //  It's slower but more flexible (static option only for now).
    static const bool beam_generalized_gaussian = true;
    //  What kind of scanline antialiasing do you want?
    //  0: Sample weights at 1x; 1: Sample weights at 3x; 2: Compute an integral
    //  Integrals are slow (especially for generalized Gaussians) and rarely any
    //  better than 3x antialiasing (static option only for now).
    static const float beam_antialias_level = 1.0;              //  range [0, 2]
    //  Min/max standard deviations for scanline beams: Higher values widen and
    //  soften scanlines.  Depending on other options, low min sigmas can alias.
    static const float beam_min_sigma_static = 0.02;            //  range (0, 1]
    static const float beam_max_sigma_static = 0.3;             //  range (0, 1]
    //  Beam width varies as a function of color: A power function (0) is more
    //  configurable, but a spherical function (1) gives the widest beam
    //  variability without aliasing (static option only for now).
    static const float beam_spot_shape_function = 0.0;
    //  Spot shape power: Powers <= 1 give smoother spot shapes but lower
    //  sharpness.  Powers >= 1.0 are awful unless mix/max sigmas are close.
    static const float beam_spot_power_static = 1.0/3.0;    //  range (0, 16]
    //  Generalized Gaussian max shape parameters: Higher values give flatter
    //  scanline plateaus and steeper dropoffs, simultaneously widening and
    //  sharpening scanlines at the cost of aliasing.  2.0 is pure Gaussian, and
    //  values > ~40.0 cause artifacts with integrals.
    static const float beam_min_shape_static = 2.0;         //  range [2, 32]
    static const float beam_max_shape_static = 4.0;         //  range [2, 32]
    //  Generalized Gaussian shape power: Affects how quickly the distribution
    //  changes shape from Gaussian to steep/plateaued as color increases from 0
    //  to 1.0.  Higher powers appear softer for most colors, and lower powers
    //  appear sharper for most colors.
    static const float beam_shape_power_static = 1.0/4.0;   //  range (0, 16]
    //  What filter should be used to sample scanlines horizontally?
    //  0: Quilez (fast), 1: Gaussian (configurable), 2: Lanczos2 (sharp)
    static const float beam_horiz_filter_static = 0.0;
    //  Standard deviation for horizontal Gaussian resampling:
    static const float beam_horiz_sigma_static = 0.35;      //  range (0, 2/3]
    //  Do horizontal scanline sampling in linear RGB (correct light mixing),
    //  gamma-encoded RGB (darker, hard spot shape, may better match bandwidth-
    //  limiting circuitry in some CRT's), or a weighted avg.?
    static const float beam_horiz_linear_rgb_weight_static = 1.0;   //  range [0, 1]
    //  Simulate scanline misconvergence?  This needs 3x horizontal texture
    //  samples and 3x texture samples of BLOOM_APPROX and HALATION_BLUR in
    //  later passes (static option only for now).
    static const bool beam_misconvergence = true;
    //  Convergence offsets in x/y directions for R/G/B scanline beams in units
    //  of scanlines.  Positive offsets go right/down; ranges [-2, 2]
    static const float2 convergence_offsets_r_static = float2(0.1, 0.2);
    static const float2 convergence_offsets_g_static = float2(0.3, 0.4);
    static const float2 convergence_offsets_b_static = float2(0.5, 0.6);
    //  Detect interlacing (static option only for now)?
    static const bool interlace_detect = true;
    //  Assume 1080-line sources are interlaced?
    static const bool interlace_1080i_static = false;
    //  For interlaced sources, assume TFF (top-field first) or BFF order?
    //  (Whether this matters depends on the nature of the interlaced input.)
    static const bool interlace_bff_static = false;

//  ANTIALIASING:
    //  What AA level do you want for curvature/overscan/subpixels?  Options:
    //  0x (none), 1x (sample subpixels), 4x, 5x, 6x, 7x, 8x, 12x, 16x, 20x, 24x
    //  (Static option only for now)
    static const float aa_level = 12.0;                     //  range [0, 24]
    //  What antialiasing filter do you want (static option only)?  Options:
    //  0: Box (separable), 1: Box (cylindrical),
    //  2: Tent (separable), 3: Tent (cylindrical),
    //  4: Gaussian (separable), 5: Gaussian (cylindrical),
    //  6: Cubic* (separable), 7: Cubic* (cylindrical, poor)
    //  8: Lanczos Sinc (separable), 9: Lanczos Jinc (cylindrical, poor)
    //      * = Especially slow with RUNTIME_ANTIALIAS_WEIGHTS
    static const float aa_filter = 6.0;                     //  range [0, 9]
    //  Flip the sample grid on odd/even frames (static option only for now)?
    static const bool aa_temporal = false;
    //  Use RGB subpixel offsets for antialiasing?  The pixel is at green, and
    //  the blue offset is the negative r offset; range [0, 0.5]
    static const float2 aa_subpixel_r_offset_static = float2(-1.0/3.0, 0.0);//float2(0.0);
    //  Cubics: See http://www.imagemagick.org/Usage/filter/#mitchell
    //  1.) "Keys cubics" with B = 1 - 2C are considered the highest quality.
    //  2.) C = 0.5 (default) is Catmull-Rom; higher C's apply sharpening.
    //  3.) C = 1.0/3.0 is the Mitchell-Netravali filter.
    //  4.) C = 0.0 is a soft spline filter.
    static const float aa_cubic_c_static = 0.5;             //  range [0, 4]
    //  Standard deviation for Gaussian antialiasing: Try 0.5/aa_pixel_diameter.
    static const float aa_gauss_sigma_static = 0.5;     //  range [0.0625, 1.0]

//  PHOSPHOR MASK:
    //  Mask type: 0 = aperture grille, 1 = slot mask, 2 = EDP shadow mask
    static const float mask_type_static = 1.0;                  //  range [0, 2]
    //  We can sample the mask three ways.  Pick 2/3 from: Pretty/Fast/Flexible.
    //  0.) Sinc-resize to the desired dot pitch manually (pretty/slow/flexible).
    //      This requires PHOSPHOR_MASK_MANUALLY_RESIZE to be #defined.
    //  1.) Hardware-resize to the desired dot pitch (ugly/fast/flexible).  This
    //      is halfway decent with LUT mipmapping but atrocious without it.
    //  2.) Tile it without resizing at a 1:1 texel:pixel ratio for flat coords
    //      (pretty/fast/inflexible).  Each input LUT has a fixed dot pitch.
    //      This mode reuses the same masks, so triads will be enormous unless
    //      you change the mask LUT filenames in your .cgp file.
    static const float mask_sample_mode_static = 0.0;           //  range [0, 2]
    //  Prefer setting the triad size (0.0) or number on the screen (1.0)?
    //  If RUNTIME_PHOSPHOR_BLOOM_SIGMA isn't #defined, the specified triad size
    //  will always be used to calculate the full bloom sigma statically.
    static const float mask_specify_num_triads_static = 0.0;    //  range [0, 1]
    //  Specify the phosphor triad size, in pixels.  Each tile (usually with 8
    //  triads) will be rounded to the nearest integer tile size and clamped to
    //  obey minimum size constraints (imposed to reduce downsize taps) and
    //  maximum size constraints (imposed to have a sane MASK_RESIZE FBO size).
    //  To increase the size limit, double the viewport-relative scales for the
    //  two MASK_RESIZE passes in crt-royale.cgp and user-cgp-contants.h.
    //      range [1, mask_texture_small_size/mask_triads_per_tile]
    static const float mask_triad_size_desired_static = 24.0 / 8.0;
    //  If mask_specify_num_triads is 1.0/true, we'll go by this instead (the
    //  final size will be rounded and constrained as above); default 480.0
    static const float mask_num_triads_desired_static = 480.0;
    //  How many lobes should the sinc/Lanczos resizer use?  More lobes require
    //  more samples and avoid moire a bit better, but some is unavoidable
    //  depending on the destination size (static option for now).
    static const float mask_sinc_lobes = 3.0;                   //  range [2, 4]
    //  The mask is resized using a variable number of taps in each dimension,
    //  but some Cg profiles always fetch a constant number of taps no matter
    //  what (no dynamic branching).  We can limit the maximum number of taps if
    //  we statically limit the minimum phosphor triad size.  Larger values are
    //  faster, but the limit IS enforced (static option only, forever);
    //      range [1, mask_texture_small_size/mask_triads_per_tile]
    //  TODO: Make this 1.0 and compensate with smarter sampling!
    static const float mask_min_allowed_triad_size = 2.0;

//  GEOMETRY:
    //  Geometry mode:
    //  0: Off (default), 1: Spherical mapping (like cgwg's),
    //  2: Alt. spherical mapping (more bulbous), 3: Cylindrical/Trinitron
    static const float geom_mode_static = 0.0;      //  range [0, 3]
    //  Radius of curvature: Measured in units of your viewport's diagonal size.
    static const float geom_radius_static = 2.0;    //  range [1/(2*pi), 1024]
    //  View dist is the distance from the player to their physical screen, in
    //  units of the viewport's diagonal size.  It controls the field of view.
    static const float geom_view_dist_static = 2.0; //  range [0.5, 1024]
    //  Tilt angle in radians (clockwise around up and right vectors):
    static const float2 geom_tilt_angle_static = float2(0.0, 0.0);  //  range [-pi, pi]
    //  Aspect ratio: When the true viewport size is unknown, this value is used
    //  to help convert between the phosphor triad size and count, along with
    //  the mask_resize_viewport_scale constant from user-cgp-constants.h.  Set
    //  this equal to Retroarch's display aspect ratio (DAR) for best results;
    //  range [1, geom_max_aspect_ratio from user-cgp-constants.h];
    //  default (256/224)*(54/47) = 1.313069909 (see below)
    static const float geom_aspect_ratio_static = 1.313069909;
    //  Before getting into overscan, here's some general aspect ratio info:
    //  - DAR = display aspect ratio = SAR * PAR; as in your Retroarch setting
    //  - SAR = storage aspect ratio = DAR / PAR; square pixel emulator frame AR
    //  - PAR = pixel aspect ratio   = DAR / SAR; holds regardless of cropping
    //  Geometry processing has to "undo" the screen-space 2D DAR to calculate
    //  3D view vectors, then reapplies the aspect ratio to the simulated CRT in
    //  uv-space.  To ensure the source SAR is intended for a ~4:3 DAR, either:
    //  a.) Enable Retroarch's "Crop Overscan"
    //  b.) Readd horizontal padding: Set overscan to e.g. N*(1.0, 240.0/224.0)
    //  Real consoles use horizontal black padding in the signal, but emulators
    //  often crop this without cropping the vertical padding; a 256x224 [S]NES
    //  frame (8:7 SAR) is intended for a ~4:3 DAR, but a 256x240 frame is not.
    //  The correct [S]NES PAR is 54:47, found by blargg and NewRisingSun:
    //      http://board.zsnes.com/phpBB3/viewtopic.php?f=22&t=11928&start=50
    //      http://forums.nesdev.com/viewtopic.php?p=24815#p24815
    //  For flat output, it's okay to set DAR = [existing] SAR * [correct] PAR
    //  without doing a. or b., but horizontal image borders will be tighter
    //  than vertical ones, messing up curvature and overscan.  Fixing the
    //  padding first corrects this.
    //  Overscan: Amount to "zoom in" before cropping.  You can zoom uniformly
    //  or adjust x/y independently to e.g. readd horizontal padding, as noted
    //  above: Values < 1.0 zoom out; range (0, inf)
    static const float2 geom_overscan_static = float2(1.0, 1.0);// * 1.005 * (1.0, 240/224.0)
    //  Compute a proper pixel-space to texture-space matrix even without ddx()/
    //  ddy()?  This is ~8.5% slower but improves antialiasing/subpixel filtering
    //  with strong curvature (static option only for now).
    static const bool geom_force_correct_tangent_matrix = true;

//  BORDERS:
    //  Rounded border size in texture uv coords:
    static const float border_size_static = 0.015;           //  range [0, 0.5]
    //  Border darkness: Moderate values darken the border smoothly, and high
    //  values make the image very dark just inside the border:
    static const float border_darkness_static = 2.0;        //  range [0, inf)
    //  Border compression: High numbers compress border transitions, narrowing
    //  the dark border area.
    static const float border_compress_static = 2.5;        //  range [1, inf)


#endif  //  USER_SETTINGS_H

/***************** END user-settings.h ******************/

//#include "../include/bind-shader-params.h"
/***************** BEGIN bind-shader-params.h ******************/

/////////////////////////////  BEGIN BIND-SHADER-PARAMS  ////////////////////////////

#ifndef BIND_SHADER_PARAMS_H
#define BIND_SHADER_PARAMS_H

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA


/////////////////////////////  SETTINGS MANAGEMENT  ////////////////////////////

///////////////////////////////  BEGIN INCLUDES  ///////////////////////////////

//#include "../include/user-settings.h"
//#include "../include/derived-settings-and-constants.h"
/***************** BEGIN derived-settings-and-constants.h ******************/

////////////////////  BEGIN DERIVED-SETTINGS-AND-CONSTANTS  ////////////////////

#ifndef DERIVED_SETTINGS_AND_CONSTANTS_H
#define DERIVED_SETTINGS_AND_CONSTANTS_H

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA


/////////////////////////////////  DESCRIPTION  ////////////////////////////////

//  These macros and constants can be used across the whole codebase.
//  Unlike the values in user-settings.cgh, end users shouldn't modify these.


///////////////////////////////  BEGIN INCLUDES  ///////////////////////////////

//#include "../include/user-settings.h"
//#include "../include/user-cgp-constants.h"
/***************** BEGIN user-cgp-constants.h ******************/

#ifndef USER_CGP_CONSTANTS_H
#define USER_CGP_CONSTANTS_H

//  IMPORTANT:
//  These constants MUST be set appropriately for the settings in crt-royale.cgp
//  (or whatever related .cgp file you're using).  If they aren't, you're likely
//  to get artifacts, the wrong phosphor mask size, etc.  I wish these could be
//  set directly in the .cgp file to make things easier, but...they can't.

//  PASS SCALES AND RELATED CONSTANTS:
//  Copy the absolute scale_x for BLOOM_APPROX.  There are two major versions of
//  this shader: One does a viewport-scale bloom, and the other skips it.  The
//  latter benefits from a higher bloom_approx_scale_x, so save both separately:
static const float bloom_approx_size_x = 320.0;
static const float bloom_approx_size_x_for_fake = 400.0;
//  Copy the viewport-relative scales of the phosphor mask resize passes
//  (MASK_RESIZE and the pass immediately preceding it):
static const float2 mask_resize_viewport_scale = float2(0.0625, 0.0625);
//  Copy the geom_max_aspect_ratio used to calculate the MASK_RESIZE scales, etc.:
static const float geom_max_aspect_ratio = 4.0/3.0;

//  PHOSPHOR MASK TEXTURE CONSTANTS:
//  Set the following constants to reflect the properties of the phosphor mask
//  texture named in crt-royale.cgp.  The shader optionally resizes a mask tile
//  based on user settings, then repeats a single tile until filling the screen.
//  The shader must know the input texture size (default 64x64), and to manually
//  resize, it must also know the horizontal triads per tile (default 8).
static const float2 mask_texture_small_size = float2(64.0, 64.0);
static const float2 mask_texture_large_size = float2(512.0, 512.0);
static const float mask_triads_per_tile = 8.0;
//  We need the average brightness of the phosphor mask to compensate for the
//  dimming it causes.  The following four values are roughly correct for the
//  masks included with the shader.  Update the value for any LUT texture you
//  change.  [Un]comment "#define PHOSPHOR_MASK_GRILLE14" depending on whether
//  the loaded aperture grille uses 14-pixel or 15-pixel stripes (default 15).
//#define PHOSPHOR_MASK_GRILLE14
static const float mask_grille14_avg_color = 50.6666666/255.0;
    //  TileableLinearApertureGrille14Wide7d33Spacing*.png
    //  TileableLinearApertureGrille14Wide10And6Spacing*.png
static const float mask_grille15_avg_color = 53.0/255.0;
    //  TileableLinearApertureGrille15Wide6d33Spacing*.png
    //  TileableLinearApertureGrille15Wide8And5d5Spacing*.png
static const float mask_slot_avg_color = 46.0/255.0;
    //  TileableLinearSlotMask15Wide9And4d5Horizontal8VerticalSpacing*.png
    //  TileableLinearSlotMaskTall15Wide9And4d5Horizontal9d14VerticalSpacing*.png
static const float mask_shadow_avg_color = 41.0/255.0;
    //  TileableLinearShadowMask*.png
    //  TileableLinearShadowMaskEDP*.png

#ifdef PHOSPHOR_MASK_GRILLE14
    static const float mask_grille_avg_color = mask_grille14_avg_color;
#else
    static const float mask_grille_avg_color = mask_grille15_avg_color;
#endif


#endif  //  USER_CGP_CONSTANTS_H

/***************** END user-cgp-constants.h ******************/


////////////////////////////////  END INCLUDES  ////////////////////////////////

///////////////////////////////  FIXED SETTINGS  ///////////////////////////////

//  Avoid dividing by zero; using a macro overloads for float, float2, etc.:
#define FIX_ZERO(c) (max(abs(c), 0.0000152587890625))   //  2^-16

//  Ensure the first pass decodes CRT gamma and the last encodes LCD gamma.
#ifndef SIMULATE_CRT_ON_LCD
    #define SIMULATE_CRT_ON_LCD
#endif

//  Manually tiling a manually resized texture creates texture coord derivative
//  discontinuities and confuses anisotropic filtering, causing discolored tile
//  seams in the phosphor mask.  Workarounds:
//  a.) Using tex2Dlod disables anisotropic filtering for tiled masks.  It's
//      downgraded to tex2Dbias without DRIVERS_ALLOW_TEX2DLOD #defined and
//      disabled without DRIVERS_ALLOW_TEX2DBIAS #defined either.
//  b.) "Tile flat twice" requires drawing two full tiles without border padding
//      to the resized mask FBO, and it's incompatible with same-pass curvature.
//      (Same-pass curvature isn't used but could be in the future...maybe.)
//  c.) "Fix discontinuities" requires derivatives and drawing one tile with
//      border padding to the resized mask FBO, but it works with same-pass
//      curvature.  It's disabled without DRIVERS_ALLOW_DERIVATIVES #defined.
//  Precedence: a, then, b, then c (if multiple strategies are #defined).
    #define ANISOTROPIC_TILING_COMPAT_TEX2DLOD              //  129.7 FPS, 4x, flat; 101.8 at fullscreen
    #define ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE       //  128.1 FPS, 4x, flat; 101.5 at fullscreen
    #define ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES   //  124.4 FPS, 4x, flat; 97.4 at fullscreen
//  Also, manually resampling the phosphor mask is slightly blurrier with
//  anisotropic filtering.  (Resampling with mipmapping is even worse: It
//  creates artifacts, but only with the fully bloomed shader.)  The difference
//  is subtle with small triads, but you can fix it for a small cost.
    //#define ANISOTROPIC_RESAMPLING_COMPAT_TEX2DLOD


//////////////////////////////  DERIVED SETTINGS  //////////////////////////////

//  Intel HD 4000 GPU's can't handle manual mask resizing (for now), setting the
//  geometry mode at runtime, or a 4x4 true Gaussian resize.  Disable
//  incompatible settings ASAP.  (INTEGRATED_GRAPHICS_COMPATIBILITY_MODE may be
//  #defined by either user-settings.h or a wrapper .cg that #includes the
//  current .cg pass.)
#ifdef INTEGRATED_GRAPHICS_COMPATIBILITY_MODE
    #ifdef PHOSPHOR_MASK_MANUALLY_RESIZE
        #undef PHOSPHOR_MASK_MANUALLY_RESIZE
    #endif
    #ifdef RUNTIME_GEOMETRY_MODE
        #undef RUNTIME_GEOMETRY_MODE
    #endif
    //  Mode 2 (4x4 Gaussian resize) won't work, and mode 1 (3x3 blur) is
    //  inferior in most cases, so replace 2.0 with 0.0:
    static const float bloom_approx_filter =
        bloom_approx_filter_static > 1.5 ? 0.0 : bloom_approx_filter_static;
#else
    static const float bloom_approx_filter = bloom_approx_filter_static;
#endif

//  Disable slow runtime paths if static parameters are used.  Most of these
//  won't be a problem anyway once the params are disabled, but some will.
#ifndef RUNTIME_SHADER_PARAMS_ENABLE
    #ifdef RUNTIME_PHOSPHOR_BLOOM_SIGMA
        #undef RUNTIME_PHOSPHOR_BLOOM_SIGMA
    #endif
    #ifdef RUNTIME_ANTIALIAS_WEIGHTS
        #undef RUNTIME_ANTIALIAS_WEIGHTS
    #endif
    #ifdef RUNTIME_ANTIALIAS_SUBPIXEL_OFFSETS
        #undef RUNTIME_ANTIALIAS_SUBPIXEL_OFFSETS
    #endif
    #ifdef RUNTIME_SCANLINES_HORIZ_FILTER_COLORSPACE
        #undef RUNTIME_SCANLINES_HORIZ_FILTER_COLORSPACE
    #endif
    #ifdef RUNTIME_GEOMETRY_TILT
        #undef RUNTIME_GEOMETRY_TILT
    #endif
    #ifdef RUNTIME_GEOMETRY_MODE
        #undef RUNTIME_GEOMETRY_MODE
    #endif
    #ifdef FORCE_RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT
        #undef FORCE_RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT
    #endif
#endif

//  Make tex2Dbias a backup for tex2Dlod for wider compatibility.
#ifdef ANISOTROPIC_TILING_COMPAT_TEX2DLOD
    #define ANISOTROPIC_TILING_COMPAT_TEX2DBIAS
#endif
#ifdef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DLOD
    #define ANISOTROPIC_RESAMPLING_COMPAT_TEX2DBIAS
#endif
//  Rule out unavailable anisotropic compatibility strategies:
#ifndef DRIVERS_ALLOW_DERIVATIVES
    #ifdef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
        #undef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
    #endif
#endif
#ifndef DRIVERS_ALLOW_TEX2DLOD
    #ifdef ANISOTROPIC_TILING_COMPAT_TEX2DLOD
        #undef ANISOTROPIC_TILING_COMPAT_TEX2DLOD
    #endif
    #ifdef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DLOD
        #undef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DLOD
    #endif
    #ifdef ANTIALIAS_DISABLE_ANISOTROPIC
        #undef ANTIALIAS_DISABLE_ANISOTROPIC
    #endif
#endif
#ifndef DRIVERS_ALLOW_TEX2DBIAS
    #ifdef ANISOTROPIC_TILING_COMPAT_TEX2DBIAS
        #undef ANISOTROPIC_TILING_COMPAT_TEX2DBIAS
    #endif
    #ifdef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DBIAS
        #undef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DBIAS
    #endif
#endif
//  Prioritize anisotropic tiling compatibility strategies by performance and
//  disable unused strategies.  This concentrates all the nesting in one place.
#ifdef ANISOTROPIC_TILING_COMPAT_TEX2DLOD
    #ifdef ANISOTROPIC_TILING_COMPAT_TEX2DBIAS
        #undef ANISOTROPIC_TILING_COMPAT_TEX2DBIAS
    #endif
    #ifdef ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE
        #undef ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE
    #endif
    #ifdef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
        #undef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
    #endif
#else
    #ifdef ANISOTROPIC_TILING_COMPAT_TEX2DBIAS
        #ifdef ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE
            #undef ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE
        #endif
        #ifdef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
            #undef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
        #endif
    #else
        //  ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE is only compatible with
        //  flat texture coords in the same pass, but that's all we use.
        #ifdef ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE
            #ifdef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
                #undef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
            #endif
        #endif
    #endif
#endif
//  The tex2Dlod and tex2Dbias strategies share a lot in common, and we can
//  reduce some #ifdef nesting in the next section by essentially OR'ing them:
#ifdef ANISOTROPIC_TILING_COMPAT_TEX2DLOD
    #define ANISOTROPIC_TILING_COMPAT_TEX2DLOD_FAMILY
#endif
#ifdef ANISOTROPIC_TILING_COMPAT_TEX2DBIAS
    #define ANISOTROPIC_TILING_COMPAT_TEX2DLOD_FAMILY
#endif
//  Prioritize anisotropic resampling compatibility strategies the same way:
#ifdef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DLOD
    #ifdef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DBIAS
        #undef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DBIAS
    #endif
#endif


///////////////////////  DERIVED PHOSPHOR MASK CONSTANTS  //////////////////////

//  If we can use the large mipmapped LUT without mipmapping artifacts, we
//  should: It gives us more options for using fewer samples.
#ifdef DRIVERS_ALLOW_TEX2DLOD
    #ifdef ANISOTROPIC_RESAMPLING_COMPAT_TEX2DLOD
        //  TODO: Take advantage of this!
        #define PHOSPHOR_MASK_RESIZE_MIPMAPPED_LUT
        static const float2 mask_resize_src_lut_size = mask_texture_large_size;
    #else
        static const float2 mask_resize_src_lut_size = mask_texture_small_size;
    #endif
#else
    static const float2 mask_resize_src_lut_size = mask_texture_small_size;
#endif


//  tex2D's sampler2D parameter MUST be a uniform global, a uniform input to
//  main_fragment, or a static alias of one of the above.  This makes it hard
//  to select the phosphor mask at runtime: We can't even assign to a uniform
//  global in the vertex shader or select a sampler2D in the vertex shader and
//  pass it to the fragment shader (even with explicit TEXUNIT# bindings),
//  because it just gives us the input texture or a black screen.  However, we
//  can get around these limitations by calling tex2D three times with different
//  uniform samplers (or resizing the phosphor mask three times altogether).
//  With dynamic branches, we can process only one of these branches on top of
//  quickly discarding fragments we don't need (cgc seems able to overcome
//  limigations around dependent texture fetches inside of branches).  Without
//  dynamic branches, we have to process every branch for every fragment...which
//  is slower.  Runtime sampling mode selection is slower without dynamic
//  branches as well.  Let the user's static #defines decide if it's worth it.
#ifdef DRIVERS_ALLOW_DYNAMIC_BRANCHES
    #define RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT
#else
    #ifdef FORCE_RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT
        #define RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT
    #endif
#endif

//  We need to render some minimum number of tiles in the resize passes.
//  We need at least 1.0 just to repeat a single tile, and we need extra
//  padding beyond that for anisotropic filtering, discontinuitity fixing,
//  antialiasing, same-pass curvature (not currently used), etc.  First
//  determine how many border texels and tiles we need, based on how the result
//  will be sampled:
#ifdef GEOMETRY_EARLY
        static const float max_subpixel_offset = aa_subpixel_r_offset_static.x;
        //  Most antialiasing filters have a base radius of 4.0 pixels:
        static const float max_aa_base_pixel_border = 4.0 +
            max_subpixel_offset;
#else
    static const float max_aa_base_pixel_border = 0.0;
#endif
//  Anisotropic filtering adds about 0.5 to the pixel border:
#ifndef ANISOTROPIC_TILING_COMPAT_TEX2DLOD_FAMILY
    static const float max_aniso_pixel_border = max_aa_base_pixel_border + 0.5;
#else
    static const float max_aniso_pixel_border = max_aa_base_pixel_border;
#endif
//  Fixing discontinuities adds 1.0 more to the pixel border:
#ifdef ANISOTROPIC_TILING_COMPAT_FIX_DISCONTINUITIES
    static const float max_tiled_pixel_border = max_aniso_pixel_border + 1.0;
#else
    static const float max_tiled_pixel_border = max_aniso_pixel_border;
#endif
//  Convert the pixel border to an integer texel border.  Assume same-pass
//  curvature about triples the texel frequency:
#ifdef GEOMETRY_EARLY
    static const float max_mask_texel_border =
        ceil(max_tiled_pixel_border * 3.0);
#else
    static const float max_mask_texel_border = ceil(max_tiled_pixel_border);
#endif
//  Convert the texel border to a tile border using worst-case assumptions:
static const float max_mask_tile_border = max_mask_texel_border/
    (mask_min_allowed_triad_size * mask_triads_per_tile);

//  Finally, set the number of resized tiles to render to MASK_RESIZE, and set
//  the starting texel (inside borders) for sampling it.
#ifndef GEOMETRY_EARLY
    #ifdef ANISOTROPIC_TILING_COMPAT_TILE_FLAT_TWICE
        //  Special case: Render two tiles without borders.  Anisotropic
        //  filtering doesn't seem to be a problem here.
        static const float mask_resize_num_tiles = 1.0 + 1.0;
        static const float mask_start_texels = 0.0;
    #else
        static const float mask_resize_num_tiles = 1.0 +
            2.0 * max_mask_tile_border;
        static const float mask_start_texels = max_mask_texel_border;
    #endif
#else
    static const float mask_resize_num_tiles = 1.0 + 2.0*max_mask_tile_border;
    static const float mask_start_texels = max_mask_texel_border;
#endif

//  We have to fit mask_resize_num_tiles into an FBO with a viewport scale of
//  mask_resize_viewport_scale.  This limits the maximum final triad size.
//  Estimate the minimum number of triads we can split the screen into in each
//  dimension (we'll be as correct as mask_resize_viewport_scale is):
static const float mask_resize_num_triads =
    mask_resize_num_tiles * mask_triads_per_tile;
static const float2 min_allowed_viewport_triads =
    float2(mask_resize_num_triads) / mask_resize_viewport_scale;


////////////////////////  COMMON MATHEMATICAL CONSTANTS  ///////////////////////

static const float pi = 3.141592653589;
//  We often want to find the location of the previous texel, e.g.:
//      const float2 curr_texel = uv * texture_size;
//      const float2 prev_texel = floor(curr_texel - float2(0.5)) + float2(0.5);
//      const float2 prev_texel_uv = prev_texel / texture_size;
//  However, many GPU drivers round incorrectly around exact texel locations.
//  We need to subtract a little less than 0.5 before flooring, and some GPU's
//  require this value to be farther from 0.5 than others; define it here.
//      const float2 prev_texel =
//          floor(curr_texel - float2(under_half)) + float2(0.5);
static const float under_half = 0.4995;


#endif  //  DERIVED_SETTINGS_AND_CONSTANTS_H

/////////////////////////////  END DERIVED-SETTINGS-AND-CONSTANTS  ////////////////////////////

/***************** END derived-settings-and-constants.h ******************/


////////////////////////////////  END INCLUDES  ////////////////////////////////

//  Override some parameters for gamma-management.h and tex2Dantialias.h:
#define OVERRIDE_DEVICE_GAMMA
static const float gba_gamma = 3.5; //  Irrelevant but necessary to define.
#define ANTIALIAS_OVERRIDE_BASICS
#define ANTIALIAS_OVERRIDE_PARAMETERS

//  Disable runtime shader params if the user doesn't explicitly want them.
//  Static constants will be defined in place of uniforms of the same name.
#ifndef RUNTIME_SHADER_PARAMS_ENABLE
    #undef PARAMETER_UNIFORM
#endif

#ifdef PARAMETER_UNIFORM
	uniform COMPAT_PRECISION float crt_gamma;
	uniform COMPAT_PRECISION float lcd_gamma;
	uniform COMPAT_PRECISION float levels_contrast;
	uniform COMPAT_PRECISION float halation_weight;
	uniform COMPAT_PRECISION float diffusion_weight;
	uniform COMPAT_PRECISION float bloom_underestimate_levels;
	uniform COMPAT_PRECISION float bloom_excess;
	uniform COMPAT_PRECISION float beam_min_sigma;
	uniform COMPAT_PRECISION float beam_max_sigma;
	uniform COMPAT_PRECISION float beam_spot_power;
	uniform COMPAT_PRECISION float beam_min_shape;
	uniform COMPAT_PRECISION float beam_max_shape;
	uniform COMPAT_PRECISION float beam_shape_power;
	uniform COMPAT_PRECISION float beam_horiz_sigma;
	#ifdef RUNTIME_SCANLINES_HORIZ_FILTER_COLORSPACE
		uniform COMPAT_PRECISION float beam_horiz_filter;
		uniform COMPAT_PRECISION float beam_horiz_linear_rgb_weight;
	#else
        COMPAT_PRECISION float beam_horiz_filter = clamp(beam_horiz_filter_static, 0.0, 2.0);
        COMPAT_PRECISION float beam_horiz_linear_rgb_weight = clamp(beam_horiz_linear_rgb_weight_static, 0.0, 1.0);
    #endif
	uniform COMPAT_PRECISION float convergence_offset_x_r;
	uniform COMPAT_PRECISION float convergence_offset_x_g;
	uniform COMPAT_PRECISION float convergence_offset_x_b;
	uniform COMPAT_PRECISION float convergence_offset_y_r;
	uniform COMPAT_PRECISION float convergence_offset_y_g;
	uniform COMPAT_PRECISION float convergence_offset_y_b;
	#ifdef RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT
        uniform COMPAT_PRECISION float mask_type;
    #else
        COMPAT_PRECISION float mask_type = clamp(mask_type_static, 0.0, 2.0);
    #endif
	uniform COMPAT_PRECISION float mask_specify_num_triads;
    uniform COMPAT_PRECISION float mask_triad_size_desired;
	uniform COMPAT_PRECISION float mask_sample_mode_desired;
	uniform COMPAT_PRECISION float mask_num_triads_desired;
	uniform COMPAT_PRECISION float aa_subpixel_r_offset_x_runtime;
	uniform COMPAT_PRECISION float aa_subpixel_r_offset_y_runtime;
	#ifdef RUNTIME_ANTIALIAS_WEIGHTS
		uniform COMPAT_PRECISION float aa_cubic_c;
		uniform COMPAT_PRECISION float aa_gauss_sigma;
    #else
        COMPAT_PRECISION float aa_cubic_c = aa_cubic_c_static;                              //  Clamp to [0, 4]?
        COMPAT_PRECISION float aa_gauss_sigma = max(FIX_ZERO(0.0), aa_gauss_sigma_static);  //  Clamp to [FIXZERO(0), 1]?
    #endif
	uniform COMPAT_PRECISION float geom_mode_runtime;
	uniform COMPAT_PRECISION float geom_radius;
	uniform COMPAT_PRECISION float geom_view_dist;
	uniform COMPAT_PRECISION float geom_tilt_angle_x;
	uniform COMPAT_PRECISION float geom_tilt_angle_y;
	uniform COMPAT_PRECISION float geom_aspect_ratio_x;
	uniform COMPAT_PRECISION float geom_aspect_ratio_y;
	uniform COMPAT_PRECISION float geom_overscan_x;
	uniform COMPAT_PRECISION float geom_overscan_y;
	uniform COMPAT_PRECISION float border_size;
	uniform COMPAT_PRECISION float border_darkness;
	uniform COMPAT_PRECISION float border_compress;
	uniform COMPAT_PRECISION float interlace_bff;
	uniform COMPAT_PRECISION float interlace_1080i;
#else
    //  Use constants from user-settings.h, and limit ranges appropriately:
    COMPAT_PRECISION float crt_gamma = max(0.0, crt_gamma_static);
    COMPAT_PRECISION float lcd_gamma = max(0.0, lcd_gamma_static);
    COMPAT_PRECISION float levels_contrast = clamp(levels_contrast_static, 0.0, 4.0);
    COMPAT_PRECISION float halation_weight = clamp(halation_weight_static, 0.0, 1.0);
    COMPAT_PRECISION float diffusion_weight = clamp(diffusion_weight_static, 0.0, 1.0);
    COMPAT_PRECISION float bloom_underestimate_levels = max(FIX_ZERO(0.0), bloom_underestimate_levels_static);
    COMPAT_PRECISION float bloom_excess = clamp(bloom_excess_static, 0.0, 1.0);
    COMPAT_PRECISION float beam_min_sigma = max(FIX_ZERO(0.0), beam_min_sigma_static);
    COMPAT_PRECISION float beam_max_sigma = max(beam_min_sigma, beam_max_sigma_static);
    COMPAT_PRECISION float beam_spot_power = max(beam_spot_power_static, 0.0);
    COMPAT_PRECISION float beam_min_shape = max(2.0, beam_min_shape_static);
    COMPAT_PRECISION float beam_max_shape = max(beam_min_shape, beam_max_shape_static);
    COMPAT_PRECISION float beam_shape_power = max(0.0, beam_shape_power_static);
    COMPAT_PRECISION float beam_horiz_filter = clamp(beam_horiz_filter_static, 0.0, 2.0);
    COMPAT_PRECISION float beam_horiz_sigma = max(FIX_ZERO(0.0), beam_horiz_sigma_static);
    COMPAT_PRECISION float beam_horiz_linear_rgb_weight = clamp(beam_horiz_linear_rgb_weight_static, 0.0, 1.0);
    //  Unpack static vector elements to match scalar uniforms:
    COMPAT_PRECISION float convergence_offset_x_r = clamp(convergence_offsets_r_static.x, -4.0, 4.0);
    COMPAT_PRECISION float convergence_offset_x_g = clamp(convergence_offsets_g_static.x, -4.0, 4.0);
    COMPAT_PRECISION float convergence_offset_x_b = clamp(convergence_offsets_b_static.x, -4.0, 4.0);
    COMPAT_PRECISION float convergence_offset_y_r = clamp(convergence_offsets_r_static.y, -4.0, 4.0);
    COMPAT_PRECISION float convergence_offset_y_g = clamp(convergence_offsets_g_static.y, -4.0, 4.0);
    COMPAT_PRECISION float convergence_offset_y_b = clamp(convergence_offsets_b_static.y, -4.0, 4.0);
    COMPAT_PRECISION float mask_type = clamp(mask_type_static, 0.0, 2.0);
    COMPAT_PRECISION float mask_sample_mode_desired = clamp(mask_sample_mode_static, 0.0, 2.0);
    COMPAT_PRECISION float mask_specify_num_triads = clamp(mask_specify_num_triads_static, 0.0, 1.0);
    COMPAT_PRECISION float mask_triad_size_desired = clamp(mask_triad_size_desired_static, 1.0, 18.0);
    COMPAT_PRECISION float mask_num_triads_desired = clamp(mask_num_triads_desired_static, 342.0, 1920.0);
    COMPAT_PRECISION float aa_subpixel_r_offset_x_runtime = clamp(aa_subpixel_r_offset_static.x, -0.5, 0.5);
    COMPAT_PRECISION float aa_subpixel_r_offset_y_runtime = clamp(aa_subpixel_r_offset_static.y, -0.5, 0.5);
    COMPAT_PRECISION float aa_cubic_c = aa_cubic_c_static;                              //  Clamp to [0, 4]?
    COMPAT_PRECISION float aa_gauss_sigma = max(FIX_ZERO(0.0), aa_gauss_sigma_static);  //  Clamp to [FIXZERO(0), 1]?
    COMPAT_PRECISION float geom_mode_runtime = clamp(geom_mode_static, 0.0, 3.0);
    COMPAT_PRECISION float geom_radius = max(1.0/(2.0*pi), geom_radius_static);         //  Clamp to [1/(2*pi), 1024]?
    COMPAT_PRECISION float geom_view_dist = max(0.5, geom_view_dist_static);            //  Clamp to [0.5, 1024]?
    COMPAT_PRECISION float geom_tilt_angle_x = clamp(geom_tilt_angle_static.x, -pi, pi);
    COMPAT_PRECISION float geom_tilt_angle_y = clamp(geom_tilt_angle_static.y, -pi, pi);
    COMPAT_PRECISION float geom_aspect_ratio_x = geom_aspect_ratio_static;              //  Force >= 1?
    COMPAT_PRECISION float geom_aspect_ratio_y = 1.0;
    COMPAT_PRECISION float geom_overscan_x = max(FIX_ZERO(0.0), geom_overscan_static.x);
    COMPAT_PRECISION float geom_overscan_y = max(FIX_ZERO(0.0), geom_overscan_static.y);
    COMPAT_PRECISION float border_size = clamp(border_size_static, 0.0, 0.5);           //  0.5 reaches to image center
    COMPAT_PRECISION float border_darkness = max(0.0, border_darkness_static);
    COMPAT_PRECISION float border_compress = max(1.0, border_compress_static);          //  < 1.0 darkens whole image
    COMPAT_PRECISION float interlace_bff = float(interlace_bff_static);
    COMPAT_PRECISION float interlace_1080i = float(interlace_1080i_static);
#endif

//  Provide accessors for vector constants that pack scalar uniforms:
inline float2 get_aspect_vector(const float geom_aspect_ratio)
{
    //  Get an aspect ratio vector.  Enforce geom_max_aspect_ratio, and prevent
    //  the absolute scale from affecting the uv-mapping for curvature:
    const float geom_clamped_aspect_ratio =
        min(geom_aspect_ratio, geom_max_aspect_ratio);
    const float2 geom_aspect =
        normalize(float2(geom_clamped_aspect_ratio, 1.0));
    return geom_aspect;
}

inline float2 get_geom_overscan_vector()
{
    return float2(geom_overscan_x, geom_overscan_y);
}

inline float2 get_geom_tilt_angle_vector()
{
    return float2(geom_tilt_angle_x, geom_tilt_angle_y);
}

inline float3 get_convergence_offsets_x_vector()
{
    return float3(convergence_offset_x_r, convergence_offset_x_g,
        convergence_offset_x_b);
}

inline float3 get_convergence_offsets_y_vector()
{
    return float3(convergence_offset_y_r, convergence_offset_y_g,
        convergence_offset_y_b);
}

inline float2 get_convergence_offsets_r_vector()
{
    return float2(convergence_offset_x_r, convergence_offset_y_r);
}

inline float2 get_convergence_offsets_g_vector()
{
    return float2(convergence_offset_x_g, convergence_offset_y_g);
}

inline float2 get_convergence_offsets_b_vector()
{
    return float2(convergence_offset_x_b, convergence_offset_y_b);
}

inline float2 get_aa_subpixel_r_offset()
{
    #ifdef RUNTIME_ANTIALIAS_WEIGHTS
        #ifdef RUNTIME_ANTIALIAS_SUBPIXEL_OFFSETS
            //  WARNING: THIS IS EXTREMELY EXPENSIVE.
            return float2(aa_subpixel_r_offset_x_runtime,
                aa_subpixel_r_offset_y_runtime);
        #else
            return aa_subpixel_r_offset_static;
        #endif
    #else
        return aa_subpixel_r_offset_static;
    #endif
}

//  Provide accessors settings which still need "cooking:"
inline float get_mask_amplify()
{
    static const float mask_grille_amplify = 1.0/mask_grille_avg_color;
    static const float mask_slot_amplify = 1.0/mask_slot_avg_color;
    static const float mask_shadow_amplify = 1.0/mask_shadow_avg_color;
    return mask_type < 0.5 ? mask_grille_amplify :
        mask_type < 1.5 ? mask_slot_amplify :
        mask_shadow_amplify;
}

inline float get_mask_sample_mode()
{
    #ifdef RUNTIME_PHOSPHOR_MASK_MODE_TYPE_SELECT
        #ifdef PHOSPHOR_MASK_MANUALLY_RESIZE
            return mask_sample_mode_desired;
        #else
            return clamp(mask_sample_mode_desired, 1.0, 2.0);
        #endif
    #else
        #ifdef PHOSPHOR_MASK_MANUALLY_RESIZE
            return mask_sample_mode_static;
        #else
            return clamp(mask_sample_mode_static, 1.0, 2.0);
        #endif
    #endif
}

#endif  //  BIND_SHADER_PARAMS_H

////////////////////////////  END BIND-SHADER-PARAMS  ///////////////////////////

/***************** END bind-shader-params.h ******************/

//#include "../include/gamma-management.h"
/***************** BEGIN gamma-management.h ******************/

////////////////////////////  BEGIN GAMMA-MANAGEMENT  //////////////////////////

#ifndef GAMMA_MANAGEMENT_H
#define GAMMA_MANAGEMENT_H

/////////////////////////////////  MIT LICENSE  ////////////////////////////////

//  Copyright (C) 2014 TroggleMonkey
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

/////////////////////////////////  DESCRIPTION  ////////////////////////////////

//  This file provides gamma-aware tex*D*() and encode_output() functions.
//  Requires:   Before #include-ing this file, the including file must #define
//              the following macros when applicable and follow their rules:
//              1.) #define FIRST_PASS if this is the first pass.
//              2.) #define LAST_PASS if this is the last pass.
//              3.) If sRGB is available, set srgb_framebufferN = "true" for
//                  every pass except the last in your .cgp preset.
//              4.) If sRGB isn't available but you want gamma-correctness with
//                  no banding, #define GAMMA_ENCODE_EVERY_FBO each pass.
//              5.) #define SIMULATE_CRT_ON_LCD if desired (precedence over 5-7)
//              6.) #define SIMULATE_GBA_ON_LCD if desired (precedence over 6-7)
//              7.) #define SIMULATE_LCD_ON_CRT if desired (precedence over 7)
//              8.) #define SIMULATE_GBA_ON_CRT if desired (precedence over -)
//              If an option in [5, 8] is #defined in the first or last pass, it
//              should be #defined for both.  It shouldn't make a difference
//              whether it's #defined for intermediate passes or not.
//  Optional:   The including file (or an earlier included file) may optionally
//              #define a number of macros indicating it will override certain
//              macros and associated constants are as follows:
//              static constants with either static or uniform constants.  The
//              1.) OVERRIDE_STANDARD_GAMMA: The user must first define:
//                  static const float ntsc_gamma
//                  static const float pal_gamma
//                  static const float crt_reference_gamma_high
//                  static const float crt_reference_gamma_low
//                  static const float lcd_reference_gamma
//                  static const float crt_office_gamma
//                  static const float lcd_office_gamma
//              2.) OVERRIDE_DEVICE_GAMMA: The user must first define:
//                  static const float crt_gamma
//                  static const float gba_gamma
//                  static const float lcd_gamma
//              3.) OVERRIDE_FINAL_GAMMA: The user must first define:
//                  static const float input_gamma
//                  static const float intermediate_gamma
//                  static const float output_gamma
//                  (intermediate_gamma is for GAMMA_ENCODE_EVERY_FBO.)
//              4.) OVERRIDE_ALPHA_ASSUMPTIONS: The user must first define:
//                  static const bool assume_opaque_alpha
//              The gamma constant overrides must be used in every pass or none,
//              and OVERRIDE_FINAL_GAMMA bypasses all of the SIMULATE* macros.
//              OVERRIDE_ALPHA_ASSUMPTIONS may be set on a per-pass basis.
//  Usage:      After setting macros appropriately, ignore gamma correction and
//              replace all tex*D*() calls with equivalent gamma-aware
//              tex*D*_linearize calls, except:
//              1.) When you read an LUT, use regular tex*D or a gamma-specified
//                  function, depending on its gamma encoding:
//                      tex*D*_linearize_gamma (takes a runtime gamma parameter)
//              2.) If you must read pass0's original input in a later pass, use
//                  tex2D_linearize_ntsc_gamma.  If you want to read pass0's
//                  input with gamma-corrected bilinear filtering, consider
//                  creating a first linearizing pass and reading from the input
//                  of pass1 later.
//              Then, return encode_output(color) from every fragment shader.
//              Finally, use the global gamma_aware_bilinear boolean if you want
//              to statically branch based on whether bilinear filtering is
//              gamma-correct or not (e.g. for placing Gaussian blur samples).
//
//  Detailed Policy:
//  tex*D*_linearize() functions enforce a consistent gamma-management policy
//  based on the FIRST_PASS and GAMMA_ENCODE_EVERY_FBO settings.  They assume
//  their input texture has the same encoding characteristics as the input for
//  the current pass (which doesn't apply to the exceptions listed above).
//  Similarly, encode_output() enforces a policy based on the LAST_PASS and
//  GAMMA_ENCODE_EVERY_FBO settings.  Together, they result in one of the
//  following two pipelines.
//  Typical pipeline with intermediate sRGB framebuffers:
//      linear_color = pow(pass0_encoded_color, input_gamma);
//      intermediate_output = linear_color;     //  Automatic sRGB encoding
//      linear_color = intermediate_output;     //  Automatic sRGB decoding
//      final_output = pow(intermediate_output, 1.0/output_gamma);
//  Typical pipeline without intermediate sRGB framebuffers:
//      linear_color = pow(pass0_encoded_color, input_gamma);
//      intermediate_output = pow(linear_color, 1.0/intermediate_gamma);
//      linear_color = pow(intermediate_output, intermediate_gamma);
//      final_output = pow(intermediate_output, 1.0/output_gamma);
//  Using GAMMA_ENCODE_EVERY_FBO is much slower, but it's provided as a way to
//  easily get gamma-correctness without banding on devices where sRGB isn't
//  supported.
//
//  Use This Header to Maximize Code Reuse:
//  The purpose of this header is to provide a consistent interface for texture
//  reads and output gamma-encoding that localizes and abstracts away all the
//  annoying details.  This greatly reduces the amount of code in each shader
//  pass that depends on the pass number in the .cgp preset or whether sRGB
//  FBO's are being used: You can trivially change the gamma behavior of your
//  whole pass by commenting or uncommenting 1-3 #defines.  To reuse the same
//  code in your first, Nth, and last passes, you can even put it all in another
//  header file and #include it from skeleton .cg files that #define the
//  appropriate pass-specific settings.
//
//  Rationale for Using Three Macros:
//  This file uses GAMMA_ENCODE_EVERY_FBO instead of an opposite macro like
//  SRGB_PIPELINE to ensure sRGB is assumed by default, which hopefully imposes
//  a lower maintenance burden on each pass.  At first glance it seems we could
//  accomplish everything with two macros: GAMMA_CORRECT_IN / GAMMA_CORRECT_OUT.
//  This works for simple use cases where input_gamma == output_gamma, but it
//  breaks down for more complex scenarios like CRT simulation, where the pass
//  number determines the gamma encoding of the input and output.


///////////////////////////////  BASE CONSTANTS  ///////////////////////////////

//  Set standard gamma constants, but allow users to override them:
#ifndef OVERRIDE_STANDARD_GAMMA
    //  Standard encoding gammas:
    static const float ntsc_gamma = 2.2;    //  Best to use NTSC for PAL too?
    static const float pal_gamma = 2.8;     //  Never actually 2.8 in practice
    //  Typical device decoding gammas (only use for emulating devices):
    //  CRT/LCD reference gammas are higher than NTSC and Rec.709 video standard
    //  gammas: The standards purposely undercorrected for an analog CRT's
    //  assumed 2.5 reference display gamma to maintain contrast in assumed
    //  [dark] viewing conditions: http://www.poynton.com/PDFs/GammaFAQ.pdf
    //  These unstated assumptions about display gamma and perceptual rendering
    //  intent caused a lot of confusion, and more modern CRT's seemed to target
    //  NTSC 2.2 gamma with circuitry.  LCD displays seem to have followed suit
    //  (they struggle near black with 2.5 gamma anyway), especially PC/laptop
    //  displays designed to view sRGB in bright environments.  (Standards are
    //  also in flux again with BT.1886, but it's underspecified for displays.)
    static const float crt_reference_gamma_high = 2.5;  //  In (2.35, 2.55)
    static const float crt_reference_gamma_low = 2.35;  //  In (2.35, 2.55)
    static const float lcd_reference_gamma = 2.5;       //  To match CRT
    static const float crt_office_gamma = 2.2;  //  Circuitry-adjusted for NTSC
    static const float lcd_office_gamma = 2.2;  //  Approximates sRGB
#endif  //  OVERRIDE_STANDARD_GAMMA

//  Assuming alpha == 1.0 might make it easier for users to avoid some bugs,
//  but only if they're aware of it.
#ifndef OVERRIDE_ALPHA_ASSUMPTIONS
    static const bool assume_opaque_alpha = false;
#endif


///////////////////////  DERIVED CONSTANTS AS FUNCTIONS  ///////////////////////

//  gamma-management.h should be compatible with overriding gamma values with
//  runtime user parameters, but we can only define other global constants in
//  terms of static constants, not uniform user parameters.  To get around this
//  limitation, we need to define derived constants using functions.

//  Set device gamma constants, but allow users to override them:
#ifdef OVERRIDE_DEVICE_GAMMA
    //  The user promises to globally define the appropriate constants:
    inline float get_crt_gamma()    {   return crt_gamma;   }
    inline float get_gba_gamma()    {   return gba_gamma;   }
    inline float get_lcd_gamma()    {   return lcd_gamma;   }
#else
    inline float get_crt_gamma()    {   return crt_reference_gamma_high;    }
    inline float get_gba_gamma()    {   return 3.5; }   //  Game Boy Advance; in (3.0, 4.0)
    inline float get_lcd_gamma()    {   return lcd_office_gamma;            }
#endif  //  OVERRIDE_DEVICE_GAMMA

//  Set decoding/encoding gammas for the first/lass passes, but allow overrides:
#ifdef OVERRIDE_FINAL_GAMMA
    //  The user promises to globally define the appropriate constants:
    inline float get_intermediate_gamma()   {   return intermediate_gamma;  }
    inline float get_input_gamma()          {   return input_gamma;         }
    inline float get_output_gamma()         {   return output_gamma;        }
#else
    //  If we gamma-correct every pass, always use ntsc_gamma between passes to
    //  ensure middle passes don't need to care if anything is being simulated:
    inline float get_intermediate_gamma()   {   return ntsc_gamma;          }
    #ifdef SIMULATE_CRT_ON_LCD
        inline float get_input_gamma()      {   return get_crt_gamma();     }
        inline float get_output_gamma()     {   return get_lcd_gamma();     }
    #else
    #ifdef SIMULATE_GBA_ON_LCD
        inline float get_input_gamma()      {   return get_gba_gamma();     }
        inline float get_output_gamma()     {   return get_lcd_gamma();     }
    #else
    #ifdef SIMULATE_LCD_ON_CRT
        inline float get_input_gamma()      {   return get_lcd_gamma();     }
        inline float get_output_gamma()     {   return get_crt_gamma();     }
    #else
    #ifdef SIMULATE_GBA_ON_CRT
        inline float get_input_gamma()      {   return get_gba_gamma();     }
        inline float get_output_gamma()     {   return get_crt_gamma();     }
    #else   //  Don't simulate anything:
        inline float get_input_gamma()      {   return ntsc_gamma;          }
        inline float get_output_gamma()     {   return ntsc_gamma;          }
    #endif  //  SIMULATE_GBA_ON_CRT
    #endif  //  SIMULATE_LCD_ON_CRT
    #endif  //  SIMULATE_GBA_ON_LCD
    #endif  //  SIMULATE_CRT_ON_LCD
#endif  //  OVERRIDE_FINAL_GAMMA

//  Set decoding/encoding gammas for the current pass.  Use static constants for
//  linearize_input and gamma_encode_output, because they aren't derived, and
//  they let the compiler do dead-code elimination.
#ifndef GAMMA_ENCODE_EVERY_FBO
    #ifdef FIRST_PASS
        static const bool linearize_input = true;
        inline float get_pass_input_gamma()     {   return get_input_gamma();   }
    #else
        static const bool linearize_input = false;
        inline float get_pass_input_gamma()     {   return 1.0;                 }
    #endif
    #ifdef LAST_PASS
        static const bool gamma_encode_output = true;
        inline float get_pass_output_gamma()    {   return get_output_gamma();  }
    #else
        static const bool gamma_encode_output = false;
        inline float get_pass_output_gamma()    {   return 1.0;                 }
    #endif
#else
    static const bool linearize_input = true;
    static const bool gamma_encode_output = true;
    #ifdef FIRST_PASS
        inline float get_pass_input_gamma()     {   return get_input_gamma();   }
    #else
        inline float get_pass_input_gamma()     {   return get_intermediate_gamma();    }
    #endif
    #ifdef LAST_PASS
        inline float get_pass_output_gamma()    {   return get_output_gamma();  }
    #else
        inline float get_pass_output_gamma()    {   return get_intermediate_gamma();    }
    #endif
#endif

//  Users might want to know if bilinear filtering will be gamma-correct:
static const bool gamma_aware_bilinear = !linearize_input;


//////////////////////  COLOR ENCODING/DECODING FUNCTIONS  /////////////////////

inline float4 encode_output(const float4 color)
{
    if(gamma_encode_output)
    {
        if(assume_opaque_alpha)
        {
            return float4(pow(color.rgb, float3(1.0/get_pass_output_gamma())), 1.0);
        }
        else
        {
            return float4(pow(color.rgb, float3(1.0/get_pass_output_gamma())), color.a);
        }
    }
    else
    {
        return color;
    }
}

inline float4 decode_input(const float4 color)
{
    if(linearize_input)
    {
        if(assume_opaque_alpha)
        {
            return float4(pow(color.rgb, float3(get_pass_input_gamma())), 1.0);
        }
        else
        {
            return float4(pow(color.rgb, float3(get_pass_input_gamma())), color.a);
        }
    }
    else
    {
        return color;
    }
}

inline float4 decode_gamma_input(const float4 color, const float3 gamma)
{
    if(assume_opaque_alpha)
    {
        return float4(pow(color.rgb, gamma), 1.0);
    }
    else
    {
        return float4(pow(color.rgb, gamma), color.a);
    }
}

//TODO/FIXME: I have no idea why replacing the lookup wrappers with this macro fixes the blurs being offset ¯\_(ツ)_/¯
//#define tex2D_linearize(C, D) decode_input(vec4(COMPAT_TEXTURE(C, D)))
// EDIT: it's the 'const' in front of the coords that's doing it

///////////////////////////  TEXTURE LOOKUP WRAPPERS  //////////////////////////

//  "SMART" LINEARIZING TEXTURE LOOKUP FUNCTIONS:
//  Provide a wide array of linearizing texture lookup wrapper functions.  The
//  Cg shader spec Retroarch uses only allows for 2D textures, but 1D and 3D
//  lookups are provided for completeness in case that changes someday.  Nobody
//  is likely to use the *fetch and *proj functions, but they're included just
//  in case.  The only tex*D texture sampling functions omitted are:
//      - tex*Dcmpbias
//      - tex*Dcmplod
//      - tex*DARRAY*
//      - tex*DMS*
//      - Variants returning integers
//  Standard line length restrictions are ignored below for vertical brevity.
/*
//  tex1D:
inline float4 tex1D_linearize(const sampler1D tex, const float tex_coords)
{   return decode_input(tex1D(tex, tex_coords));   }

inline float4 tex1D_linearize(const sampler1D tex, const float2 tex_coords)
{   return decode_input(tex1D(tex, tex_coords));   }

inline float4 tex1D_linearize(const sampler1D tex, const float tex_coords, const int texel_off)
{   return decode_input(tex1D(tex, tex_coords, texel_off));    }

inline float4 tex1D_linearize(const sampler1D tex, const float2 tex_coords, const int texel_off)
{   return decode_input(tex1D(tex, tex_coords, texel_off));    }

inline float4 tex1D_linearize(const sampler1D tex, const float tex_coords, const float dx, const float dy)
{   return decode_input(tex1D(tex, tex_coords, dx, dy));   }

inline float4 tex1D_linearize(const sampler1D tex, const float2 tex_coords, const float dx, const float dy)
{   return decode_input(tex1D(tex, tex_coords, dx, dy));   }

inline float4 tex1D_linearize(const sampler1D tex, const float tex_coords, const float dx, const float dy, const int texel_off)
{   return decode_input(tex1D(tex, tex_coords, dx, dy, texel_off));    }

inline float4 tex1D_linearize(const sampler1D tex, const float2 tex_coords, const float dx, const float dy, const int texel_off)
{   return decode_input(tex1D(tex, tex_coords, dx, dy, texel_off));    }

//  tex1Dbias:
inline float4 tex1Dbias_linearize(const sampler1D tex, const float4 tex_coords)
{   return decode_input(tex1Dbias(tex, tex_coords));   }

inline float4 tex1Dbias_linearize(const sampler1D tex, const float4 tex_coords, const int texel_off)
{   return decode_input(tex1Dbias(tex, tex_coords, texel_off));    }

//  tex1Dfetch:
inline float4 tex1Dfetch_linearize(const sampler1D tex, const int4 tex_coords)
{   return decode_input(tex1Dfetch(tex, tex_coords));  }

inline float4 tex1Dfetch_linearize(const sampler1D tex, const int4 tex_coords, const int texel_off)
{   return decode_input(tex1Dfetch(tex, tex_coords, texel_off));   }

//  tex1Dlod:
inline float4 tex1Dlod_linearize(const sampler1D tex, const float4 tex_coords)
{   return decode_input(tex1Dlod(tex, tex_coords));    }

inline float4 tex1Dlod_linearize(const sampler1D tex, const float4 tex_coords, const int texel_off)
{   return decode_input(tex1Dlod(tex, tex_coords, texel_off));     }

//  tex1Dproj:
inline float4 tex1Dproj_linearize(const sampler1D tex, const float2 tex_coords)
{   return decode_input(tex1Dproj(tex, tex_coords));   }

inline float4 tex1Dproj_linearize(const sampler1D tex, const float3 tex_coords)
{   return decode_input(tex1Dproj(tex, tex_coords));   }

inline float4 tex1Dproj_linearize(const sampler1D tex, const float2 tex_coords, const int texel_off)
{   return decode_input(tex1Dproj(tex, tex_coords, texel_off));    }

inline float4 tex1Dproj_linearize(const sampler1D tex, const float3 tex_coords, const int texel_off)
{   return decode_input(tex1Dproj(tex, tex_coords, texel_off));    }
*/
//  tex2D:
inline float4 tex2D_linearize(const sampler2D tex, float2 tex_coords)
{   return decode_input(COMPAT_TEXTURE(tex, tex_coords));   }

inline float4 tex2D_linearize(const sampler2D tex, float3 tex_coords)
{   return decode_input(COMPAT_TEXTURE(tex, tex_coords.xy));   }

inline float4 tex2D_linearize(const sampler2D tex, float2 tex_coords, int texel_off)
{   return decode_input(textureLod(tex, tex_coords, texel_off));    }

inline float4 tex2D_linearize(const sampler2D tex, float3 tex_coords, int texel_off)
{   return decode_input(textureLod(tex, tex_coords.xy, texel_off));    }

//inline float4 tex2D_linearize(const sampler2D tex, const float2 tex_coords, const float2 dx, const float2 dy)
//{   return decode_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy));   }

//inline float4 tex2D_linearize(const sampler2D tex, const float3 tex_coords, const float2 dx, const float2 dy)
//{   return decode_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy));   }

//inline float4 tex2D_linearize(const sampler2D tex, const float2 tex_coords, const float2 dx, const float2 dy, const int texel_off)
//{   return decode_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy, texel_off));    }

//inline float4 tex2D_linearize(const sampler2D tex, const float3 tex_coords, const float2 dx, const float2 dy, const int texel_off)
//{   return decode_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy, texel_off));    }

//  tex2Dbias:
//inline float4 tex2Dbias_linearize(const sampler2D tex, const float4 tex_coords)
//{   return decode_input(tex2Dbias(tex, tex_coords));   }

//inline float4 tex2Dbias_linearize(const sampler2D tex, const float4 tex_coords, const int texel_off)
//{   return decode_input(tex2Dbias(tex, tex_coords, texel_off));    }

//  tex2Dfetch:
//inline float4 tex2Dfetch_linearize(const sampler2D tex, const int4 tex_coords)
//{   return decode_input(tex2Dfetch(tex, tex_coords));  }

//inline float4 tex2Dfetch_linearize(const sampler2D tex, const int4 tex_coords, const int texel_off)
//{   return decode_input(tex2Dfetch(tex, tex_coords, texel_off));   }

//  tex2Dlod:
inline float4 tex2Dlod_linearize(const sampler2D tex, float4 tex_coords)
{   return decode_input(textureLod(tex, tex_coords.xy, 0.0));    }

inline float4 tex2Dlod_linearize(const sampler2D tex, float4 tex_coords, int texel_off)
{   return decode_input(textureLod(tex, tex_coords.xy, texel_off));     }
/*
//  tex2Dproj:
inline float4 tex2Dproj_linearize(const sampler2D tex, const float3 tex_coords)
{   return decode_input(tex2Dproj(tex, tex_coords));   }

inline float4 tex2Dproj_linearize(const sampler2D tex, const float4 tex_coords)
{   return decode_input(tex2Dproj(tex, tex_coords));   }

inline float4 tex2Dproj_linearize(const sampler2D tex, const float3 tex_coords, const int texel_off)
{   return decode_input(tex2Dproj(tex, tex_coords, texel_off));    }

inline float4 tex2Dproj_linearize(const sampler2D tex, const float4 tex_coords, const int texel_off)
{   return decode_input(tex2Dproj(tex, tex_coords, texel_off));    }
*/
/*
//  tex3D:
inline float4 tex3D_linearize(const sampler3D tex, const float3 tex_coords)
{   return decode_input(tex3D(tex, tex_coords));   }

inline float4 tex3D_linearize(const sampler3D tex, const float3 tex_coords, const int texel_off)
{   return decode_input(tex3D(tex, tex_coords, texel_off));    }

inline float4 tex3D_linearize(const sampler3D tex, const float3 tex_coords, const float3 dx, const float3 dy)
{   return decode_input(tex3D(tex, tex_coords, dx, dy));   }

inline float4 tex3D_linearize(const sampler3D tex, const float3 tex_coords, const float3 dx, const float3 dy, const int texel_off)
{   return decode_input(tex3D(tex, tex_coords, dx, dy, texel_off));    }

//  tex3Dbias:
inline float4 tex3Dbias_linearize(const sampler3D tex, const float4 tex_coords)
{   return decode_input(tex3Dbias(tex, tex_coords));   }

inline float4 tex3Dbias_linearize(const sampler3D tex, const float4 tex_coords, const int texel_off)
{   return decode_input(tex3Dbias(tex, tex_coords, texel_off));    }

//  tex3Dfetch:
inline float4 tex3Dfetch_linearize(const sampler3D tex, const int4 tex_coords)
{   return decode_input(tex3Dfetch(tex, tex_coords));  }

inline float4 tex3Dfetch_linearize(const sampler3D tex, const int4 tex_coords, const int texel_off)
{   return decode_input(tex3Dfetch(tex, tex_coords, texel_off));   }

//  tex3Dlod:
inline float4 tex3Dlod_linearize(const sampler3D tex, const float4 tex_coords)
{   return decode_input(tex3Dlod(tex, tex_coords));    }

inline float4 tex3Dlod_linearize(const sampler3D tex, const float4 tex_coords, const int texel_off)
{   return decode_input(tex3Dlod(tex, tex_coords, texel_off));     }

//  tex3Dproj:
inline float4 tex3Dproj_linearize(const sampler3D tex, const float4 tex_coords)
{   return decode_input(tex3Dproj(tex, tex_coords));   }

inline float4 tex3Dproj_linearize(const sampler3D tex, const float4 tex_coords, const int texel_off)
{   return decode_input(tex3Dproj(tex, tex_coords, texel_off));    }
/////////*

//  NONSTANDARD "SMART" LINEARIZING TEXTURE LOOKUP FUNCTIONS:
//  This narrow selection of nonstandard tex2D* functions can be useful:

//  tex2Dlod0: Automatically fill in the tex2D LOD parameter for mip level 0.
//inline float4 tex2Dlod0_linearize(const sampler2D tex, const float2 tex_coords)
//{   return decode_input(tex2Dlod(tex, float4(tex_coords, 0.0, 0.0)));   }

//inline float4 tex2Dlod0_linearize(const sampler2D tex, const float2 tex_coords, const int texel_off)
//{   return decode_input(tex2Dlod(tex, float4(tex_coords, 0.0, 0.0), texel_off));    }


//  MANUALLY LINEARIZING TEXTURE LOOKUP FUNCTIONS:
//  Provide a narrower selection of tex2D* wrapper functions that decode an
//  input sample with a specified gamma value.  These are useful for reading
//  LUT's and for reading the input of pass0 in a later pass.

//  tex2D:
inline float4 tex2D_linearize_gamma(const sampler2D tex, const float2 tex_coords, const float3 gamma)
{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords), gamma);   }

inline float4 tex2D_linearize_gamma(const sampler2D tex, const float3 tex_coords, const float3 gamma)
{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords.xy), gamma);   }

//inline float4 tex2D_linearize_gamma(const sampler2D tex, const float2 tex_coords, const int texel_off, const float3 gamma)
//{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords, texel_off), gamma);    }

//inline float4 tex2D_linearize_gamma(const sampler2D tex, const float3 tex_coords, const int texel_off, const float3 gamma)
//{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords, texel_off), gamma);    }

//inline float4 tex2D_linearize_gamma(const sampler2D tex, const float2 tex_coords, const float2 dx, const float2 dy, const float3 gamma)
//{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy), gamma);   }

//inline float4 tex2D_linearize_gamma(const sampler2D tex, const float3 tex_coords, const float2 dx, const float2 dy, const float3 gamma)
//{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy), gamma);   }

//inline float4 tex2D_linearize_gamma(const sampler2D tex, const float2 tex_coords, const float2 dx, const float2 dy, const int texel_off, const float3 gamma)
//{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy, texel_off), gamma);    }

//inline float4 tex2D_linearize_gamma(const sampler2D tex, const float3 tex_coords, const float2 dx, const float2 dy, const int texel_off, const float3 gamma)
//{   return decode_gamma_input(COMPAT_TEXTURE(tex, tex_coords, dx, dy, texel_off), gamma);    }
/*
//  tex2Dbias:
inline float4 tex2Dbias_linearize_gamma(const sampler2D tex, const float4 tex_coords, const float3 gamma)
{   return decode_gamma_input(tex2Dbias(tex, tex_coords), gamma);   }

inline float4 tex2Dbias_linearize_gamma(const sampler2D tex, const float4 tex_coords, const int texel_off, const float3 gamma)
{   return decode_gamma_input(tex2Dbias(tex, tex_coords, texel_off), gamma);    }

//  tex2Dfetch:
inline float4 tex2Dfetch_linearize_gamma(const sampler2D tex, const int4 tex_coords, const float3 gamma)
{   return decode_gamma_input(tex2Dfetch(tex, tex_coords), gamma);  }

inline float4 tex2Dfetch_linearize_gamma(const sampler2D tex, const int4 tex_coords, const int texel_off, const float3 gamma)
{   return decode_gamma_input(tex2Dfetch(tex, tex_coords, texel_off), gamma);   }
*/
//  tex2Dlod:
inline float4 tex2Dlod_linearize_gamma(const sampler2D tex, float4 tex_coords, float3 gamma)
{   return decode_gamma_input(textureLod(tex, tex_coords.xy, 0.0), gamma);    }

inline float4 tex2Dlod_linearize_gamma(const sampler2D tex, float4 tex_coords, int texel_off, float3 gamma)
{   return decode_gamma_input(textureLod(tex, tex_coords.xy, texel_off), gamma);     }


#endif  //  GAMMA_MANAGEMENT_H

////////////////////////////  END GAMMA-MANAGEMENT  //////////////////////////
/***************** END gamma-management.h ******************/

//#include "../include/derived-settings-and-constants.h"
//#include "../include/scanline-functions.h"
/***************** BEGIN scanline-functions.h ******************/

/////////////////////////////  BEGIN SCANLINE-FUNCTIONS  ////////////////////////////

#ifndef SCANLINE_FUNCTIONS_H
#define SCANLINE_FUNCTIONS_H

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA


///////////////////////////////  BEGIN INCLUDES  ///////////////////////////////

//#include "../include/user-settings.h"
//#include "../include/derived-settings-and-constants.h"
//#include "../include/special-functions.h"
/***************** BEGIN special-functions.h ******************/

///////////////////////////  BEGIN SPECIAL-FUNCTIONS  //////////////////////////

#ifndef SPECIAL_FUNCTIONS_H
#define SPECIAL_FUNCTIONS_H

/////////////////////////////////  MIT LICENSE  ////////////////////////////////

//  Copyright (C) 2014 TroggleMonkey
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.


/////////////////////////////////  DESCRIPTION  ////////////////////////////////

//  This file implements the following mathematical special functions:
//  1.) erf() = 2/sqrt(pi) * indefinite_integral(e**(-x**2))
//  2.) gamma(s), a real-numbered extension of the integer factorial function
//  It also implements normalized_ligamma(s, z), a normalized lower incomplete
//  gamma function for s < 0.5 only.  Both gamma() and normalized_ligamma() can
//  be called with an _impl suffix to use an implementation version with a few
//  extra precomputed parameters (which may be useful for the caller to reuse).
//  See below for details.
//
//  Design Rationale:
//  Pretty much every line of code in this file is duplicated four times for
//  different input types (float4/float3/float2/float).  This is unfortunate,
//  but Cg doesn't allow function templates.  Macros would be far less verbose,
//  but they would make the code harder to document and read.  I don't expect
//  these functions will require a whole lot of maintenance changes unless
//  someone ever has need for more robust incomplete gamma functions, so code
//  duplication seems to be the lesser evil in this case.


///////////////////////////  GAUSSIAN ERROR FUNCTION  //////////////////////////

float4 erf6(float4 x)
{
    //  Requires:   x is the standard parameter to erf().
    //  Returns:    Return an Abramowitz/Stegun approximation of erf(), where:
    //                  erf(x) = 2/sqrt(pi) * integral(e**(-x**2))
    //              This approximation has a max absolute error of 2.5*10**-5
    //              with solid numerical robustness and efficiency.  See:
	//                  https://en.wikipedia.org/wiki/Error_function#Approximation_with_elementary_functions
	static const float4 one = float4(1.0);
	const float4 sign_x = sign(x);
	const float4 t = one/(one + 0.47047*abs(x));
	const float4 result = one - t*(0.3480242 + t*(-0.0958798 + t*0.7478556))*
		exp(-(x*x));
	return result * sign_x;
}

float3 erf6(const float3 x)
{
    //  Float3 version:
	static const float3 one = float3(1.0);
	const float3 sign_x = sign(x);
	const float3 t = one/(one + 0.47047*abs(x));
	const float3 result = one - t*(0.3480242 + t*(-0.0958798 + t*0.7478556))*
		exp(-(x*x));
	return result * sign_x;
}

float2 erf6(const float2 x)
{
    //  Float2 version:
	static const float2 one = float2(1.0);
	const float2 sign_x = sign(x);
	const float2 t = one/(one + 0.47047*abs(x));
	const float2 result = one - t*(0.3480242 + t*(-0.0958798 + t*0.7478556))*
		exp(-(x*x));
	return result * sign_x;
}

float erf6(const float x)
{
    //  Float version:
	const float sign_x = sign(x);
	const float t = 1.0/(1.0 + 0.47047*abs(x));
	const float result = 1.0 - t*(0.3480242 + t*(-0.0958798 + t*0.7478556))*
		exp(-(x*x));
	return result * sign_x;
}

float4 erft(const float4 x)
{
    //  Requires:   x is the standard parameter to erf().
    //  Returns:    Approximate erf() with the hyperbolic tangent.  The error is
    //              visually noticeable, but it's blazing fast and perceptually
    //              close...at least on ATI hardware.  See:
    //                  http://www.maplesoft.com/applications/view.aspx?SID=5525&view=html
    //  Warning:    Only use this if your hardware drivers correctly implement
    //              tanh(): My nVidia 8800GTS returns garbage output.
	return tanh(1.202760580 * x);
}

float3 erft(const float3 x)
{
    //  Float3 version:
	return tanh(1.202760580 * x);
}

float2 erft(const float2 x)
{
    //  Float2 version:
	return tanh(1.202760580 * x);
}

float erft(const float x)
{
    //  Float version:
	return tanh(1.202760580 * x);
}

inline float4 erf(const float4 x)
{
    //  Requires:   x is the standard parameter to erf().
    //  Returns:    Some approximation of erf(x), depending on user settings.
	#ifdef ERF_FAST_APPROXIMATION
		return erft(x);
	#else
		return erf6(x);
	#endif
}

inline float3 erf(const float3 x)
{
    //  Float3 version:
	#ifdef ERF_FAST_APPROXIMATION
		return erft(x);
	#else
		return erf6(x);
	#endif
}

inline float2 erf(const float2 x)
{
    //  Float2 version:
	#ifdef ERF_FAST_APPROXIMATION
		return erft(x);
	#else
		return erf6(x);
	#endif
}

inline float erf(const float x)
{
    //  Float version:
	#ifdef ERF_FAST_APPROXIMATION
		return erft(x);
	#else
		return erf6(x);
	#endif
}


///////////////////////////  COMPLETE GAMMA FUNCTION  //////////////////////////

float4 gamma_impl(const float4 s, const float4 s_inv)
{
    //  Requires:   1.) s is the standard parameter to the gamma function, and
    //                  it should lie in the [0, 36] range.
    //              2.) s_inv = 1.0/s.  This implementation function requires
    //                  the caller to precompute this value, giving users the
    //                  opportunity to reuse it.
    //  Returns:    Return approximate gamma function (real-numbered factorial)
    //              output using the Lanczos approximation with two coefficients
    //              calculated using Paul Godfrey's method here:
    //                  http://my.fit.edu/~gabdo/gamma.txt
    //              An optimal g value for s in [0, 36] is ~1.12906830989, with
    //              a maximum relative error of 0.000463 for 2**16 equally
    //              evals.  We could use three coeffs (0.0000346 error) without
    //              hurting latency, but this allows more parallelism with
    //              outside instructions.
	static const float4 g = float4(1.12906830989);
	static const float4 c0 = float4(0.8109119309638332633713423362694399653724431);
	static const float4 c1 = float4(0.4808354605142681877121661197951496120000040);
	static const float4 e = float4(2.71828182845904523536028747135266249775724709);
	const float4 sph = s + float4(0.5);
	const float4 lanczos_sum = c0 + c1/(s + float4(1.0));
	const float4 base = (sph + g)/e;  //  or (s + g + float4(0.5))/e
	//  gamma(s + 1) = base**sph * lanczos_sum; divide by s for gamma(s).
	//  This has less error for small s's than (s -= 1.0) at the beginning.
	return (pow(base, sph) * lanczos_sum) * s_inv;
}

float3 gamma_impl(const float3 s, const float3 s_inv)
{
    //  Float3 version:
	static const float3 g = float3(1.12906830989);
	static const float3 c0 = float3(0.8109119309638332633713423362694399653724431);
	static const float3 c1 = float3(0.4808354605142681877121661197951496120000040);
	static const float3 e = float3(2.71828182845904523536028747135266249775724709);
	const float3 sph = s + float3(0.5);
	const float3 lanczos_sum = c0 + c1/(s + float3(1.0));
	const float3 base = (sph + g)/e;
	return (pow(base, sph) * lanczos_sum) * s_inv;
}

float2 gamma_impl(const float2 s, const float2 s_inv)
{
    //  Float2 version:
	static const float2 g = float2(1.12906830989);
	static const float2 c0 = float2(0.8109119309638332633713423362694399653724431);
	static const float2 c1 = float2(0.4808354605142681877121661197951496120000040);
	static const float2 e = float2(2.71828182845904523536028747135266249775724709);
	const float2 sph = s + float2(0.5);
	const float2 lanczos_sum = c0 + c1/(s + float2(1.0));
	const float2 base = (sph + g)/e;
	return (pow(base, sph) * lanczos_sum) * s_inv;
}

float gamma_impl(const float s, const float s_inv)
{
    //  Float version:
	static const float g = 1.12906830989;
	static const float c0 = 0.8109119309638332633713423362694399653724431;
	static const float c1 = 0.4808354605142681877121661197951496120000040;
	static const float e = 2.71828182845904523536028747135266249775724709;
	const float sph = s + 0.5;
	const float lanczos_sum = c0 + c1/(s + 1.0);
	const float base = (sph + g)/e;
	return (pow(base, sph) * lanczos_sum) * s_inv;
}

float4 gamma(const float4 s)
{
    //  Requires:   s is the standard parameter to the gamma function, and it
    //              should lie in the [0, 36] range.
    //  Returns:    Return approximate gamma function output with a maximum
    //              relative error of 0.000463.  See gamma_impl for details.
	return gamma_impl(s, float4(1.0)/s);
}

float3 gamma(const float3 s)
{
    //  Float3 version:
	return gamma_impl(s, float3(1.0)/s);
}

float2 gamma(const float2 s)
{
    //  Float2 version:
	return gamma_impl(s, float2(1.0)/s);
}

float gamma(const float s)
{
    //  Float version:
	return gamma_impl(s, 1.0/s);
}


////////////////  INCOMPLETE GAMMA FUNCTIONS (RESTRICTED INPUT)  ///////////////

//  Lower incomplete gamma function for small s and z (implementation):
float4 ligamma_small_z_impl(const float4 s, const float4 z, const float4 s_inv)
{
    //  Requires:   1.) s < ~0.5
    //              2.) z <= ~0.775075
    //              3.) s_inv = 1.0/s (precomputed for outside reuse)
    //  Returns:    A series representation for the lower incomplete gamma
    //              function for small s and small z (4 terms).
    //  The actual "rolled up" summation looks like:
	//      last_sign = 1.0; last_pow = 1.0; last_factorial = 1.0;
	//      sum = last_sign * last_pow / ((s + k) * last_factorial)
	//      for(int i = 0; i < 4; ++i)
	//      {
	//          last_sign *= -1.0; last_pow *= z; last_factorial *= i;
	//          sum += last_sign * last_pow / ((s + k) * last_factorial);
	//      }
	//  Unrolled, constant-unfolded and arranged for madds and parallelism:
	const float4 scale = pow(z, s);
	float4 sum = s_inv;  //  Summation iteration 0 result
	//  Summation iterations 1, 2, and 3:
	const float4 z_sq = z*z;
	const float4 denom1 = s + float4(1.0);
	const float4 denom2 = 2.0*s + float4(4.0);
	const float4 denom3 = 6.0*s + float4(18.0);
	//float4 denom4 = 24.0*s + float4(96.0);
	sum -= z/denom1;
	sum += z_sq/denom2;
	sum -= z * z_sq/denom3;
	//sum += z_sq * z_sq / denom4;
	//  Scale and return:
	return scale * sum;
}

float3 ligamma_small_z_impl(const float3 s, const float3 z, const float3 s_inv)
{
    //  Float3 version:
	const float3 scale = pow(z, s);
	float3 sum = s_inv;
	const float3 z_sq = z*z;
	const float3 denom1 = s + float3(1.0);
	const float3 denom2 = 2.0*s + float3(4.0);
	const float3 denom3 = 6.0*s + float3(18.0);
	sum -= z/denom1;
	sum += z_sq/denom2;
	sum -= z * z_sq/denom3;
	return scale * sum;
}

float2 ligamma_small_z_impl(const float2 s, const float2 z, const float2 s_inv)
{
    //  Float2 version:
	const float2 scale = pow(z, s);
	float2 sum = s_inv;
	const float2 z_sq = z*z;
	const float2 denom1 = s + float2(1.0);
	const float2 denom2 = 2.0*s + float2(4.0);
	const float2 denom3 = 6.0*s + float2(18.0);
	sum -= z/denom1;
	sum += z_sq/denom2;
	sum -= z * z_sq/denom3;
	return scale * sum;
}

float ligamma_small_z_impl(const float s, const float z, const float s_inv)
{
    //  Float version:
	const float scale = pow(z, s);
	float sum = s_inv;
	const float z_sq = z*z;
	const float denom1 = s + 1.0;
	const float denom2 = 2.0*s + 4.0;
	const float denom3 = 6.0*s + 18.0;
	sum -= z/denom1;
	sum += z_sq/denom2;
	sum -= z * z_sq/denom3;
	return scale * sum;
}

//  Upper incomplete gamma function for small s and large z (implementation):
float4 uigamma_large_z_impl(const float4 s, const float4 z)
{
    //  Requires:   1.) s < ~0.5
    //              2.) z > ~0.775075
    //  Returns:    Gauss's continued fraction representation for the upper
    //              incomplete gamma function (4 terms).
	//  The "rolled up" continued fraction looks like this.  The denominator
    //  is truncated, and it's calculated "from the bottom up:"
	//      denom = float4('inf');
	//      float4 one = float4(1.0);
	//      for(int i = 4; i > 0; --i)
	//      {
	//          denom = ((i * 2.0) - one) + z - s + (i * (s - i))/denom;
	//      }
	//  Unrolled and constant-unfolded for madds and parallelism:
	const float4 numerator = pow(z, s) * exp(-z);
	float4 denom = float4(7.0) + z - s;
	denom = float4(5.0) + z - s + (3.0*s - float4(9.0))/denom;
	denom = float4(3.0) + z - s + (2.0*s - float4(4.0))/denom;
	denom = float4(1.0) + z - s + (s - float4(1.0))/denom;
	return numerator / denom;
}

float3 uigamma_large_z_impl(const float3 s, const float3 z)
{
    //  Float3 version:
	const float3 numerator = pow(z, s) * exp(-z);
	float3 denom = float3(7.0) + z - s;
	denom = float3(5.0) + z - s + (3.0*s - float3(9.0))/denom;
	denom = float3(3.0) + z - s + (2.0*s - float3(4.0))/denom;
	denom = float3(1.0) + z - s + (s - float3(1.0))/denom;
	return numerator / denom;
}

float2 uigamma_large_z_impl(const float2 s, const float2 z)
{
    //  Float2 version:
	const float2 numerator = pow(z, s) * exp(-z);
	float2 denom = float2(7.0) + z - s;
	denom = float2(5.0) + z - s + (3.0*s - float2(9.0))/denom;
	denom = float2(3.0) + z - s + (2.0*s - float2(4.0))/denom;
	denom = float2(1.0) + z - s + (s - float2(1.0))/denom;
	return numerator / denom;
}

float uigamma_large_z_impl(const float s, const float z)
{
    //  Float version:
	const float numerator = pow(z, s) * exp(-z);
	float denom = 7.0 + z - s;
	denom = 5.0 + z - s + (3.0*s - 9.0)/denom;
	denom = 3.0 + z - s + (2.0*s - 4.0)/denom;
	denom = 1.0 + z - s + (s - 1.0)/denom;
	return numerator / denom;
}

//  Normalized lower incomplete gamma function for small s (implementation):
float4 normalized_ligamma_impl(const float4 s, const float4 z,
    const float4 s_inv, const float4 gamma_s_inv)
{
    //  Requires:   1.) s < ~0.5
    //              2.) s_inv = 1/s (precomputed for outside reuse)
    //              3.) gamma_s_inv = 1/gamma(s) (precomputed for outside reuse)
    //  Returns:    Approximate the normalized lower incomplete gamma function
    //              for s < 0.5.  Since we only care about s < 0.5, we only need
    //              to evaluate two branches (not four) based on z.  Each branch
    //              uses four terms, with a max relative error of ~0.00182.  The
    //              branch threshold and specifics were adapted for fewer terms
    //              from Gil/Segura/Temme's paper here:
    //                  http://oai.cwi.nl/oai/asset/20433/20433B.pdf
	//  Evaluate both branches: Real branches test slower even when available.
	static const float4 thresh = float4(0.775075);
	bool4 z_is_large;
	z_is_large.x = z.x > thresh.x;
	z_is_large.y = z.y > thresh.y;
	z_is_large.z = z.z > thresh.z;
	z_is_large.w = z.w > thresh.w;
	const float4 large_z = float4(1.0) - uigamma_large_z_impl(s, z) * gamma_s_inv;
	const float4 small_z = ligamma_small_z_impl(s, z, s_inv) * gamma_s_inv;
	//  Combine the results from both branches:
	bool4 inverse_z_is_large = not(z_is_large);
	return large_z * float4(z_is_large) + small_z * float4(inverse_z_is_large);
}

float3 normalized_ligamma_impl(const float3 s, const float3 z,
    const float3 s_inv, const float3 gamma_s_inv)
{
    //  Float3 version:
	static const float3 thresh = float3(0.775075);
	bool3 z_is_large;
	z_is_large.x = z.x > thresh.x;
	z_is_large.y = z.y > thresh.y;
	z_is_large.z = z.z > thresh.z;
	const float3 large_z = float3(1.0) - uigamma_large_z_impl(s, z) * gamma_s_inv;
	const float3 small_z = ligamma_small_z_impl(s, z, s_inv) * gamma_s_inv;
	bool3 inverse_z_is_large = not(z_is_large);
	return large_z * float3(z_is_large) + small_z * float3(inverse_z_is_large);
}

float2 normalized_ligamma_impl(const float2 s, const float2 z,
    const float2 s_inv, const float2 gamma_s_inv)
{
    //  Float2 version:
	static const float2 thresh = float2(0.775075);
	bool2 z_is_large;
	z_is_large.x = z.x > thresh.x;
	z_is_large.y = z.y > thresh.y;
	const float2 large_z = float2(1.0) - uigamma_large_z_impl(s, z) * gamma_s_inv;
	const float2 small_z = ligamma_small_z_impl(s, z, s_inv) * gamma_s_inv;
	bool2 inverse_z_is_large = not(z_is_large);
	return large_z * float2(z_is_large) + small_z * float2(inverse_z_is_large);
}

float normalized_ligamma_impl(const float s, const float z,
    const float s_inv, const float gamma_s_inv)
{
    //  Float version:
	static const float thresh = 0.775075;
	const bool z_is_large = z > thresh;
	const float large_z = 1.0 - uigamma_large_z_impl(s, z) * gamma_s_inv;
	const float small_z = ligamma_small_z_impl(s, z, s_inv) * gamma_s_inv;
	return large_z * float(z_is_large) + small_z * float(!z_is_large);
}

//  Normalized lower incomplete gamma function for small s:
float4 normalized_ligamma(const float4 s, const float4 z)
{
    //  Requires:   s < ~0.5
    //  Returns:    Approximate the normalized lower incomplete gamma function
    //              for s < 0.5.  See normalized_ligamma_impl() for details.
	const float4 s_inv = float4(1.0)/s;
	const float4 gamma_s_inv = float4(1.0)/gamma_impl(s, s_inv);
	return normalized_ligamma_impl(s, z, s_inv, gamma_s_inv);
}

float3 normalized_ligamma(const float3 s, const float3 z)
{
    //  Float3 version:
	const float3 s_inv = float3(1.0)/s;
	const float3 gamma_s_inv = float3(1.0)/gamma_impl(s, s_inv);
	return normalized_ligamma_impl(s, z, s_inv, gamma_s_inv);
}

float2 normalized_ligamma(const float2 s, const float2 z)
{
    //  Float2 version:
	const float2 s_inv = float2(1.0)/s;
	const float2 gamma_s_inv = float2(1.0)/gamma_impl(s, s_inv);
	return normalized_ligamma_impl(s, z, s_inv, gamma_s_inv);
}

float normalized_ligamma(const float s, const float z)
{
    //  Float version:
	const float s_inv = 1.0/s;
	const float gamma_s_inv = 1.0/gamma_impl(s, s_inv);
	return normalized_ligamma_impl(s, z, s_inv, gamma_s_inv);
}

#endif  //  SPECIAL_FUNCTIONS_H

////////////////////////////  END SPECIAL-FUNCTIONS  ///////////////////////////
/***************** END special-functions.h ******************/

//#include "../include/gamma-management.h"

////////////////////////////////  END INCLUDES  ////////////////////////////////

/////////////////////////////  SCANLINE FUNCTIONS  /////////////////////////////

inline float3 get_gaussian_sigma(const float3 color, const float sigma_range)
{
    //  Requires:   Globals:
    //              1.) beam_min_sigma and beam_max_sigma are global floats
    //                  containing the desired minimum and maximum beam standard
    //                  deviations, for dim and bright colors respectively.
    //              2.) beam_max_sigma must be > 0.0
    //              3.) beam_min_sigma must be in (0.0, beam_max_sigma]
    //              4.) beam_spot_power must be defined as a global float.
    //              Parameters:
    //              1.) color is the underlying source color along a scanline
    //              2.) sigma_range = beam_max_sigma - beam_min_sigma; we take
    //                  sigma_range as a parameter to avoid repeated computation
    //                  when beam_{min, max}_sigma are runtime shader parameters
    //  Optional:   Users may set beam_spot_shape_function to 1 to define the
    //              inner f(color) subfunction (see below) as:
    //                  f(color) = sqrt(1.0 - (color - 1.0)*(color - 1.0))
    //              Otherwise (technically, if beam_spot_shape_function < 0.5):
    //                  f(color) = pow(color, beam_spot_power)
    //  Returns:    The standard deviation of the Gaussian beam for "color:"
    //                  sigma = beam_min_sigma + sigma_range * f(color)
    //  Details/Discussion:
    //  The beam's spot shape vaguely resembles an aspect-corrected f() in the
    //  range [0, 1] (not quite, but it's related).  f(color) = color makes
    //  spots look like diamonds, and a spherical function or cube balances
    //  between variable width and a soft/realistic shape.   A beam_spot_power
    //  > 1.0 can produce an ugly spot shape and more initial clipping, but the
    //  final shape also differs based on the horizontal resampling filter and
    //  the phosphor bloom.  For instance, resampling horizontally in nonlinear
    //  light and/or with a sharp (e.g. Lanczos) filter will sharpen the spot
    //  shape, but a sixth root is still quite soft.  A power function (default
    //  1.0/3.0 beam_spot_power) is most flexible, but a fixed spherical curve
    //  has the highest variability without an awful spot shape.
    //
    //  beam_min_sigma affects scanline sharpness/aliasing in dim areas, and its
    //  difference from beam_max_sigma affects beam width variability.  It only
    //  affects clipping [for pure Gaussians] if beam_spot_power > 1.0 (which is
    //  a conservative estimate for a more complex constraint).
    //
    //  beam_max_sigma affects clipping and increasing scanline width/softness
    //  as color increases.  The wider this is, the more scanlines need to be
    //  evaluated to avoid distortion.  For a pure Gaussian, the max_beam_sigma
    //  at which the first unused scanline always has a weight < 1.0/255.0 is:
    //      num scanlines = 2, max_beam_sigma = 0.2089; distortions begin ~0.34
    //      num scanlines = 3, max_beam_sigma = 0.3879; distortions begin ~0.52
    //      num scanlines = 4, max_beam_sigma = 0.5723; distortions begin ~0.70
    //      num scanlines = 5, max_beam_sigma = 0.7591; distortions begin ~0.89
    //      num scanlines = 6, max_beam_sigma = 0.9483; distortions begin ~1.08
    //  Generalized Gaussians permit more leeway here as steepness increases.
    if(beam_spot_shape_function < 0.5)
    {
        //  Use a power function:
        return float3(beam_min_sigma) + sigma_range *
            pow(color, float3(beam_spot_power));
    }
    else
    {
        //  Use a spherical function:
        const float3 color_minus_1 = color - float3(1.0);
        return float3(beam_min_sigma) + sigma_range *
            sqrt(float3(1.0) - color_minus_1*color_minus_1);
    }
}

inline float3 get_generalized_gaussian_beta(const float3 color,
    const float shape_range)
{
    //  Requires:   Globals:
    //              1.) beam_min_shape and beam_max_shape are global floats
    //                  containing the desired min/max generalized Gaussian
    //                  beta parameters, for dim and bright colors respectively.
    //              2.) beam_max_shape must be >= 2.0
    //              3.) beam_min_shape must be in [2.0, beam_max_shape]
    //              4.) beam_shape_power must be defined as a global float.
    //              Parameters:
    //              1.) color is the underlying source color along a scanline
    //              2.) shape_range = beam_max_shape - beam_min_shape; we take
    //                  shape_range as a parameter to avoid repeated computation
    //                  when beam_{min, max}_shape are runtime shader parameters
    //  Returns:    The type-I generalized Gaussian "shape" parameter beta for
    //              the given color.
    //  Details/Discussion:
    //  Beta affects the scanline distribution as follows:
    //  a.) beta < 2.0 narrows the peak to a spike with a discontinuous slope
    //  b.) beta == 2.0 just degenerates to a Gaussian
    //  c.) beta > 2.0 flattens and widens the peak, then drops off more steeply
    //      than a Gaussian.  Whereas high sigmas widen and soften peaks, high
    //      beta widen and sharpen peaks at the risk of aliasing.
    //  Unlike high beam_spot_powers, high beam_shape_powers actually soften shape
    //  transitions, whereas lower ones sharpen them (at the risk of aliasing).
    return beam_min_shape + shape_range * pow(color, float3(beam_shape_power));
}

float3 scanline_gaussian_integral_contrib(const float3 dist,
    const float3 color, const float pixel_height, const float sigma_range)
{
    //  Requires:   1.) dist is the distance of the [potentially separate R/G/B]
    //                  point(s) from a scanline in units of scanlines, where
    //                  1.0 means the sample point straddles the next scanline.
    //              2.) color is the underlying source color along a scanline.
    //              3.) pixel_height is the output pixel height in scanlines.
    //              4.) Requirements of get_gaussian_sigma() must be met.
    //  Returns:    Return a scanline's light output over a given pixel.
    //  Details:
    //  The CRT beam profile follows a roughly Gaussian distribution which is
    //  wider for bright colors than dark ones.  The integral over the full
    //  range of a Gaussian function is always 1.0, so we can vary the beam
    //  with a standard deviation without affecting brightness.  'x' = distance:
    //      gaussian sample = 1/(sigma*sqrt(2*pi)) * e**(-(x**2)/(2*sigma**2))
    //      gaussian integral = 0.5 (1.0 + erf(x/(sigma * sqrt(2))))
    //  Use a numerical approximation of the "error function" (the Gaussian
    //  indefinite integral) to find the definite integral of the scanline's
    //  average brightness over a given pixel area.  Even if curved coords were
    //  used in this pass, a flat scalar pixel height works almost as well as a
    //  pixel height computed from a full pixel-space to scanline-space matrix.
    const float3 sigma = get_gaussian_sigma(color, sigma_range);
    const float3 ph_offset = float3(pixel_height * 0.5);
    const float3 denom_inv = 1.0/(sigma*sqrt(2.0));
    const float3 integral_high = erf((dist + ph_offset)*denom_inv);
    const float3 integral_low = erf((dist - ph_offset)*denom_inv);
    return color * 0.5*(integral_high - integral_low)/pixel_height;
}

float3 scanline_generalized_gaussian_integral_contrib(float3 dist,
    float3 color, float pixel_height, float sigma_range,
    float shape_range)
{
    //  Requires:   1.) Requirements of scanline_gaussian_integral_contrib()
    //                  must be met.
    //              2.) Requirements of get_gaussian_sigma() must be met.
    //              3.) Requirements of get_generalized_gaussian_beta() must be
    //                  met.
    //  Returns:    Return a scanline's light output over a given pixel.
    //  A generalized Gaussian distribution allows the shape (beta) to vary
    //  as well as the width (alpha).  "gamma" refers to the gamma function:
    //      generalized sample =
    //          beta/(2*alpha*gamma(1/beta)) * e**(-(|x|/alpha)**beta)
    //  ligamma(s, z) is the lower incomplete gamma function, for which we only
    //  implement two of four branches (because we keep 1/beta <= 0.5):
    //      generalized integral = 0.5 + 0.5* sign(x) *
    //          ligamma(1/beta, (|x|/alpha)**beta)/gamma(1/beta)
    //  See get_generalized_gaussian_beta() for a discussion of beta.
    //  We base alpha on the intended Gaussian sigma, but it only strictly
    //  models models standard deviation at beta == 2, because the standard
    //  deviation depends on both alpha and beta (keeping alpha independent is
    //  faster and preserves intuitive behavior and a full spectrum of results).
    const float3 alpha = sqrt(2.0) * get_gaussian_sigma(color, sigma_range);
    const float3 beta = get_generalized_gaussian_beta(color, shape_range);
    const float3 alpha_inv = float3(1.0)/alpha;
    const float3 s = float3(1.0)/beta;
    const float3 ph_offset = float3(pixel_height * 0.5);
    //  Pass beta to gamma_impl to avoid repeated divides.  Similarly pass
    //  beta (i.e. 1/s) and 1/gamma(s) to normalized_ligamma_impl.
    const float3 gamma_s_inv = float3(1.0)/gamma_impl(s, beta);
    const float3 dist1 = dist + ph_offset;
    const float3 dist0 = dist - ph_offset;
    const float3 integral_high = sign(dist1) * normalized_ligamma_impl(
        s, pow(abs(dist1)*alpha_inv, beta), beta, gamma_s_inv);
    const float3 integral_low = sign(dist0) * normalized_ligamma_impl(
        s, pow(abs(dist0)*alpha_inv, beta), beta, gamma_s_inv);
    return color * 0.5*(integral_high - integral_low)/pixel_height;
}

float3 scanline_gaussian_sampled_contrib(const float3 dist, const float3 color,
    const float pixel_height, const float sigma_range)
{
    //  See scanline_gaussian integral_contrib() for detailed comments!
    //  gaussian sample = 1/(sigma*sqrt(2*pi)) * e**(-(x**2)/(2*sigma**2))
    const float3 sigma = get_gaussian_sigma(color, sigma_range);
    //  Avoid repeated divides:
    const float3 sigma_inv = float3(1.0)/sigma;
    const float3 inner_denom_inv = 0.5 * sigma_inv * sigma_inv;
    const float3 outer_denom_inv = sigma_inv/sqrt(2.0*pi);
    if(beam_antialias_level > 0.5)
    {
        //  Sample 1/3 pixel away in each direction as well:
        const float3 sample_offset = float3(pixel_height/3.0);
        const float3 dist2 = dist + sample_offset;
        const float3 dist3 = abs(dist - sample_offset);
        //  Average three pure Gaussian samples:
        const float3 scale = color/3.0 * outer_denom_inv;
        const float3 weight1 = exp(-(dist*dist)*inner_denom_inv);
        const float3 weight2 = exp(-(dist2*dist2)*inner_denom_inv);
        const float3 weight3 = exp(-(dist3*dist3)*inner_denom_inv);
        return scale * (weight1 + weight2 + weight3);
    }
    else
    {
        return color*exp(-(dist*dist)*inner_denom_inv)*outer_denom_inv;
    }
}

float3 scanline_generalized_gaussian_sampled_contrib(float3 dist,
    float3 color, float pixel_height, float sigma_range,
    float shape_range)
{
    //  See scanline_generalized_gaussian_integral_contrib() for details!
    //  generalized sample =
    //      beta/(2*alpha*gamma(1/beta)) * e**(-(|x|/alpha)**beta)
    const float3 alpha = sqrt(2.0) * get_gaussian_sigma(color, sigma_range);
    const float3 beta = get_generalized_gaussian_beta(color, shape_range);
    //  Avoid repeated divides:
    const float3 alpha_inv = float3(1.0)/alpha;
    const float3 beta_inv = float3(1.0)/beta;
    const float3 scale = color * beta * 0.5 * alpha_inv /
        gamma_impl(beta_inv, beta);
    if(beam_antialias_level > 0.5)
    {
        //  Sample 1/3 pixel closer to and farther from the scanline too.
        const float3 sample_offset = float3(pixel_height/3.0);
        const float3 dist2 = dist + sample_offset;
        const float3 dist3 = abs(dist - sample_offset);
        //  Average three generalized Gaussian samples:
        const float3 weight1 = exp(-pow(abs(dist*alpha_inv), beta));
        const float3 weight2 = exp(-pow(abs(dist2*alpha_inv), beta));
        const float3 weight3 = exp(-pow(abs(dist3*alpha_inv), beta));
        return scale/3.0 * (weight1 + weight2 + weight3);
    }
    else
    {
        return scale * exp(-pow(abs(dist*alpha_inv), beta));
    }
}

inline float3 scanline_contrib(float3 dist, float3 color,
    float pixel_height, const float sigma_range, const float shape_range)
{
    //  Requires:   1.) Requirements of scanline_gaussian_integral_contrib()
    //                  must be met.
    //              2.) Requirements of get_gaussian_sigma() must be met.
    //              3.) Requirements of get_generalized_gaussian_beta() must be
    //                  met.
    //  Returns:    Return a scanline's light output over a given pixel, using
    //              a generalized or pure Gaussian distribution and sampling or
    //              integrals as desired by user codepath choices.
    if(beam_generalized_gaussian)
    {
        if(beam_antialias_level > 1.5)
        {
            return scanline_generalized_gaussian_integral_contrib(
                dist, color, pixel_height, sigma_range, shape_range);
        }
        else
        {
            return scanline_generalized_gaussian_sampled_contrib(
                dist, color, pixel_height, sigma_range, shape_range);
        }
    }
    else
    {
        if(beam_antialias_level > 1.5)
        {
            return scanline_gaussian_integral_contrib(
                dist, color, pixel_height, sigma_range);
        }
        else
        {
            return scanline_gaussian_sampled_contrib(
                dist, color, pixel_height, sigma_range);
        }
    }
}

inline float3 get_raw_interpolated_color(const float3 color0,
    const float3 color1, const float3 color2, const float3 color3,
    const float4 weights)
{
    //  Use max to avoid bizarre artifacts from negative colors:
    return max(mul(weights, float4x3(color0, color1, color2, color3)), 0.0);
}

float3 get_interpolated_linear_color(const float3 color0, const float3 color1,
    const float3 color2, const float3 color3, const float4 weights)
{
    //  Requires:   1.) Requirements of include/gamma-management.h must be met:
    //                  intermediate_gamma must be globally defined, and input
    //                  colors are interpreted as linear RGB unless you #define
    //                  GAMMA_ENCODE_EVERY_FBO (in which case they are
    //                  interpreted as gamma-encoded with intermediate_gamma).
    //              2.) color0-3 are colors sampled from a texture with tex2D().
    //                  They are interpreted as defined in requirement 1.
    //              3.) weights contains weights for each color, summing to 1.0.
    //              4.) beam_horiz_linear_rgb_weight must be defined as a global
    //                  float in [0.0, 1.0] describing how much blending should
    //                  be done in linear RGB (rest is gamma-corrected RGB).
    //              5.) RUNTIME_SCANLINES_HORIZ_FILTER_COLORSPACE must be #defined
    //                  if beam_horiz_linear_rgb_weight is anything other than a
    //                  static constant, or we may try branching at runtime
    //                  without dynamic branches allowed (slow).
    //  Returns:    Return an interpolated color lookup between the four input
    //              colors based on the weights in weights.  The final color will
    //              be a linear RGB value, but the blending will be done as
    //              indicated above.
    const float intermediate_gamma = get_intermediate_gamma();
    //  Branch if beam_horiz_linear_rgb_weight is static (for free) or if the
    //  profile allows dynamic branches (faster than computing extra pows):
    #ifndef RUNTIME_SCANLINES_HORIZ_FILTER_COLORSPACE
        #define SCANLINES_BRANCH_FOR_LINEAR_RGB_WEIGHT
    #else
        #ifdef DRIVERS_ALLOW_DYNAMIC_BRANCHES
            #define SCANLINES_BRANCH_FOR_LINEAR_RGB_WEIGHT
        #endif
    #endif
    #ifdef SCANLINES_BRANCH_FOR_LINEAR_RGB_WEIGHT
        //  beam_horiz_linear_rgb_weight is static, so we can branch:
        #ifdef GAMMA_ENCODE_EVERY_FBO
            const float3 gamma_mixed_color = pow(get_raw_interpolated_color(
                color0, color1, color2, color3, weights), float3(intermediate_gamma));
            if(beam_horiz_linear_rgb_weight > 0.0)
            {
                const float3 linear_mixed_color = get_raw_interpolated_color(
                    pow(color0, float3(intermediate_gamma)),
                    pow(color1, float3(intermediate_gamma)),
                    pow(color2, float3(intermediate_gamma)),
                    pow(color3, float3(intermediate_gamma)),
                    weights);
                return lerp(gamma_mixed_color, linear_mixed_color,
                    beam_horiz_linear_rgb_weight);
            }
            else
            {
                return gamma_mixed_color;
            }
        #else
            const float3 linear_mixed_color = get_raw_interpolated_color(
                color0, color1, color2, color3, weights);
            if(beam_horiz_linear_rgb_weight < 1.0)
            {
                const float3 gamma_mixed_color = get_raw_interpolated_color(
                    pow(color0, float3(1.0/intermediate_gamma)),
                    pow(color1, float3(1.0/intermediate_gamma)),
                    pow(color2, float3(1.0/intermediate_gamma)),
                    pow(color3, float3(1.0/intermediate_gamma)),
                    weights);
                return lerp(gamma_mixed_color, linear_mixed_color,
                    beam_horiz_linear_rgb_weight);
            }
            else
            {
                return linear_mixed_color;
            }
        #endif  //  GAMMA_ENCODE_EVERY_FBO
    #else
        #ifdef GAMMA_ENCODE_EVERY_FBO
            //  Inputs: color0-3 are colors in gamma-encoded RGB.
            const float3 gamma_mixed_color = pow(get_raw_interpolated_color(
                color0, color1, color2, color3, weights), intermediate_gamma);
            const float3 linear_mixed_color = get_raw_interpolated_color(
                pow(color0, float3(intermediate_gamma)),
                pow(color1, float3(intermediate_gamma)),
                pow(color2, float3(intermediate_gamma)),
                pow(color3, float3(intermediate_gamma)),
                weights);
            return lerp(gamma_mixed_color, linear_mixed_color,
                beam_horiz_linear_rgb_weight);
        #else
            //  Inputs: color0-3 are colors in linear RGB.
            const float3 linear_mixed_color = get_raw_interpolated_color(
                color0, color1, color2, color3, weights);
            const float3 gamma_mixed_color = get_raw_interpolated_color(
                    pow(color0, float3(1.0/intermediate_gamma)),
                    pow(color1, float3(1.0/intermediate_gamma)),
                    pow(color2, float3(1.0/intermediate_gamma)),
                    pow(color3, float3(1.0/intermediate_gamma)),
                    weights);
			// wtf fixme
//			const float beam_horiz_linear_rgb_weight1 = 1.0;
            return lerp(gamma_mixed_color, linear_mixed_color,
                beam_horiz_linear_rgb_weight);
        #endif  //  GAMMA_ENCODE_EVERY_FBO
    #endif  //  SCANLINES_BRANCH_FOR_LINEAR_RGB_WEIGHT
}

float3 get_scanline_color(const sampler2D tex, const float2 scanline_uv,
    const float2 uv_step_x, const float4 weights)
{
    //  Requires:   1.) scanline_uv must be vertically snapped to the caller's
    //                  desired line or scanline and horizontally snapped to the
    //                  texel just left of the output pixel (color1)
    //              2.) uv_step_x must contain the horizontal uv distance
    //                  between texels.
    //              3.) weights must contain interpolation filter weights for
    //                  color0, color1, color2, and color3, where color1 is just
    //                  left of the output pixel.
    //  Returns:    Return a horizontally interpolated texture lookup using 2-4
    //              nearby texels, according to weights and the conventions of
    //              get_interpolated_linear_color().
    //  We can ignore the outside texture lookups for Quilez resampling.
    const float3 color1 = COMPAT_TEXTURE(tex, scanline_uv).rgb;
    const float3 color2 = COMPAT_TEXTURE(tex, scanline_uv + uv_step_x).rgb;
    float3 color0 = float3(0.0);
    float3 color3 = float3(0.0);
    if(beam_horiz_filter > 0.5)
    {
        color0 = COMPAT_TEXTURE(tex, scanline_uv - uv_step_x).rgb;
        color3 = COMPAT_TEXTURE(tex, scanline_uv + 2.0 * uv_step_x).rgb;
    }
    //  Sample the texture as-is, whether it's linear or gamma-encoded:
    //  get_interpolated_linear_color() will handle the difference.
    return get_interpolated_linear_color(color0, color1, color2, color3, weights);
}

float3 sample_single_scanline_horizontal(const sampler2D tex,
    const float2 tex_uv, const float2 tex_size,
    const float2 texture_size_inv)
{
    //  TODO: Add function requirements.
    //  Snap to the previous texel and get sample dists from 2/4 nearby texels:
    const float2 curr_texel = tex_uv * tex_size;
    //  Use under_half to fix a rounding bug right around exact texel locations.
    const float2 prev_texel =
        floor(curr_texel - float2(under_half)) + float2(0.5);
    const float2 prev_texel_hor = float2(prev_texel.x, curr_texel.y);
    const float2 prev_texel_hor_uv = prev_texel_hor * texture_size_inv;
    const float prev_dist = curr_texel.x - prev_texel_hor.x;
    const float4 sample_dists = float4(1.0 + prev_dist, prev_dist,
        1.0 - prev_dist, 2.0 - prev_dist);
    //  Get Quilez, Lanczos2, or Gaussian resize weights for 2/4 nearby texels:
    float4 weights;
    if(beam_horiz_filter < 0.5)
    {
        //  Quilez:
        const float x = sample_dists.y;
        const float w2 = x*x*x*(x*(x*6.0 - 15.0) + 10.0);
        weights = float4(0.0, 1.0 - w2, w2, 0.0);
    }
    else if(beam_horiz_filter < 1.5)
    {
        //  Gaussian:
        float inner_denom_inv = 1.0/(2.0*beam_horiz_sigma*beam_horiz_sigma);
        weights = exp(-(sample_dists*sample_dists)*inner_denom_inv);
    }
    else
    {
        //  Lanczos2:
        const float4 pi_dists = FIX_ZERO(sample_dists * pi);
        weights = 2.0 * sin(pi_dists) * sin(pi_dists * 0.5) /
            (pi_dists * pi_dists);
    }
    //  Ensure the weight sum == 1.0:
    const float4 final_weights = weights/dot(weights, float4(1.0));
    //  Get the interpolated horizontal scanline color:
    const float2 uv_step_x = float2(texture_size_inv.x, 0.0);
    return get_scanline_color(
        tex, prev_texel_hor_uv, uv_step_x, final_weights);
}

float3 sample_rgb_scanline_horizontal(const sampler2D tex,
    const float2 tex_uv, const float2 tex_size,
    const float2 texture_size_inv)
{
    //  TODO: Add function requirements.
    //  Rely on a helper to make convergence easier.
    if(beam_misconvergence)
    {
        const float3 convergence_offsets_rgb =
            get_convergence_offsets_x_vector();
        const float3 offset_u_rgb =
            convergence_offsets_rgb * texture_size_inv.xxx;
        const float2 scanline_uv_r = tex_uv - float2(offset_u_rgb.r, 0.0);
        const float2 scanline_uv_g = tex_uv - float2(offset_u_rgb.g, 0.0);
        const float2 scanline_uv_b = tex_uv - float2(offset_u_rgb.b, 0.0);
        const float3 sample_r = sample_single_scanline_horizontal(
            tex, scanline_uv_r, tex_size, texture_size_inv);
        const float3 sample_g = sample_single_scanline_horizontal(
            tex, scanline_uv_g, tex_size, texture_size_inv);
        const float3 sample_b = sample_single_scanline_horizontal(
            tex, scanline_uv_b, tex_size, texture_size_inv);
        return float3(sample_r.r, sample_g.g, sample_b.b);
    }
    else
    {
        return sample_single_scanline_horizontal(tex, tex_uv, tex_size,
            texture_size_inv);
    }
}

float2 get_last_scanline_uv(const float2 tex_uv, const float2 tex_size,
    const float2 texture_size_inv, const float2 il_step_multiple,
    const float frame_count, out float dist)
{
    //  Compute texture coords for the last/upper scanline, accounting for
    //  interlacing: With interlacing, only consider even/odd scanlines every
    //  other frame.  Top-field first (TFF) order puts even scanlines on even
    //  frames, and BFF order puts them on odd frames.  Texels are centered at:
    //      frac(tex_uv * tex_size) == x.5
    //  Caution: If these coordinates ever seem incorrect, first make sure it's
    //  not because anisotropic filtering is blurring across field boundaries.
    //  Note: TFF/BFF won't matter for sources that double-weave or similar.
	// wtf fixme
//	const float interlace_bff1 = 1.0;
    const float field_offset = floor(il_step_multiple.y * 0.75) *
        fmod(frame_count + float(interlace_bff), 2.0);
    const float2 curr_texel = tex_uv * tex_size;
    //  Use under_half to fix a rounding bug right around exact texel locations.
    const float2 prev_texel_num = floor(curr_texel - float2(under_half));
    const float wrong_field = fmod(
        prev_texel_num.y + field_offset, il_step_multiple.y);
    const float2 scanline_texel_num = prev_texel_num - float2(0.0, wrong_field);
    //  Snap to the center of the previous scanline in the current field:
    const float2 scanline_texel = scanline_texel_num + float2(0.5);
    const float2 scanline_uv = scanline_texel * texture_size_inv;
    //  Save the sample's distance from the scanline, in units of scanlines:
    dist = (curr_texel.y - scanline_texel.y)/il_step_multiple.y;
    return scanline_uv;
}

inline bool is_interlaced(float num_lines)
{
    //  Detect interlacing based on the number of lines in the source.
    if(interlace_detect)
    {
        //  NTSC: 525 lines, 262.5/field; 486 active (2 half-lines), 243/field
        //  NTSC Emulators: Typically 224 or 240 lines
        //  PAL: 625 lines, 312.5/field; 576 active (typical), 288/field
        //  PAL Emulators: ?
        //  ATSC: 720p, 1080i, 1080p
        //  Where do we place our cutoffs?  Assumptions:
        //  1.) We only need to care about active lines.
        //  2.) Anything > 288 and <= 576 lines is probably interlaced.
        //  3.) Anything > 576 lines is probably not interlaced...
        //  4.) ...except 1080 lines, which is a crapshoot (user decision).
        //  5.) Just in case the main program uses calculated video sizes,
        //      we should nudge the float thresholds a bit.
        const bool sd_interlace = ((num_lines > 288.5) && (num_lines < 576.5));
        const bool hd_interlace = bool(interlace_1080i) ?
            ((num_lines > 1079.5) && (num_lines < 1080.5)) :
            false;
        return (sd_interlace || hd_interlace);
    }
    else
    {
        return false;
    }
}

#endif  //  SCANLINE_FUNCTIONS_H

/////////////////////////////  END SCANLINE-FUNCTIONS  ////////////////////////////

/***************** END scanline-functions.h ******************/


///////////////////////////////  END VERTEX INCLUDES  /////////////////////////////

#undef COMPAT_PRECISION
#undef COMPAT_TEXTURE

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 tex_uv;
COMPAT_VARYING vec2 blur_dxdy;
COMPAT_VARYING vec2 uv_scanline_step;
COMPAT_VARYING float estimated_viewport_size_x;
COMPAT_VARYING vec2 texture_size_inv;
COMPAT_VARYING vec2 tex_uv_to_pixel_scale;

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform COMPAT_PRECISION vec2 PassPrev2TextureSize;
uniform COMPAT_PRECISION vec2 PassPrev2InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

COMPAT_PRECISION float bloom_approx_scale_x = OutputSize.x / TextureSize.y;
const COMPAT_PRECISION float max_viewport_size_x = 1080.0*1024.0*(4.0/3.0);

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;
	const float2 video_uv = vTexCoord * texture_size/video_size;
    tex_uv = video_uv * ORIG_LINEARIZEDvideo_size /
        ORIG_LINEARIZEDtexture_size;
    //  The last pass (vertical scanlines) had a viewport y scale, so we can
    //  use it to calculate a better runtime sigma:
    estimated_viewport_size_x =
        video_size.y * geom_aspect_ratio_x/geom_aspect_ratio_y;

    //  Get the uv sample distance between output pixels.  We're using a resize
    //  blur, so arbitrary upsizing will be acceptable if filter_linearN =
    //  "true," and arbitrary downsizing will be acceptable if mipmap_inputN =
    //  "true" too.  The blur will be much more accurate if a true 4x4 Gaussian
    //  resize is used instead of tex2Dblur3x3_resize (which samples between
    //  texels even for upsizing).
    const float2 dxdy_min_scale = ORIG_LINEARIZEDvideo_size/output_size;
    const float2 texture_size_inv = float2(1.0, 1.0)/ORIG_LINEARIZEDtexture_size;
    if(bloom_approx_filter > 1.5)   //  4x4 true Gaussian resize
    {
        //  For upsizing, we'll snap to texels and sample the nearest 4.
        const float2 dxdy_scale = max(dxdy_min_scale, float2(1.0, 1.0));
        blur_dxdy = dxdy_scale * texture_size_inv;
    }
    else
    {
        const float2 dxdy_scale = dxdy_min_scale;
        blur_dxdy = dxdy_scale * texture_size_inv;
    }
    //  tex2Dresize_gaussian4x4 needs to know a bit more than the other filters:
    tex_uv_to_pixel_scale = output_size *
        ORIG_LINEARIZEDtexture_size / ORIG_LINEARIZEDvideo_size;
    //texture_size_inv = texture_size_inv;

    //  Detecting interlacing again here lets us apply convergence offsets in
    //  this pass.  il_step_multiple contains the (texel, scanline) step
    //  multiple: 1 for progressive, 2 for interlaced.
    const float2 orig_video_size = ORIG_LINEARIZEDvideo_size;
    const float y_step = 1.0 + float(is_interlaced(orig_video_size.y));
    const float2 il_step_multiple = float2(1.0, y_step);
    //  Get the uv distance between (texels, same-field scanlines):
    uv_scanline_step = il_step_multiple / ORIG_LINEARIZEDtexture_size;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out COMPAT_PRECISION vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
uniform sampler2D PassPrev2Texture;
#define ORIG_LINEARIZED PassPrev2Texture
uniform COMPAT_PRECISION vec2 PassPrev2TextureSize;
uniform COMPAT_PRECISION vec2 PassPrev2InputSize;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 tex_uv;
COMPAT_VARYING vec2 blur_dxdy;
COMPAT_VARYING vec2 uv_scanline_step;
COMPAT_VARYING float estimated_viewport_size_x;
COMPAT_VARYING vec2 texture_size_inv;
COMPAT_VARYING vec2 tex_uv_to_pixel_scale;

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

COMPAT_PRECISION float bloom_approx_scale_x = OutputSize.x / TextureSize.y;
const COMPAT_PRECISION float max_viewport_size_x = 1080.0*1024.0*(4.0/3.0);

//////////////////////////////  FRAGMENT INCLUDES  //////////////////////////////

//#include "../include/blur-functions.h"
/***************** BEGIN blur-functions.h ******************/

////////////////////////////  BEGIN BLUR-FUNCTIONS  ///////////////////////////

#ifndef BLUR_FUNCTIONS_H
#define BLUR_FUNCTIONS_H

/////////////////////////////////  MIT LICENSE  ////////////////////////////////

//  Copyright (C) 2014 TroggleMonkey
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

/////////////////////////////////  DESCRIPTION  ////////////////////////////////

//  This file provides reusable one-pass and separable (two-pass) blurs.
//  Requires:   All blurs share these requirements (dxdy requirement is split):
//              1.) All requirements of gamma-management.h must be satisfied!
//              2.) filter_linearN must == "true" in your .cgp preset unless
//                  you're using tex2DblurNresize at 1x scale.
//              3.) mipmap_inputN must == "true" in your .cgp preset if
//                  IN.output_size < IN.video_size.
//              4.) IN.output_size == IN.video_size / pow(2, M), where M is some
//                  positive integer.  tex2Dblur*resize can resize arbitrarily
//                  (and the blur will be done after resizing), but arbitrary
//                  resizes "fail" with other blurs due to the way they mix
//                  static weights with bilinear sample exploitation.
//              5.) In general, dxdy should contain the uv pixel spacing:
//                      dxdy = (IN.video_size/IN.output_size)/IN.texture_size
//              6.) For separable blurs (tex2DblurNresize and tex2DblurNfast),
//                  zero out the dxdy component in the unblurred dimension:
//                      dxdy = float2(dxdy.x, 0.0) or float2(0.0, dxdy.y)
//              Many blurs share these requirements:
//              1.) One-pass blurs require scale_xN == scale_yN or scales > 1.0,
//                  or they will blur more in the lower-scaled dimension.
//              2.) One-pass shared sample blurs require ddx(), ddy(), and
//                  tex2Dlod() to be supported by the current Cg profile, and
//                  the drivers must support high-quality derivatives.
//              3.) One-pass shared sample blurs require:
//                      tex_uv.w == log2(IN.video_size/IN.output_size).y;
//              Non-wrapper blurs share this requirement:
//              1.) sigma is the intended standard deviation of the blur
//              Wrapper blurs share this requirement, which is automatically
//              met (unless OVERRIDE_BLUR_STD_DEVS is #defined; see below):
//              1.) blurN_std_dev must be global static const float values
//                  specifying standard deviations for Nx blurs in units
//                  of destination pixels
//  Optional:   1.) The including file (or an earlier included file) may
//                  optionally #define USE_BINOMIAL_BLUR_STD_DEVS to replace
//                  default standard deviations with those matching a binomial
//                  distribution.  (See below for details/properties.)
//              2.) The including file (or an earlier included file) may
//                  optionally #define OVERRIDE_BLUR_STD_DEVS and override:
//                      static const float blur3_std_dev
//                      static const float blur4_std_dev
//                      static const float blur5_std_dev
//                      static const float blur6_std_dev
//                      static const float blur7_std_dev
//                      static const float blur8_std_dev
//                      static const float blur9_std_dev
//                      static const float blur10_std_dev
//                      static const float blur11_std_dev
//                      static const float blur12_std_dev
//                      static const float blur17_std_dev
//                      static const float blur25_std_dev
//                      static const float blur31_std_dev
//                      static const float blur43_std_dev
//              3.) The including file (or an earlier included file) may
//                  optionally #define OVERRIDE_ERROR_BLURRING and override:
//                      static const float error_blurring
//                  This tuning value helps mitigate weighting errors from one-
//                  pass shared-sample blurs sharing bilinear samples between
//                  fragments.  Values closer to 0.0 have "correct" blurriness
//                  but allow more artifacts, and values closer to 1.0 blur away
//                  artifacts by sampling closer to halfway between texels.
//              UPDATE 6/21/14: The above static constants may now be overridden
//              by non-static uniform constants.  This permits exposing blur
//              standard deviations as runtime GUI shader parameters.  However,
//              using them keeps weights from being statically computed, and the
//              speed hit depends on the blur: On my machine, uniforms kill over
//              53% of the framerate with tex2Dblur12x12shared, but they only
//              drop the framerate by about 18% with tex2Dblur11fast.
//  Quality and Performance Comparisons:
//  For the purposes of the following discussion, "no sRGB" means
//  GAMMA_ENCODE_EVERY_FBO is #defined, and "sRGB" means it isn't.
//  1.) tex2DblurNfast is always faster than tex2DblurNresize.
//  2.) tex2DblurNresize functions are the only ones that can arbitrarily resize
//      well, because they're the only ones that don't exploit bilinear samples.
//      This also means they're the only functions which can be truly gamma-
//      correct without linear (or sRGB FBO) input, but only at 1x scale.
//  3.) One-pass shared sample blurs only have a speed advantage without sRGB.
//      They also have some inaccuracies due to their shared-[bilinear-]sample
//      design, which grow increasingly bothersome for smaller blurs and higher-
//      frequency source images (relative to their resolution).  I had high
//      hopes for them, but their most realistic use case is limited to quickly
//      reblurring an already blurred input at full resolution.  Otherwise:
//      a.) If you're blurring a low-resolution source, you want a better blur.
//      b.) If you're blurring a lower mipmap, you want a better blur.
//      c.) If you're blurring a high-resolution, high-frequency source, you
//          want a better blur.
//  4.) The one-pass blurs without shared samples grow slower for larger blurs,
//      but they're competitive with separable blurs at 5x5 and smaller, and
//      even tex2Dblur7x7 isn't bad if you're wanting to conserve passes.
//  Here are some framerates from a GeForce 8800GTS.  The first pass resizes to
//  viewport size (4x in this test) and linearizes for sRGB codepaths, and the
//  remaining passes perform 6 full blurs.  Mipmapped tests are performed at the
//  same scale, so they just measure the cost of mipmapping each FBO (only every
//  other FBO is mipmapped for separable blurs, to mimic realistic usage).
//  Mipmap      Neither     sRGB+Mipmap sRGB        Function
//  76.0        92.3        131.3       193.7       tex2Dblur3fast
//  63.2        74.4        122.4       175.5       tex2Dblur3resize
//  93.7        121.2       159.3       263.2       tex2Dblur3x3
//  59.7        68.7        115.4       162.1       tex2Dblur3x3resize
//  63.2        74.4        122.4       175.5       tex2Dblur5fast
//  49.3        54.8        100.0       132.7       tex2Dblur5resize
//  59.7        68.7        115.4       162.1       tex2Dblur5x5
//  64.9        77.2        99.1        137.2       tex2Dblur6x6shared
//  55.8        63.7        110.4       151.8       tex2Dblur7fast
//  39.8        43.9        83.9        105.8       tex2Dblur7resize
//  40.0        44.2        83.2        104.9       tex2Dblur7x7
//  56.4        65.5        71.9        87.9        tex2Dblur8x8shared
//  49.3        55.1        99.9        132.5       tex2Dblur9fast
//  33.3        36.2        72.4        88.0        tex2Dblur9resize
//  27.8        29.7        61.3        72.2        tex2Dblur9x9
//  37.2        41.1        52.6        60.2        tex2Dblur10x10shared
//  44.4        49.5        91.3        117.8       tex2Dblur11fast
//  28.8        30.8        63.6        75.4        tex2Dblur11resize
//  33.6        36.5        40.9        45.5        tex2Dblur12x12shared
//  TODO: Fill in benchmarks for new untested blurs.
//                                                  tex2Dblur17fast
//                                                  tex2Dblur25fast
//                                                  tex2Dblur31fast
//                                                  tex2Dblur43fast
//                                                  tex2Dblur3x3resize


/////////////////////////////  SETTINGS MANAGEMENT  ////////////////////////////

//  Set static standard deviations, but allow users to override them with their
//  own constants (even non-static uniforms if they're okay with the speed hit):
#ifndef OVERRIDE_BLUR_STD_DEVS
    //  blurN_std_dev values are specified in terms of dxdy strides.
    #ifdef USE_BINOMIAL_BLUR_STD_DEVS
        //  By request, we can define standard deviations corresponding to a
        //  binomial distribution with p = 0.5 (related to Pascal's triangle).
        //  This distribution works such that blurring multiple times should
        //  have the same result as a single larger blur.  These values are
        //  larger than default for blurs up to 6x and smaller thereafter.
        static const float blur3_std_dev = 0.84931640625;
        static const float blur4_std_dev = 0.84931640625;
        static const float blur5_std_dev = 1.0595703125;
        static const float blur6_std_dev = 1.06591796875;
        static const float blur7_std_dev = 1.17041015625;
        static const float blur8_std_dev = 1.1720703125;
        static const float blur9_std_dev = 1.2259765625;
        static const float blur10_std_dev = 1.21982421875;
        static const float blur11_std_dev = 1.25361328125;
        static const float blur12_std_dev = 1.2423828125;
        static const float blur17_std_dev = 1.27783203125;
        static const float blur25_std_dev = 1.2810546875;
        static const float blur31_std_dev = 1.28125;
        static const float blur43_std_dev = 1.28125;
    #else
        //  The defaults are the largest values that keep the largest unused
        //  blur term on each side <= 1.0/256.0.  (We could get away with more
        //  or be more conservative, but this compromise is pretty reasonable.)
        static const float blur3_std_dev = 0.62666015625;
        static const float blur4_std_dev = 0.66171875;
        static const float blur5_std_dev = 0.9845703125;
        static const float blur6_std_dev = 1.02626953125;
        static const float blur7_std_dev = 1.36103515625;
        static const float blur8_std_dev = 1.4080078125;
        static const float blur9_std_dev = 1.7533203125;
        static const float blur10_std_dev = 1.80478515625;
        static const float blur11_std_dev = 2.15986328125;
        static const float blur12_std_dev = 2.215234375;
        static const float blur17_std_dev = 3.45535583496;
        static const float blur25_std_dev = 5.3409576416;
        static const float blur31_std_dev = 6.86488037109;
        static const float blur43_std_dev = 10.1852050781;
    #endif  //  USE_BINOMIAL_BLUR_STD_DEVS
#endif  //  OVERRIDE_BLUR_STD_DEVS

#ifndef OVERRIDE_ERROR_BLURRING
    //  error_blurring should be in [0.0, 1.0].  Higher values reduce ringing
    //  in shared-sample blurs but increase blurring and feature shifting.
    static const float error_blurring = 0.5;
#endif


//////////////////////////////////  INCLUDES  //////////////////////////////////

//  gamma-management.h relies on pass-specific settings to guide its behavior:
//  FIRST_PASS, LAST_PASS, GAMMA_ENCODE_EVERY_FBO, etc.  See it for details.
//#include "../include/gamma-management.h"
//#include "../include/quad-pixel-communication.h"
/***************** BEGIN quad-pixel-communication.h ******************/

///////////////////////  BEGIN QUAD-PIXEL-COMMUNICATION  //////////////////////

#ifndef QUAD_PIXEL_COMMUNICATION_H
#define QUAD_PIXEL_COMMUNICATION_H

/////////////////////////////////  MIT LICENSE  ////////////////////////////////

//  Copyright (C) 2014 TroggleMonkey*
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

/////////////////////////////////  DISCLAIMER  /////////////////////////////////

//  *This code was inspired by "Shader Amortization using Pixel Quad Message
//  Passing" by Eric Penner, published in GPU Pro 2, Chapter VI.2.  My intent
//  is not to plagiarize his fundamentally similar code and assert my own
//  copyright, but the algorithmic helper functions require so little code that
//  implementations can't vary by much except bugfixes and conventions.  I just
//  wanted to license my own particular code here to avoid ambiguity and make it
//  clear that as far as I'm concerned, people can do as they please with it.

/////////////////////////////////  DESCRIPTION  ////////////////////////////////

//  Given screen pixel numbers, derive a "quad vector" describing a fragment's
//  position in its 2x2 pixel quad.  Given that vector, obtain the values of any
//  variable at neighboring fragments.
//  Requires:   Using this file in general requires:
//              1.) ddx() and ddy() are present in the current Cg profile.
//              2.) The GPU driver is using fine/high-quality derivatives.
//                  Functions will give incorrect results if this is not true,
//                  so a test function is included.


/////////////////////  QUAD-PIXEL COMMUNICATION PRIMITIVES  ////////////////////

float4 get_quad_vector_naive(float4 output_pixel_num_wrt_uvxy)
{
    //  Requires:   Two measures of the current fragment's output pixel number
    //              in the range ([0, IN.output_size.x), [0, IN.output_size.y)):
    //              1.) output_pixel_num_wrt_uvxy.xy increase with uv coords.
    //              2.) output_pixel_num_wrt_uvxy.zw increase with screen xy.
    //  Returns:    Two measures of the fragment's position in its 2x2 quad:
    //              1.) The .xy components are its 2x2 placement with respect to
    //                  uv direction (the origin (0, 0) is at the top-left):
    //                  top-left     = (-1.0, -1.0) top-right    = ( 1.0, -1.0)
    //                  bottom-left  = (-1.0,  1.0) bottom-right = ( 1.0,  1.0)
    //                  You need this to arrange/weight shared texture samples.
    //              2.) The .zw components are its 2x2 placement with respect to
    //                  screen xy direction (IN.position); the origin varies.
    //                  quad_gather needs this measure to work correctly.
    //              Note: quad_vector.zw = quad_vector.xy * float2(
    //                      ddx(output_pixel_num_wrt_uvxy.x),
    //                      ddy(output_pixel_num_wrt_uvxy.y));
    //  Caveats:    This function assumes the GPU driver always starts 2x2 pixel
    //              quads at even pixel numbers.  This assumption can be wrong
    //              for odd output resolutions (nondeterministically so).
    float4 pixel_odd = frac(output_pixel_num_wrt_uvxy * 0.5) * 2.0;
    float4 quad_vector = pixel_odd * 2.0 - float4(1.0);
    return quad_vector;
}

float4 get_quad_vector(float4 output_pixel_num_wrt_uvxy)
{
    //  Requires:   Same as get_quad_vector_naive() (see that first).
    //  Returns:    Same as get_quad_vector_naive() (see that first), but it's
    //              correct even if the 2x2 pixel quad starts at an odd pixel,
    //              which can occur at odd resolutions.
    float4 quad_vector_guess =
        get_quad_vector_naive(output_pixel_num_wrt_uvxy);
    //  If quad_vector_guess.zw doesn't increase with screen xy, we know
    //  the 2x2 pixel quad starts at an odd pixel:
    float2 odd_start_mirror = 0.5 * float2(ddx(quad_vector_guess.z),
                                                ddy(quad_vector_guess.w));
    return quad_vector_guess * odd_start_mirror.xyxy;
}

float4 get_quad_vector(float2 output_pixel_num_wrt_uv)
{
    //  Requires:   1.) ddx() and ddy() are present in the current Cg profile.
    //              2.) output_pixel_num_wrt_uv must increase with uv coords and
    //                  measure the current fragment's output pixel number in:
    //                      ([0, IN.output_size.x), [0, IN.output_size.y))
    //  Returns:    Same as get_quad_vector_naive() (see that first), but it's
    //              correct even if the 2x2 pixel quad starts at an odd pixel,
    //              which can occur at odd resolutions.
    //  Caveats:    This function requires less information than the version
    //              taking a float4, but it's potentially slower.
    //  Do screen coords increase with or against uv?  Get the direction
    //  with respect to (uv.x, uv.y) for (screen.x, screen.y) in {-1, 1}.
    float2 screen_uv_mirror = float2(ddx(output_pixel_num_wrt_uv.x),
                                        ddy(output_pixel_num_wrt_uv.y));
    float2 pixel_odd_wrt_uv = frac(output_pixel_num_wrt_uv * 0.5) * 2.0;
    float2 quad_vector_uv_guess = (pixel_odd_wrt_uv - float2(0.5)) * 2.0;
    float2 quad_vector_screen_guess = quad_vector_uv_guess * screen_uv_mirror;
    //  If quad_vector_screen_guess doesn't increase with screen xy, we know
    //  the 2x2 pixel quad starts at an odd pixel:
    float2 odd_start_mirror = 0.5 * float2(ddx(quad_vector_screen_guess.x),
                                                ddy(quad_vector_screen_guess.y));
    float4 quad_vector_guess = float4(
        quad_vector_uv_guess, quad_vector_screen_guess);
    return quad_vector_guess * odd_start_mirror.xyxy;
}

void quad_gather(float4 quad_vector, float4 curr,
    out float4 adjx, out float4 adjy, out float4 diag)
{
    //  Requires:   1.) ddx() and ddy() are present in the current Cg profile.
    //              2.) The GPU driver is using fine/high-quality derivatives.
    //              3.) quad_vector describes the current fragment's location in
    //                  its 2x2 pixel quad using get_quad_vector()'s conventions.
    //              4.) curr is any vector you wish to get neighboring values of.
    //  Returns:    Values of an input vector (curr) at neighboring fragments
    //              adjacent x, adjacent y, and diagonal (via out parameters).
    adjx = curr - ddx(curr) * quad_vector.z;
    adjy = curr - ddy(curr) * quad_vector.w;
    diag = adjx - ddy(adjx) * quad_vector.w;
}

void quad_gather(float4 quad_vector, float3 curr,
    out float3 adjx, out float3 adjy, out float3 diag)
{
    //  Float3 version
    adjx = curr - ddx(curr) * quad_vector.z;
    adjy = curr - ddy(curr) * quad_vector.w;
    diag = adjx - ddy(adjx) * quad_vector.w;
}

void quad_gather(float4 quad_vector, float2 curr,
    out float2 adjx, out float2 adjy, out float2 diag)
{
    //  Float2 version
    adjx = curr - ddx(curr) * quad_vector.z;
    adjy = curr - ddy(curr) * quad_vector.w;
    diag = adjx - ddy(adjx) * quad_vector.w;
}

float4 quad_gather(float4 quad_vector, float curr)
{
    //  Float version:
    //  Returns:    return.x == current
    //              return.y == adjacent x
    //              return.z == adjacent y
    //              return.w == diagonal
    float4 all = float4(curr);
    all.y = all.x - ddx(all.x) * quad_vector.z;
    all.zw = all.xy - ddy(all.xy) * quad_vector.w;
    return all;
}

float4 quad_gather_sum(float4 quad_vector, float4 curr)
{
    //  Requires:   Same as quad_gather()
    //  Returns:    Sum of an input vector (curr) at all fragments in a quad.
    float4 adjx, adjy, diag;
    quad_gather(quad_vector, curr, adjx, adjy, diag);
    return (curr + adjx + adjy + diag);
}

float3 quad_gather_sum(float4 quad_vector, float3 curr)
{
    //  Float3 version:
    float3 adjx, adjy, diag;
    quad_gather(quad_vector, curr, adjx, adjy, diag);
    return (curr + adjx + adjy + diag);
}

float2 quad_gather_sum(float4 quad_vector, float2 curr)
{
    //  Float2 version:
    float2 adjx, adjy, diag;
    quad_gather(quad_vector, curr, adjx, adjy, diag);
    return (curr + adjx + adjy + diag);
}

float quad_gather_sum(float4 quad_vector, float curr)
{
    //  Float version:
    float4 all_values = quad_gather(quad_vector, curr);
    return (all_values.x + all_values.y + all_values.z + all_values.w);
}

bool fine_derivatives_working(float4 quad_vector, float4 curr)
{
    //  Requires:   1.) ddx() and ddy() are present in the current Cg profile.
    //              2.) quad_vector describes the current fragment's location in
    //                  its 2x2 pixel quad using get_quad_vector()'s conventions.
    //              3.) curr must be a test vector with non-constant derivatives
    //                  (its value should change nonlinearly across fragments).
    //  Returns:    true if fine/hybrid/high-quality derivatives are used, or
    //              false if coarse derivatives are used or inconclusive
    //  Usage:      Test whether quad-pixel communication is working!
    //  Method:     We can confirm fine derivatives are used if the following
    //              holds (ever, for any value at any fragment):
    //                  (ddy(curr) != ddy(adjx)) or (ddx(curr) != ddx(adjy))
    //              The more values we test (e.g. test a float4 two ways), the
    //              easier it is to demonstrate fine derivatives are working.
    //  TODO: Check for floating point exact comparison issues!
    float4 ddx_curr = ddx(curr);
    float4 ddy_curr = ddy(curr);
    float4 adjx = curr - ddx_curr * quad_vector.z;
    float4 adjy = curr - ddy_curr * quad_vector.w;
    bool ddy_different = any(bool4(ddy_curr.x != ddy(adjx).x, ddy_curr.y != ddy(adjx).y, ddy_curr.z != ddy(adjx).z, ddy_curr.w != ddy(adjx).w));
    bool ddx_different = any(bool4(ddx_curr.x != ddx(adjy).x, ddx_curr.y != ddx(adjy).y, ddx_curr.z != ddx(adjy).z, ddx_curr.w != ddx(adjy).w));
    return any(bool2(ddy_different, ddx_different));
}

bool fine_derivatives_working_fast(float4 quad_vector, float curr)
{
    //  Requires:   Same as fine_derivatives_working()
    //  Returns:    Same as fine_derivatives_working()
    //  Usage:      This is faster than fine_derivatives_working() but more
    //              likely to return false negatives, so it's less useful for
    //              offline testing/debugging.  It's also useless as the basis
    //              for dynamic runtime branching as of May 2014: Derivatives
    //              (and quad-pixel communication) are currently disallowed in
    //              branches.  However, future GPU's may allow you to use them
    //              in dynamic branches if you promise the branch condition
    //              evaluates the same for every fragment in the quad (and/or if
    //              the driver enforces that promise by making a single fragment
    //              control branch decisions).  If that ever happens, this
    //              version may become a more economical choice.
    float ddx_curr = ddx(curr);
    float ddy_curr = ddy(curr);
    float adjx = curr - ddx_curr * quad_vector.z;
    return (ddy_curr != ddy(adjx));
}

#endif  //  QUAD_PIXEL_COMMUNICATION_H

////////////////////////  END QUAD-PIXEL-COMMUNICATION  ///////////////////////
/***************** END quad-pixel-communication.h ******************/

//#include "../include/special-functions.h"

////////////////////////////////  END INCLUDES  ////////////////////////////////

///////////////////////////////////  HELPERS  //////////////////////////////////

inline float4 uv2_to_uv4(float2 tex_uv)
{
    //  Make a float2 uv offset safe for adding to float4 tex2Dlod coords:
    return float4(tex_uv, 0.0, 0.0);
}

//  Make a length squared helper macro (for usage with static constants):
#define LENGTH_SQ(vec) (dot(vec, vec))

inline float get_fast_gaussian_weight_sum_inv(const float sigma)
{
    //  We can use the Gaussian integral to calculate the asymptotic weight for
    //  the center pixel.  Since the unnormalized center pixel weight is 1.0,
    //  the normalized weight is the same as the weight sum inverse.  Given a
    //  large enough blur (9+), the asymptotic weight sum is close and faster:
    //      center_weight = 0.5 *
    //          (erf(0.5/(sigma*sqrt(2.0))) - erf(-0.5/(sigma*sqrt(2.0))))
    //      erf(-x) == -erf(x), so we get 0.5 * (2.0 * erf(blah blah)):
    //  However, we can get even faster results with curve-fitting.  These are
    //  also closer than the asymptotic results, because they were constructed
    //  from 64 blurs sizes from [3, 131) and 255 equally-spaced sigmas from
    //  (0, blurN_std_dev), so the results for smaller sigmas are biased toward
    //  smaller blurs.  The max error is 0.0031793913.
    //  Relative FPS: 134.3 with erf, 135.8 with curve-fitting.
    //static const float temp = 0.5/sqrt(2.0);
    //return erf(temp/sigma);
    return min(exp(exp(0.348348412457428/
        (sigma - 0.0860587260734721))), 0.399334576340352/sigma);
}


////////////////////  ARBITRARILY RESIZABLE SEPARABLE BLURS  ///////////////////

float3 tex2Dblur11resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Global requirements must be met (see file description).
    //  Returns:    A 1D 11x Gaussian blurred texture lookup using a 11-tap blur.
    //              It may be mipmapped depending on settings and dxdy.
    //  Calculate Gaussian blur kernel weights and a normalization factor for
    //  distances of 0-4, ignoring constant factors (since we're normalizing).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float weight_sum_inv = 1.0 /
        (w0 + 2.0 * (w1 + w2 + w3 + w4 + w5));
    //  Statically normalize weights, sum weighted samples, and return.  Blurs are
    //  currently optimized for dynamic weights.
    float3 sum = float3(0.0,0.0,0.0);
    sum += w5 * tex2D_linearize(tex, tex_uv - 5.0 * dxdy).rgb;
    sum += w4 * tex2D_linearize(tex, tex_uv - 4.0 * dxdy).rgb;
    sum += w3 * tex2D_linearize(tex, tex_uv - 3.0 * dxdy).rgb;
    sum += w2 * tex2D_linearize(tex, tex_uv - 2.0 * dxdy).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv - 1.0 * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv + 1.0 * dxdy).rgb;
    sum += w2 * tex2D_linearize(tex, tex_uv + 2.0 * dxdy).rgb;
    sum += w3 * tex2D_linearize(tex, tex_uv + 3.0 * dxdy).rgb;
    sum += w4 * tex2D_linearize(tex, tex_uv + 4.0 * dxdy).rgb;
    sum += w5 * tex2D_linearize(tex, tex_uv + 5.0 * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur9resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Global requirements must be met (see file description).
    //  Returns:    A 1D 9x Gaussian blurred texture lookup using a 9-tap blur.
    //              It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w4 * tex2D_linearize(tex, tex_uv - 4.0 * dxdy).rgb;
    sum += w3 * tex2D_linearize(tex, tex_uv - 3.0 * dxdy).rgb;
    sum += w2 * tex2D_linearize(tex, tex_uv - 2.0 * dxdy).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv - 1.0 * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv + 1.0 * dxdy).rgb;
    sum += w2 * tex2D_linearize(tex, tex_uv + 2.0 * dxdy).rgb;
    sum += w3 * tex2D_linearize(tex, tex_uv + 3.0 * dxdy).rgb;
    sum += w4 * tex2D_linearize(tex, tex_uv + 4.0 * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur7resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Global requirements must be met (see file description).
    //  Returns:    A 1D 7x Gaussian blurred texture lookup using a 7-tap blur.
    //              It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3));
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w3 * tex2D_linearize(tex, tex_uv - 3.0 * dxdy).rgb;
    sum += w2 * tex2D_linearize(tex, tex_uv - 2.0 * dxdy).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv - 1.0 * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv + 1.0 * dxdy).rgb;
    sum += w2 * tex2D_linearize(tex, tex_uv + 2.0 * dxdy).rgb;
    sum += w3 * tex2D_linearize(tex, tex_uv + 3.0 * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur5resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Global requirements must be met (see file description).
    //  Returns:    A 1D 5x Gaussian blurred texture lookup using a 5-tap blur.
    //              It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2));
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w2 * tex2D_linearize(tex, tex_uv - 2.0 * dxdy).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv - 1.0 * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv + 1.0 * dxdy).rgb;
    sum += w2 * tex2D_linearize(tex, tex_uv + 2.0 * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur3resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Global requirements must be met (see file description).
    //  Returns:    A 1D 3x Gaussian blurred texture lookup using a 3-tap blur.
    //              It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * w1);
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w1 * tex2D_linearize(tex, tex_uv - 1.0 * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w1 * tex2D_linearize(tex, tex_uv + 1.0 * dxdy).rgb;
    return sum * weight_sum_inv;
}


///////////////////////////  FAST SEPARABLE BLURS  ///////////////////////////

float3 tex2Dblur11fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   1.) Global requirements must be met (see file description).
    //              2.) filter_linearN must = "true" in your .cgp file.
    //              3.) For gamma-correct bilinear filtering, global
    //                  gamma_aware_bilinear == true (from gamma-management.h)
    //  Returns:    A 1D 11x Gaussian blurred texture lookup using 6 linear
    //              taps.  It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float weight_sum_inv = 1.0 /
        (w0 + 2.0 * (w1 + w2 + w3 + w4 + w5));
    //  Calculate combined weights and linear sample ratios between texel pairs.
    //  The center texel (with weight w0) is used twice, so halve its weight.
    const float w01 = w0 * 0.5 + w1;
    const float w23 = w2 + w3;
    const float w45 = w4 + w5;
    const float w01_ratio = w1/w01;
    const float w23_ratio = w3/w23;
    const float w45_ratio = w5/w45;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w45 * tex2D_linearize(tex, tex_uv - (4.0 + w45_ratio) * dxdy).rgb;
    sum += w23 * tex2D_linearize(tex, tex_uv - (2.0 + w23_ratio) * dxdy).rgb;
    sum += w01 * tex2D_linearize(tex, tex_uv - w01_ratio * dxdy).rgb;
    sum += w01 * tex2D_linearize(tex, tex_uv + w01_ratio * dxdy).rgb;
    sum += w23 * tex2D_linearize(tex, tex_uv + (2.0 + w23_ratio) * dxdy).rgb;
    sum += w45 * tex2D_linearize(tex, tex_uv + (4.0 + w45_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur9fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 9x Gaussian blurred texture lookup using 1 nearest
    //              neighbor and 4 linear taps.  It may be mipmapped depending
    //              on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
    //  Calculate combined weights and linear sample ratios between texel pairs.
    const float w12 = w1 + w2;
    const float w34 = w3 + w4;
    const float w12_ratio = w2/w12;
    const float w34_ratio = w4/w34;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w34 * tex2D_linearize(tex, tex_uv - (3.0 + w34_ratio) * dxdy).rgb;
    sum += w12 * tex2D_linearize(tex, tex_uv - (1.0 + w12_ratio) * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w12 * tex2D_linearize(tex, tex_uv + (1.0 + w12_ratio) * dxdy).rgb;
    sum += w34 * tex2D_linearize(tex, tex_uv + (3.0 + w34_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur7fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 7x Gaussian blurred texture lookup using 4 linear
    //              taps.  It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3));
    //  Calculate combined weights and linear sample ratios between texel pairs.
    //  The center texel (with weight w0) is used twice, so halve its weight.
    const float w01 = w0 * 0.5 + w1;
    const float w23 = w2 + w3;
    const float w01_ratio = w1/w01;
    const float w23_ratio = w3/w23;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w23 * tex2D_linearize(tex, tex_uv - (2.0 + w23_ratio) * dxdy).rgb;
    sum += w01 * tex2D_linearize(tex, tex_uv - w01_ratio * dxdy).rgb;
    sum += w01 * tex2D_linearize(tex, tex_uv + w01_ratio * dxdy).rgb;
    sum += w23 * tex2D_linearize(tex, tex_uv + (2.0 + w23_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur5fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 5x Gaussian blurred texture lookup using 1 nearest
    //              neighbor and 2 linear taps.  It may be mipmapped depending
    //              on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2));
    //  Calculate combined weights and linear sample ratios between texel pairs.
    const float w12 = w1 + w2;
    const float w12_ratio = w2/w12;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w12 * tex2D_linearize(tex, tex_uv - (1.0 + w12_ratio) * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w12 * tex2D_linearize(tex, tex_uv + (1.0 + w12_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur3fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 3x Gaussian blurred texture lookup using 2 linear
    //              taps.  It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * w1);
    //  Calculate combined weights and linear sample ratios between texel pairs.
    //  The center texel (with weight w0) is used twice, so halve its weight.
    const float w01 = w0 * 0.5 + w1;
    const float w01_ratio = w1/w01;
    //  Weights for all samples are the same, so just average them:
    return 0.5 * (
        tex2D_linearize(tex, tex_uv - w01_ratio * dxdy).rgb +
        tex2D_linearize(tex, tex_uv + w01_ratio * dxdy).rgb);
}


////////////////////////////  HUGE SEPARABLE BLURS  ////////////////////////////

//  Huge separable blurs come only in "fast" versions.
float3 tex2Dblur43fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 43x Gaussian blurred texture lookup using 22 linear
    //              taps.  It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float w13 = exp(-169.0 * denom_inv);
    const float w14 = exp(-196.0 * denom_inv);
    const float w15 = exp(-225.0 * denom_inv);
    const float w16 = exp(-256.0 * denom_inv);
    const float w17 = exp(-289.0 * denom_inv);
    const float w18 = exp(-324.0 * denom_inv);
    const float w19 = exp(-361.0 * denom_inv);
    const float w20 = exp(-400.0 * denom_inv);
    const float w21 = exp(-441.0 * denom_inv);
    //const float weight_sum_inv = 1.0 /
    //    (w0 + 2.0 * (w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8 + w9 + w10 + w11 +
    //        w12 + w13 + w14 + w15 + w16 + w17 + w18 + w19 + w20 + w21));
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    //  Calculate combined weights and linear sample ratios between texel pairs.
    //  The center texel (with weight w0) is used twice, so halve its weight.
    const float w0_1 = w0 * 0.5 + w1;
    const float w2_3 = w2 + w3;
    const float w4_5 = w4 + w5;
    const float w6_7 = w6 + w7;
    const float w8_9 = w8 + w9;
    const float w10_11 = w10 + w11;
    const float w12_13 = w12 + w13;
    const float w14_15 = w14 + w15;
    const float w16_17 = w16 + w17;
    const float w18_19 = w18 + w19;
    const float w20_21 = w20 + w21;
    const float w0_1_ratio = w1/w0_1;
    const float w2_3_ratio = w3/w2_3;
    const float w4_5_ratio = w5/w4_5;
    const float w6_7_ratio = w7/w6_7;
    const float w8_9_ratio = w9/w8_9;
    const float w10_11_ratio = w11/w10_11;
    const float w12_13_ratio = w13/w12_13;
    const float w14_15_ratio = w15/w14_15;
    const float w16_17_ratio = w17/w16_17;
    const float w18_19_ratio = w19/w18_19;
    const float w20_21_ratio = w21/w20_21;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w20_21 * tex2D_linearize(tex, tex_uv - (20.0 + w20_21_ratio) * dxdy).rgb;
    sum += w18_19 * tex2D_linearize(tex, tex_uv - (18.0 + w18_19_ratio) * dxdy).rgb;
    sum += w16_17 * tex2D_linearize(tex, tex_uv - (16.0 + w16_17_ratio) * dxdy).rgb;
    sum += w14_15 * tex2D_linearize(tex, tex_uv - (14.0 + w14_15_ratio) * dxdy).rgb;
    sum += w12_13 * tex2D_linearize(tex, tex_uv - (12.0 + w12_13_ratio) * dxdy).rgb;
    sum += w10_11 * tex2D_linearize(tex, tex_uv - (10.0 + w10_11_ratio) * dxdy).rgb;
    sum += w8_9 * tex2D_linearize(tex, tex_uv - (8.0 + w8_9_ratio) * dxdy).rgb;
    sum += w6_7 * tex2D_linearize(tex, tex_uv - (6.0 + w6_7_ratio) * dxdy).rgb;
    sum += w4_5 * tex2D_linearize(tex, tex_uv - (4.0 + w4_5_ratio) * dxdy).rgb;
    sum += w2_3 * tex2D_linearize(tex, tex_uv - (2.0 + w2_3_ratio) * dxdy).rgb;
    sum += w0_1 * tex2D_linearize(tex, tex_uv - w0_1_ratio * dxdy).rgb;
    sum += w0_1 * tex2D_linearize(tex, tex_uv + w0_1_ratio * dxdy).rgb;
    sum += w2_3 * tex2D_linearize(tex, tex_uv + (2.0 + w2_3_ratio) * dxdy).rgb;
    sum += w4_5 * tex2D_linearize(tex, tex_uv + (4.0 + w4_5_ratio) * dxdy).rgb;
    sum += w6_7 * tex2D_linearize(tex, tex_uv + (6.0 + w6_7_ratio) * dxdy).rgb;
    sum += w8_9 * tex2D_linearize(tex, tex_uv + (8.0 + w8_9_ratio) * dxdy).rgb;
    sum += w10_11 * tex2D_linearize(tex, tex_uv + (10.0 + w10_11_ratio) * dxdy).rgb;
    sum += w12_13 * tex2D_linearize(tex, tex_uv + (12.0 + w12_13_ratio) * dxdy).rgb;
    sum += w14_15 * tex2D_linearize(tex, tex_uv + (14.0 + w14_15_ratio) * dxdy).rgb;
    sum += w16_17 * tex2D_linearize(tex, tex_uv + (16.0 + w16_17_ratio) * dxdy).rgb;
    sum += w18_19 * tex2D_linearize(tex, tex_uv + (18.0 + w18_19_ratio) * dxdy).rgb;
    sum += w20_21 * tex2D_linearize(tex, tex_uv + (20.0 + w20_21_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur31fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 31x Gaussian blurred texture lookup using 16 linear
    //              taps.  It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float w13 = exp(-169.0 * denom_inv);
    const float w14 = exp(-196.0 * denom_inv);
    const float w15 = exp(-225.0 * denom_inv);
    //const float weight_sum_inv = 1.0 /
    //    (w0 + 2.0 * (w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8 +
    //        w9 + w10 + w11 + w12 + w13 + w14 + w15));
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    //  Calculate combined weights and linear sample ratios between texel pairs.
    //  The center texel (with weight w0) is used twice, so halve its weight.
    const float w0_1 = w0 * 0.5 + w1;
    const float w2_3 = w2 + w3;
    const float w4_5 = w4 + w5;
    const float w6_7 = w6 + w7;
    const float w8_9 = w8 + w9;
    const float w10_11 = w10 + w11;
    const float w12_13 = w12 + w13;
    const float w14_15 = w14 + w15;
    const float w0_1_ratio = w1/w0_1;
    const float w2_3_ratio = w3/w2_3;
    const float w4_5_ratio = w5/w4_5;
    const float w6_7_ratio = w7/w6_7;
    const float w8_9_ratio = w9/w8_9;
    const float w10_11_ratio = w11/w10_11;
    const float w12_13_ratio = w13/w12_13;
    const float w14_15_ratio = w15/w14_15;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w14_15 * tex2D_linearize(tex, tex_uv - (14.0 + w14_15_ratio) * dxdy).rgb;
    sum += w12_13 * tex2D_linearize(tex, tex_uv - (12.0 + w12_13_ratio) * dxdy).rgb;
    sum += w10_11 * tex2D_linearize(tex, tex_uv - (10.0 + w10_11_ratio) * dxdy).rgb;
    sum += w8_9 * tex2D_linearize(tex, tex_uv - (8.0 + w8_9_ratio) * dxdy).rgb;
    sum += w6_7 * tex2D_linearize(tex, tex_uv - (6.0 + w6_7_ratio) * dxdy).rgb;
    sum += w4_5 * tex2D_linearize(tex, tex_uv - (4.0 + w4_5_ratio) * dxdy).rgb;
    sum += w2_3 * tex2D_linearize(tex, tex_uv - (2.0 + w2_3_ratio) * dxdy).rgb;
    sum += w0_1 * tex2D_linearize(tex, tex_uv - w0_1_ratio * dxdy).rgb;
    sum += w0_1 * tex2D_linearize(tex, tex_uv + w0_1_ratio * dxdy).rgb;
    sum += w2_3 * tex2D_linearize(tex, tex_uv + (2.0 + w2_3_ratio) * dxdy).rgb;
    sum += w4_5 * tex2D_linearize(tex, tex_uv + (4.0 + w4_5_ratio) * dxdy).rgb;
    sum += w6_7 * tex2D_linearize(tex, tex_uv + (6.0 + w6_7_ratio) * dxdy).rgb;
    sum += w8_9 * tex2D_linearize(tex, tex_uv + (8.0 + w8_9_ratio) * dxdy).rgb;
    sum += w10_11 * tex2D_linearize(tex, tex_uv + (10.0 + w10_11_ratio) * dxdy).rgb;
    sum += w12_13 * tex2D_linearize(tex, tex_uv + (12.0 + w12_13_ratio) * dxdy).rgb;
    sum += w14_15 * tex2D_linearize(tex, tex_uv + (14.0 + w14_15_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur25fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 25x Gaussian blurred texture lookup using 1 nearest
    //              neighbor and 12 linear taps.  It may be mipmapped depending
    //              on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    //const float weight_sum_inv = 1.0 / (w0 + 2.0 * (
    //    w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8 + w9 + w10 + w11 + w12));
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    //  Calculate combined weights and linear sample ratios between texel pairs.
    const float w1_2 = w1 + w2;
    const float w3_4 = w3 + w4;
    const float w5_6 = w5 + w6;
    const float w7_8 = w7 + w8;
    const float w9_10 = w9 + w10;
    const float w11_12 = w11 + w12;
    const float w1_2_ratio = w2/w1_2;
    const float w3_4_ratio = w4/w3_4;
    const float w5_6_ratio = w6/w5_6;
    const float w7_8_ratio = w8/w7_8;
    const float w9_10_ratio = w10/w9_10;
    const float w11_12_ratio = w12/w11_12;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w11_12 * tex2D_linearize(tex, tex_uv - (11.0 + w11_12_ratio) * dxdy).rgb;
    sum += w9_10 * tex2D_linearize(tex, tex_uv - (9.0 + w9_10_ratio) * dxdy).rgb;
    sum += w7_8 * tex2D_linearize(tex, tex_uv - (7.0 + w7_8_ratio) * dxdy).rgb;
    sum += w5_6 * tex2D_linearize(tex, tex_uv - (5.0 + w5_6_ratio) * dxdy).rgb;
    sum += w3_4 * tex2D_linearize(tex, tex_uv - (3.0 + w3_4_ratio) * dxdy).rgb;
    sum += w1_2 * tex2D_linearize(tex, tex_uv - (1.0 + w1_2_ratio) * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w1_2 * tex2D_linearize(tex, tex_uv + (1.0 + w1_2_ratio) * dxdy).rgb;
    sum += w3_4 * tex2D_linearize(tex, tex_uv + (3.0 + w3_4_ratio) * dxdy).rgb;
    sum += w5_6 * tex2D_linearize(tex, tex_uv + (5.0 + w5_6_ratio) * dxdy).rgb;
    sum += w7_8 * tex2D_linearize(tex, tex_uv + (7.0 + w7_8_ratio) * dxdy).rgb;
    sum += w9_10 * tex2D_linearize(tex, tex_uv + (9.0 + w9_10_ratio) * dxdy).rgb;
    sum += w11_12 * tex2D_linearize(tex, tex_uv + (11.0 + w11_12_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}

float3 tex2Dblur17fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 17x Gaussian blurred texture lookup using 1 nearest
    //              neighbor and 8 linear taps.  It may be mipmapped depending
    //              on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    //const float weight_sum_inv = 1.0 / (w0 + 2.0 * (
    //    w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8));
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    //  Calculate combined weights and linear sample ratios between texel pairs.
    const float w1_2 = w1 + w2;
    const float w3_4 = w3 + w4;
    const float w5_6 = w5 + w6;
    const float w7_8 = w7 + w8;
    const float w1_2_ratio = w2/w1_2;
    const float w3_4_ratio = w4/w3_4;
    const float w5_6_ratio = w6/w5_6;
    const float w7_8_ratio = w8/w7_8;
    //  Statically normalize weights, sum weighted samples, and return:
    float3 sum = float3(0.0,0.0,0.0);
    sum += w7_8 * tex2D_linearize(tex, tex_uv - (7.0 + w7_8_ratio) * dxdy).rgb;
    sum += w5_6 * tex2D_linearize(tex, tex_uv - (5.0 + w5_6_ratio) * dxdy).rgb;
    sum += w3_4 * tex2D_linearize(tex, tex_uv - (3.0 + w3_4_ratio) * dxdy).rgb;
    sum += w1_2 * tex2D_linearize(tex, tex_uv - (1.0 + w1_2_ratio) * dxdy).rgb;
    sum += w0 * tex2D_linearize(tex, tex_uv).rgb;
    sum += w1_2 * tex2D_linearize(tex, tex_uv + (1.0 + w1_2_ratio) * dxdy).rgb;
    sum += w3_4 * tex2D_linearize(tex, tex_uv + (3.0 + w3_4_ratio) * dxdy).rgb;
    sum += w5_6 * tex2D_linearize(tex, tex_uv + (5.0 + w5_6_ratio) * dxdy).rgb;
    sum += w7_8 * tex2D_linearize(tex, tex_uv + (7.0 + w7_8_ratio) * dxdy).rgb;
    return sum * weight_sum_inv;
}


////////////////////  ARBITRARILY RESIZABLE ONE-PASS BLURS  ////////////////////

float3 tex2Dblur3x3resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Requires:   Global requirements must be met (see file description).
    //  Returns:    A 3x3 Gaussian blurred mipmapped texture lookup of the
    //              resized input.
    //  Description:
    //  This is the only arbitrarily resizable one-pass blur; tex2Dblur5x5resize
    //  would perform like tex2Dblur9x9, MUCH slower than tex2Dblur5resize.
    const float denom_inv = 0.5/(sigma*sigma);
    //  Load each sample.  We need all 3x3 samples.  Quad-pixel communication
    //  won't help either: This should perform like tex2Dblur5x5, but sharing a
    //  4x4 sample field would perform more like tex2Dblur8x8shared (worse).
    const float2 sample4_uv = tex_uv;
    const float2 dx = float2(dxdy.x, 0.0);
    const float2 dy = float2(0.0, dxdy.y);
    const float2 sample1_uv = sample4_uv - dy;
    const float2 sample7_uv = sample4_uv + dy;
    const float3 sample0 = tex2D_linearize(tex, sample1_uv - dx).rgb;
    const float3 sample1 = tex2D_linearize(tex, sample1_uv).rgb;
    const float3 sample2 = tex2D_linearize(tex, sample1_uv + dx).rgb;
    const float3 sample3 = tex2D_linearize(tex, sample4_uv - dx).rgb;
    const float3 sample4 = tex2D_linearize(tex, sample4_uv).rgb;
    const float3 sample5 = tex2D_linearize(tex, sample4_uv + dx).rgb;
    const float3 sample6 = tex2D_linearize(tex, sample7_uv - dx).rgb;
    const float3 sample7 = tex2D_linearize(tex, sample7_uv).rgb;
    const float3 sample8 = tex2D_linearize(tex, sample7_uv + dx).rgb;
    //  Statically compute Gaussian sample weights:
    const float w4 = 1.0;
    const float w1_3_5_7 = exp(-LENGTH_SQ(float2(1.0, 0.0)) * denom_inv);
    const float w0_2_6_8 = exp(-LENGTH_SQ(float2(1.0, 1.0)) * denom_inv);
    const float weight_sum_inv = 1.0/(w4 + 4.0 * (w1_3_5_7 + w0_2_6_8));
    //  Weight and sum the samples:
    const float3 sum = w4 * sample4 +
        w1_3_5_7 * (sample1 + sample3 + sample5 + sample7) +
        w0_2_6_8 * (sample0 + sample2 + sample6 + sample8);
    return sum * weight_sum_inv;
}


////////////////////////////  FASTER ONE-PASS BLURS  ///////////////////////////

float3 tex2Dblur9x9(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Perform a 1-pass 9x9 blur with 5x5 bilinear samples.
    //  Requires:   Same as tex2Dblur9()
    //  Returns:    A 9x9 Gaussian blurred mipmapped texture lookup composed of
    //              5x5 carefully selected bilinear samples.
    //  Description:
    //  Perform a 1-pass 9x9 blur with 5x5 bilinear samples.  Adjust the
    //  bilinear sample location to reflect the true Gaussian weights for each
    //  underlying texel.  The following diagram illustrates the relative
    //  locations of bilinear samples.  Each sample with the same number has the
    //  same weight (notice the symmetry).  The letters a, b, c, d distinguish
    //  quadrants, and the letters U, D, L, R, C (up, down, left, right, center)
    //  distinguish 1D directions along the line containing the pixel center:
    //      6a 5a 2U 5b 6b
    //      4a 3a 1U 3b 4b
    //      2L 1L 0C 1R 2R
    //      4c 3c 1D 3d 4d
    //      6c 5c 2D 5d 6d
    //  The following diagram illustrates the underlying equally spaced texels,
    //  named after the sample that accesses them and subnamed by their location
    //  within their 2x2, 2x1, 1x2, or 1x1 texel block:
    //      6a4 6a3 5a4 5a3 2U2 5b3 5b4 6b3 6b4
    //      6a2 6a1 5a2 5a1 2U1 5b1 5b2 6b1 6b2
    //      4a4 4a3 3a4 3a3 1U2 3b3 3b4 4b3 4b4
    //      4a2 4a1 3a2 3a1 1U1 3b1 3b2 4b1 4b2
    //      2L2 2L1 1L2 1L1 0C1 1R1 1R2 2R1 2R2
    //      4c2 4c1 3c2 3c1 1D1 3d1 3d2 4d1 4d2
    //      4c4 4c3 3c4 3c3 1D2 3d3 3d4 4d3 4d4
    //      6c2 6c1 5c2 5c1 2D1 5d1 5d2 6d1 6d2
    //      6c4 6c3 5c4 5c3 2D2 5d3 5d4 6d3 6d4
    //  Note there is only one C texel and only two texels for each U, D, L, or
    //  R sample.  The center sample is effectively a nearest neighbor sample,
    //  and the U/D/L/R samples use 1D linear filtering.  All other texels are
    //  read with bilinear samples somewhere within their 2x2 texel blocks.

    //  COMPUTE TEXTURE COORDS:
    //  Statically compute sampling offsets within each 2x2 texel block, based
    //  on 1D sampling ratios between texels [1, 2] and [3, 4] texels away from
    //  the center, and reuse them independently for both dimensions.  Compute
    //  these offsets based on the relative 1D Gaussian weights of the texels
    //  in question.  (w1off means "Gaussian weight for the texel 1.0 texels
    //  away from the pixel center," etc.).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w1off = exp(-1.0 * denom_inv);
    const float w2off = exp(-4.0 * denom_inv);
    const float w3off = exp(-9.0 * denom_inv);
    const float w4off = exp(-16.0 * denom_inv);
    const float texel1to2ratio = w2off/(w1off + w2off);
    const float texel3to4ratio = w4off/(w3off + w4off);
    //  Statically compute texel offsets from the fragment center to each
    //  bilinear sample in the bottom-right quadrant, including x-axis-aligned:
    const float2 sample1R_texel_offset = float2(1.0, 0.0) + float2(texel1to2ratio, 0.0);
    const float2 sample2R_texel_offset = float2(3.0, 0.0) + float2(texel3to4ratio, 0.0);
    const float2 sample3d_texel_offset = float2(1.0, 1.0) + float2(texel1to2ratio, texel1to2ratio);
    const float2 sample4d_texel_offset = float2(3.0, 1.0) + float2(texel3to4ratio, texel1to2ratio);
    const float2 sample5d_texel_offset = float2(1.0, 3.0) + float2(texel1to2ratio, texel3to4ratio);
    const float2 sample6d_texel_offset = float2(3.0, 3.0) + float2(texel3to4ratio, texel3to4ratio);

    //  CALCULATE KERNEL WEIGHTS FOR ALL SAMPLES:
    //  Statically compute Gaussian texel weights for the bottom-right quadrant.
    //  Read underscores as "and."
    const float w1R1 = w1off;
    const float w1R2 = w2off;
    const float w2R1 = w3off;
    const float w2R2 = w4off;
    const float w3d1 =     exp(-LENGTH_SQ(float2(1.0, 1.0)) * denom_inv);
    const float w3d2_3d3 = exp(-LENGTH_SQ(float2(2.0, 1.0)) * denom_inv);
    const float w3d4 =     exp(-LENGTH_SQ(float2(2.0, 2.0)) * denom_inv);
    const float w4d1_5d1 = exp(-LENGTH_SQ(float2(3.0, 1.0)) * denom_inv);
    const float w4d2_5d3 = exp(-LENGTH_SQ(float2(4.0, 1.0)) * denom_inv);
    const float w4d3_5d2 = exp(-LENGTH_SQ(float2(3.0, 2.0)) * denom_inv);
    const float w4d4_5d4 = exp(-LENGTH_SQ(float2(4.0, 2.0)) * denom_inv);
    const float w6d1 =     exp(-LENGTH_SQ(float2(3.0, 3.0)) * denom_inv);
    const float w6d2_6d3 = exp(-LENGTH_SQ(float2(4.0, 3.0)) * denom_inv);
    const float w6d4 =     exp(-LENGTH_SQ(float2(4.0, 4.0)) * denom_inv);
    //  Statically add texel weights in each sample to get sample weights:
    const float w0 = 1.0;
    const float w1 = w1R1 + w1R2;
    const float w2 = w2R1 + w2R2;
    const float w3 = w3d1 + 2.0 * w3d2_3d3 + w3d4;
    const float w4 = w4d1_5d1 + w4d2_5d3 + w4d3_5d2 + w4d4_5d4;
    const float w5 = w4;
    const float w6 = w6d1 + 2.0 * w6d2_6d3 + w6d4;
    //  Get the weight sum inverse (normalization factor):
    const float weight_sum_inv =
        1.0/(w0 + 4.0 * (w1 + w2 + w3 + w4 + w5 + w6));

    //  LOAD TEXTURE SAMPLES:
    //  Load all 25 samples (1 nearest, 8 linear, 16 bilinear) using symmetry:
    const float2 mirror_x = float2(-1.0, 1.0);
    const float2 mirror_y = float2(1.0, -1.0);
    const float2 mirror_xy = float2(-1.0, -1.0);
    const float2 dxdy_mirror_x = dxdy * mirror_x;
    const float2 dxdy_mirror_y = dxdy * mirror_y;
    const float2 dxdy_mirror_xy = dxdy * mirror_xy;
    //  Sampling order doesn't seem to affect performance, so just be clear:
    const float3 sample0C = tex2D_linearize(tex, tex_uv).rgb;
    const float3 sample1R = tex2D_linearize(tex, tex_uv + dxdy * sample1R_texel_offset).rgb;
    const float3 sample1D = tex2D_linearize(tex, tex_uv + dxdy * sample1R_texel_offset.yx).rgb;
    const float3 sample1L = tex2D_linearize(tex, tex_uv - dxdy * sample1R_texel_offset).rgb;
    const float3 sample1U = tex2D_linearize(tex, tex_uv - dxdy * sample1R_texel_offset.yx).rgb;
    const float3 sample2R = tex2D_linearize(tex, tex_uv + dxdy * sample2R_texel_offset).rgb;
    const float3 sample2D = tex2D_linearize(tex, tex_uv + dxdy * sample2R_texel_offset.yx).rgb;
    const float3 sample2L = tex2D_linearize(tex, tex_uv - dxdy * sample2R_texel_offset).rgb;
    const float3 sample2U = tex2D_linearize(tex, tex_uv - dxdy * sample2R_texel_offset.yx).rgb;
    const float3 sample3d = tex2D_linearize(tex, tex_uv + dxdy * sample3d_texel_offset).rgb;
    const float3 sample3c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample3d_texel_offset).rgb;
    const float3 sample3b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample3d_texel_offset).rgb;
    const float3 sample3a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample3d_texel_offset).rgb;
    const float3 sample4d = tex2D_linearize(tex, tex_uv + dxdy * sample4d_texel_offset).rgb;
    const float3 sample4c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample4d_texel_offset).rgb;
    const float3 sample4b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample4d_texel_offset).rgb;
    const float3 sample4a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample4d_texel_offset).rgb;
    const float3 sample5d = tex2D_linearize(tex, tex_uv + dxdy * sample5d_texel_offset).rgb;
    const float3 sample5c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample5d_texel_offset).rgb;
    const float3 sample5b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample5d_texel_offset).rgb;
    const float3 sample5a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample5d_texel_offset).rgb;
    const float3 sample6d = tex2D_linearize(tex, tex_uv + dxdy * sample6d_texel_offset).rgb;
    const float3 sample6c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample6d_texel_offset).rgb;
    const float3 sample6b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample6d_texel_offset).rgb;
    const float3 sample6a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample6d_texel_offset).rgb;

    //  SUM WEIGHTED SAMPLES:
    //  Statically normalize weights (so total = 1.0), and sum weighted samples.
    float3 sum = w0 * sample0C;
    sum += w1 * (sample1R + sample1D + sample1L + sample1U);
    sum += w2 * (sample2R + sample2D + sample2L + sample2U);
    sum += w3 * (sample3d + sample3c + sample3b + sample3a);
    sum += w4 * (sample4d + sample4c + sample4b + sample4a);
    sum += w5 * (sample5d + sample5c + sample5b + sample5a);
    sum += w6 * (sample6d + sample6c + sample6b + sample6a);
    return sum * weight_sum_inv;
}

float3 tex2Dblur7x7(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Perform a 1-pass 7x7 blur with 5x5 bilinear samples.
    //  Requires:   Same as tex2Dblur9()
    //  Returns:    A 7x7 Gaussian blurred mipmapped texture lookup composed of
    //              4x4 carefully selected bilinear samples.
    //  Description:
    //  First see the descriptions for tex2Dblur9x9() and tex2Dblur7().  This
    //  blur mixes concepts from both.  The sample layout is as follows:
    //      4a 3a 3b 4b
    //      2a 1a 1b 2b
    //      2c 1c 1d 2d
    //      4c 3c 3d 4d
    //  The texel layout is as follows.  Note that samples 3a/3b, 1a/1b, 1c/1d,
    //  and 3c/3d share a vertical column of texels, and samples 2a/2c, 1a/1c,
    //  1b/1d, and 2b/2d share a horizontal row of texels (all sample1's share
    //  the center texel):
    //      4a4  4a3  3a4  3ab3 3b4  4b3  4b4
    //      4a2  4a1  3a2  3ab1 3b2  4b1  4b2
    //      2a4  2a3  1a4  1ab3 1b4  2b3  2b4
    //      2ac2 2ac1 1ac2 1*   1bd2 2bd1 2bd2
    //      2c4  2c3  1c4  1cd3 1d4  2d3  2d4
    //      4c2  4c1  3c2  3cd1 3d2  4d1  4d2
    //      4c4  4c3  3c4  3cd3 3d4  4d3  4d4

    //  COMPUTE TEXTURE COORDS:
    //  Statically compute bilinear sampling offsets (details in tex2Dblur9x9).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0off = 1.0;
    const float w1off = exp(-1.0 * denom_inv);
    const float w2off = exp(-4.0 * denom_inv);
    const float w3off = exp(-9.0 * denom_inv);
    const float texel0to1ratio = w1off/(w0off * 0.5 + w1off);
    const float texel2to3ratio = w3off/(w2off + w3off);
    //  Statically compute texel offsets from the fragment center to each
    //  bilinear sample in the bottom-right quadrant, including axis-aligned:
    const float2 sample1d_texel_offset = float2(texel0to1ratio, texel0to1ratio);
    const float2 sample2d_texel_offset = float2(2.0, 0.0) + float2(texel2to3ratio, texel0to1ratio);
    const float2 sample3d_texel_offset = float2(0.0, 2.0) + float2(texel0to1ratio, texel2to3ratio);
    const float2 sample4d_texel_offset = float2(2.0, 2.0) + float2(texel2to3ratio, texel2to3ratio);

    //  CALCULATE KERNEL WEIGHTS FOR ALL SAMPLES:
    //  Statically compute Gaussian texel weights for the bottom-right quadrant.
    //  Read underscores as "and."
    const float w1abcd = 1.0;
    const float w1bd2_1cd3 = exp(-LENGTH_SQ(float2(1.0, 0.0)) * denom_inv);
    const float w2bd1_3cd1 = exp(-LENGTH_SQ(float2(2.0, 0.0)) * denom_inv);
    const float w2bd2_3cd2 = exp(-LENGTH_SQ(float2(3.0, 0.0)) * denom_inv);
    const float w1d4 =       exp(-LENGTH_SQ(float2(1.0, 1.0)) * denom_inv);
    const float w2d3_3d2 =   exp(-LENGTH_SQ(float2(2.0, 1.0)) * denom_inv);
    const float w2d4_3d4 =   exp(-LENGTH_SQ(float2(3.0, 1.0)) * denom_inv);
    const float w4d1 =       exp(-LENGTH_SQ(float2(2.0, 2.0)) * denom_inv);
    const float w4d2_4d3 =   exp(-LENGTH_SQ(float2(3.0, 2.0)) * denom_inv);
    const float w4d4 =       exp(-LENGTH_SQ(float2(3.0, 3.0)) * denom_inv);
    //  Statically add texel weights in each sample to get sample weights.
    //  Split weights for shared texels between samples sharing them:
    const float w1 = w1abcd * 0.25 + w1bd2_1cd3 + w1d4;
    const float w2_3 = (w2bd1_3cd1 + w2bd2_3cd2) * 0.5 + w2d3_3d2 + w2d4_3d4;
    const float w4 = w4d1 + 2.0 * w4d2_4d3 + w4d4;
    //  Get the weight sum inverse (normalization factor):
    const float weight_sum_inv =
        1.0/(4.0 * (w1 + 2.0 * w2_3 + w4));

    //  LOAD TEXTURE SAMPLES:
    //  Load all 16 samples using symmetry:
    const float2 mirror_x = float2(-1.0, 1.0);
    const float2 mirror_y = float2(1.0, -1.0);
    const float2 mirror_xy = float2(-1.0, -1.0);
    const float2 dxdy_mirror_x = dxdy * mirror_x;
    const float2 dxdy_mirror_y = dxdy * mirror_y;
    const float2 dxdy_mirror_xy = dxdy * mirror_xy;
    const float3 sample1a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample1d_texel_offset).rgb;
    const float3 sample2a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample2d_texel_offset).rgb;
    const float3 sample3a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample3d_texel_offset).rgb;
    const float3 sample4a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample4d_texel_offset).rgb;
    const float3 sample1b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample1d_texel_offset).rgb;
    const float3 sample2b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample2d_texel_offset).rgb;
    const float3 sample3b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample3d_texel_offset).rgb;
    const float3 sample4b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample4d_texel_offset).rgb;
    const float3 sample1c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample1d_texel_offset).rgb;
    const float3 sample2c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample2d_texel_offset).rgb;
    const float3 sample3c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample3d_texel_offset).rgb;
    const float3 sample4c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample4d_texel_offset).rgb;
    const float3 sample1d = tex2D_linearize(tex, tex_uv + dxdy * sample1d_texel_offset).rgb;
    const float3 sample2d = tex2D_linearize(tex, tex_uv + dxdy * sample2d_texel_offset).rgb;
    const float3 sample3d = tex2D_linearize(tex, tex_uv + dxdy * sample3d_texel_offset).rgb;
    const float3 sample4d = tex2D_linearize(tex, tex_uv + dxdy * sample4d_texel_offset).rgb;

    //  SUM WEIGHTED SAMPLES:
    //  Statically normalize weights (so total = 1.0), and sum weighted samples.
    float3 sum = float3(0.0,0.0,0.0);
    sum += w1 * (sample1a + sample1b + sample1c + sample1d);
    sum += w2_3 * (sample2a + sample2b + sample2c + sample2d);
    sum += w2_3 * (sample3a + sample3b + sample3c + sample3d);
    sum += w4 * (sample4a + sample4b + sample4c + sample4d);
    return sum * weight_sum_inv;
}

float3 tex2Dblur5x5(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Perform a 1-pass 5x5 blur with 3x3 bilinear samples.
    //  Requires:   Same as tex2Dblur9()
    //  Returns:    A 5x5 Gaussian blurred mipmapped texture lookup composed of
    //              3x3 carefully selected bilinear samples.
    //  Description:
    //  First see the description for tex2Dblur9x9().  This blur uses the same
    //  concept and sample/texel locations except on a smaller scale.  Samples:
    //      2a 1U 2b
    //      1L 0C 1R
    //      2c 1D 2d
    //  Texels:
    //      2a4 2a3 1U2 2b3 2b4
    //      2a2 2a1 1U1 2b1 2b2
    //      1L2 1L1 0C1 1R1 1R2
    //      2c2 2c1 1D1 2d1 2d2
    //      2c4 2c3 1D2 2d3 2d4

    //  COMPUTE TEXTURE COORDS:
    //  Statically compute bilinear sampling offsets (details in tex2Dblur9x9).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w1off = exp(-1.0 * denom_inv);
    const float w2off = exp(-4.0 * denom_inv);
    const float texel1to2ratio = w2off/(w1off + w2off);
    //  Statically compute texel offsets from the fragment center to each
    //  bilinear sample in the bottom-right quadrant, including x-axis-aligned:
    const float2 sample1R_texel_offset = float2(1.0, 0.0) + float2(texel1to2ratio, 0.0);
    const float2 sample2d_texel_offset = float2(1.0, 1.0) + float2(texel1to2ratio, texel1to2ratio);

    //  CALCULATE KERNEL WEIGHTS FOR ALL SAMPLES:
    //  Statically compute Gaussian texel weights for the bottom-right quadrant.
    //  Read underscores as "and."
    const float w1R1 = w1off;
    const float w1R2 = w2off;
    const float w2d1 =   exp(-LENGTH_SQ(float2(1.0, 1.0)) * denom_inv);
    const float w2d2_3 = exp(-LENGTH_SQ(float2(2.0, 1.0)) * denom_inv);
    const float w2d4 =   exp(-LENGTH_SQ(float2(2.0, 2.0)) * denom_inv);
    //  Statically add texel weights in each sample to get sample weights:
    const float w0 = 1.0;
    const float w1 = w1R1 + w1R2;
    const float w2 = w2d1 + 2.0 * w2d2_3 + w2d4;
    //  Get the weight sum inverse (normalization factor):
    const float weight_sum_inv = 1.0/(w0 + 4.0 * (w1 + w2));

    //  LOAD TEXTURE SAMPLES:
    //  Load all 9 samples (1 nearest, 4 linear, 4 bilinear) using symmetry:
    const float2 mirror_x = float2(-1.0, 1.0);
    const float2 mirror_y = float2(1.0, -1.0);
    const float2 mirror_xy = float2(-1.0, -1.0);
    const float2 dxdy_mirror_x = dxdy * mirror_x;
    const float2 dxdy_mirror_y = dxdy * mirror_y;
    const float2 dxdy_mirror_xy = dxdy * mirror_xy;
    const float3 sample0C = tex2D_linearize(tex, tex_uv).rgb;
    const float3 sample1R = tex2D_linearize(tex, tex_uv + dxdy * sample1R_texel_offset).rgb;
    const float3 sample1D = tex2D_linearize(tex, tex_uv + dxdy * sample1R_texel_offset.yx).rgb;
    const float3 sample1L = tex2D_linearize(tex, tex_uv - dxdy * sample1R_texel_offset).rgb;
    const float3 sample1U = tex2D_linearize(tex, tex_uv - dxdy * sample1R_texel_offset.yx).rgb;
    const float3 sample2d = tex2D_linearize(tex, tex_uv + dxdy * sample2d_texel_offset).rgb;
    const float3 sample2c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample2d_texel_offset).rgb;
    const float3 sample2b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample2d_texel_offset).rgb;
    const float3 sample2a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample2d_texel_offset).rgb;

    //  SUM WEIGHTED SAMPLES:
    //  Statically normalize weights (so total = 1.0), and sum weighted samples.
    float3 sum = w0 * sample0C;
    sum += w1 * (sample1R + sample1D + sample1L + sample1U);
    sum += w2 * (sample2a + sample2b + sample2c + sample2d);
    return sum * weight_sum_inv;
}

float3 tex2Dblur3x3(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  Perform a 1-pass 3x3 blur with 5x5 bilinear samples.
    //  Requires:   Same as tex2Dblur9()
    //  Returns:    A 3x3 Gaussian blurred mipmapped texture lookup composed of
    //              2x2 carefully selected bilinear samples.
    //  Description:
    //  First see the descriptions for tex2Dblur9x9() and tex2Dblur7().  This
    //  blur mixes concepts from both.  The sample layout is as follows:
    //      0a 0b
    //      0c 0d
    //  The texel layout is as follows.  Note that samples 0a/0b and 0c/0d share
    //  a vertical column of texels, and samples 0a/0c and 0b/0d share a
    //  horizontal row of texels (all samples share the center texel):
    //      0a3  0ab2 0b3
    //      0ac1 0*0  0bd1
    //      0c3  0cd2 0d3

    //  COMPUTE TEXTURE COORDS:
    //  Statically compute bilinear sampling offsets (details in tex2Dblur9x9).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0off = 1.0;
    const float w1off = exp(-1.0 * denom_inv);
    const float texel0to1ratio = w1off/(w0off * 0.5 + w1off);
    //  Statically compute texel offsets from the fragment center to each
    //  bilinear sample in the bottom-right quadrant, including axis-aligned:
    const float2 sample0d_texel_offset = float2(texel0to1ratio, texel0to1ratio);

    //  LOAD TEXTURE SAMPLES:
    //  Load all 4 samples using symmetry:
    const float2 mirror_x = float2(-1.0, 1.0);
    const float2 mirror_y = float2(1.0, -1.0);
    const float2 mirror_xy = float2(-1.0, -1.0);
    const float2 dxdy_mirror_x = dxdy * mirror_x;
    const float2 dxdy_mirror_y = dxdy * mirror_y;
    const float2 dxdy_mirror_xy = dxdy * mirror_xy;
    const float3 sample0a = tex2D_linearize(tex, tex_uv + dxdy_mirror_xy * sample0d_texel_offset).rgb;
    const float3 sample0b = tex2D_linearize(tex, tex_uv + dxdy_mirror_y * sample0d_texel_offset).rgb;
    const float3 sample0c = tex2D_linearize(tex, tex_uv + dxdy_mirror_x * sample0d_texel_offset).rgb;
    const float3 sample0d = tex2D_linearize(tex, tex_uv + dxdy * sample0d_texel_offset).rgb;

    //  SUM WEIGHTED SAMPLES:
    //  Weights for all samples are the same, so just average them:
    return 0.25 * (sample0a + sample0b + sample0c + sample0d);
}


//////////////////  LINEAR ONE-PASS BLURS WITH SHARED SAMPLES  /////////////////

float3 tex2Dblur12x12shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector,
    const float sigma)
{
    //  Perform a 1-pass mipmapped blur with shared samples across a pixel quad.
    //  Requires:   1.) Same as tex2Dblur9()
    //              2.) ddx() and ddy() are present in the current Cg profile.
    //              3.) The GPU driver is using fine/high-quality derivatives.
    //              4.) quad_vector *correctly* describes the current fragment's
    //                  location in its pixel quad, by the conventions noted in
    //                  get_quad_vector[_naive].
    //              5.) tex_uv.w = log2(IN.video_size/IN.output_size).y
    //              6.) tex2Dlod() is present in the current Cg profile.
    //  Optional:   Tune artifacts vs. excessive blurriness with the global
    //              float error_blurring.
    //  Returns:    A blurred texture lookup using a "virtual" 12x12 Gaussian
    //              blur (a 6x6 blur of carefully selected bilinear samples)
    //              of the given mip level.  There will be subtle inaccuracies,
    //              especially for small or high-frequency detailed sources.
    //  Description:
    //  Perform a 1-pass blur with shared texture lookups across a pixel quad.
    //  We'll get neighboring samples with high-quality ddx/ddy derivatives, as
    //  in GPU Pro 2, Chapter VI.2, "Shader Amortization using Pixel Quad
    //  Message Passing" by Eric Penner.
    //
    //  Our "virtual" 12x12 blur will be comprised of ((6 - 1)^2)/4 + 3 = 12
    //  bilinear samples, where bilinear sampling positions are computed from
    //  the relative Gaussian weights of the 4 surrounding texels.  The catch is
    //  that the appropriate texel weights and sample coords differ for each
    //  fragment, but we're reusing most of the same samples across a quad of
    //  destination fragments.  (We do use unique coords for the four nearest
    //  samples at each fragment.)  Mixing bilinear filtering and sample-sharing
    //  therefore introduces some error into the weights, and this can get nasty
    //  when the source image is small or high-frequency.  Computing bilinear
    //  ratios based on weights at the sample field center results in sharpening
    //  and ringing artifacts, but we can move samples closer to halfway between
    //  texels to try blurring away the error (which can move features around by
    //  a texel or so).  Tune this with the global float "error_blurring".
    //
    //  The pixel quad's sample field covers 12x12 texels, accessed through 6x6
    //  bilinear (2x2 texel) taps.  Each fragment depends on a window of 10x10
    //  texels (5x5 bilinear taps), and each fragment is responsible for loading
    //  a 6x6 texel quadrant as a 3x3 block of bilinear taps, plus 3 more taps
    //  to use unique bilinear coords for sample0* for each fragment.  This
    //  diagram illustrates the relative locations of bilinear samples 1-9 for
    //  each quadrant a, b, c, d (note samples will not be equally spaced):
    //      8a 7a 6a 6b 7b 8b
    //      5a 4a 3a 3b 4b 5b
    //      2a 1a 0a 0b 1b 2b
    //      2c 1c 0c 0d 1d 2d
    //      5c 4c 3c 3d 4d 5d
    //      8c 7c 6c 6d 7d 8d
    //  The following diagram illustrates the underlying equally spaced texels,
    //  named after the sample that accesses them and subnamed by their location
    //  within their 2x2 texel block:
    //      8a3 8a2 7a3 7a2 6a3 6a2 6b2 6b3 7b2 7b3 8b2 8b3
    //      8a1 8a0 7a1 7a0 6a1 6a0 6b0 6b1 7b0 7b1 8b0 8b1
    //      5a3 5a2 4a3 4a2 3a3 3a2 3b2 3b3 4b2 4b3 5b2 5b3
    //      5a1 5a0 4a1 4a0 3a1 3a0 3b0 3b1 4b0 4b1 5b0 5b1
    //      2a3 2a2 1a3 1a2 0a3 0a2 0b2 0b3 1b2 1b3 2b2 2b3
    //      2a1 2a0 1a1 1a0 0a1 0a0 0b0 0b1 1b0 1b1 2b0 2b1
    //      2c1 2c0 1c1 1c0 0c1 0c0 0d0 0d1 1d0 1d1 2d0 2d1
    //      2c3 2c2 1c3 1c2 0c3 0c2 0d2 0d3 1d2 1d3 2d2 2d3
    //      5c1 5c0 4c1 4c0 3c1 3c0 3d0 3d1 4d0 4d1 5d0 5d1
    //      5c3 5c2 4c3 4c2 3c3 3c2 3d2 3d3 4d2 4d3 5d2 5d3
    //      8c1 8c0 7c1 7c0 6c1 6c0 6d0 6d1 7d0 7d1 8d0 8d1
    //      8c3 8c2 7c3 7c2 6c3 6c2 6d2 6d3 7d2 7d3 8d2 8d3
    //  With this symmetric arrangement, we don't have to know which absolute
    //  quadrant a sample lies in to assign kernel weights; it's enough to know
    //  the sample number and the relative quadrant of the sample (relative to
    //  the current quadrant):
    //      {current, adjacent x, adjacent y, diagonal}

    //  COMPUTE COORDS FOR TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Statically compute sampling offsets within each 2x2 texel block, based
    //  on appropriate 1D Gaussian sampling ratio between texels [0, 1], [2, 3],
    //  and [4, 5] away from the fragment, and reuse them independently for both
    //  dimensions.  Use the sample field center as the estimated destination,
    //  but nudge the result closer to halfway between texels to blur error.
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0off   = 1.0;
    const float w0_5off = exp(-(0.5*0.5) * denom_inv);
    const float w1off   = exp(-(1.0*1.0) * denom_inv);
    const float w1_5off = exp(-(1.5*1.5) * denom_inv);
    const float w2off   = exp(-(2.0*2.0) * denom_inv);
    const float w2_5off = exp(-(2.5*2.5) * denom_inv);
    const float w3_5off = exp(-(3.5*3.5) * denom_inv);
    const float w4_5off = exp(-(4.5*4.5) * denom_inv);
    const float w5_5off = exp(-(5.5*5.5) * denom_inv);
    const float texel0to1ratio = lerp(w1_5off/(w0_5off + w1_5off), 0.5, error_blurring);
    const float texel2to3ratio = lerp(w3_5off/(w2_5off + w3_5off), 0.5, error_blurring);
    const float texel4to5ratio = lerp(w5_5off/(w4_5off + w5_5off), 0.5, error_blurring);
    //  We don't share sample0*, so use the nearest destination fragment:
    const float texel0to1ratio_nearest = w1off/(w0off + w1off);
    const float texel1to2ratio_nearest = w2off/(w1off + w2off);
    //  Statically compute texel offsets from the bottom-right fragment to each
    //  bilinear sample in the bottom-right quadrant:
    const float2 sample0curr_texel_offset = float2(0.0, 0.0) + float2(texel0to1ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjx_texel_offset = float2(-1.0, 0.0) + float2(-texel1to2ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjy_texel_offset = float2(0.0, -1.0) + float2(texel0to1ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample0diag_texel_offset = float2(-1.0, -1.0) + float2(-texel1to2ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample1_texel_offset = float2(2.0, 0.0) + float2(texel2to3ratio, texel0to1ratio);
    const float2 sample2_texel_offset = float2(4.0, 0.0) + float2(texel4to5ratio, texel0to1ratio);
    const float2 sample3_texel_offset = float2(0.0, 2.0) + float2(texel0to1ratio, texel2to3ratio);
    const float2 sample4_texel_offset = float2(2.0, 2.0) + float2(texel2to3ratio, texel2to3ratio);
    const float2 sample5_texel_offset = float2(4.0, 2.0) + float2(texel4to5ratio, texel2to3ratio);
    const float2 sample6_texel_offset = float2(0.0, 4.0) + float2(texel0to1ratio, texel4to5ratio);
    const float2 sample7_texel_offset = float2(2.0, 4.0) + float2(texel2to3ratio, texel4to5ratio);
    const float2 sample8_texel_offset = float2(4.0, 4.0) + float2(texel4to5ratio, texel4to5ratio);

    //  CALCULATE KERNEL WEIGHTS:
    //  Statically compute bilinear sample weights at each destination fragment
    //  based on the sum of their 4 underlying texel weights.  Assume a same-
    //  resolution blur, so each symmetrically named sample weight will compute
    //  the same at every fragment in the pixel quad: We can therefore compute
    //  texel weights based only on the bottom-right quadrant (fragment at 0d0).
    //  Too avoid too much boilerplate code, use a macro to get all 4 texel
    //  weights for a bilinear sample based on the offset of its top-left texel:
    #define GET_TEXEL_QUAD_WEIGHTS(xoff, yoff) \
        (exp(-LENGTH_SQ(float2(xoff, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff, yoff + 1.0)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff + 1.0)) * denom_inv))
    const float w8diag = GET_TEXEL_QUAD_WEIGHTS(-6.0, -6.0);
    const float w7diag = GET_TEXEL_QUAD_WEIGHTS(-4.0, -6.0);
    const float w6diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -6.0);
    const float w6adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -6.0);
    const float w7adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -6.0);
    const float w8adjy = GET_TEXEL_QUAD_WEIGHTS(4.0, -6.0);
    const float w5diag = GET_TEXEL_QUAD_WEIGHTS(-6.0, -4.0);
    const float w4diag = GET_TEXEL_QUAD_WEIGHTS(-4.0, -4.0);
    const float w3diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -4.0);
    const float w3adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -4.0);
    const float w4adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -4.0);
    const float w5adjy = GET_TEXEL_QUAD_WEIGHTS(4.0, -4.0);
    const float w2diag = GET_TEXEL_QUAD_WEIGHTS(-6.0, -2.0);
    const float w1diag = GET_TEXEL_QUAD_WEIGHTS(-4.0, -2.0);
    const float w0diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -2.0);
    const float w0adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -2.0);
    const float w1adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -2.0);
    const float w2adjy = GET_TEXEL_QUAD_WEIGHTS(4.0, -2.0);
    const float w2adjx = GET_TEXEL_QUAD_WEIGHTS(-6.0, 0.0);
    const float w1adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 0.0);
    const float w0adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 0.0);
    const float w0curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 0.0);
    const float w1curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 0.0);
    const float w2curr = GET_TEXEL_QUAD_WEIGHTS(4.0, 0.0);
    const float w5adjx = GET_TEXEL_QUAD_WEIGHTS(-6.0, 2.0);
    const float w4adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 2.0);
    const float w3adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 2.0);
    const float w3curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 2.0);
    const float w4curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 2.0);
    const float w5curr = GET_TEXEL_QUAD_WEIGHTS(4.0, 2.0);
    const float w8adjx = GET_TEXEL_QUAD_WEIGHTS(-6.0, 4.0);
    const float w7adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 4.0);
    const float w6adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 4.0);
    const float w6curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 4.0);
    const float w7curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 4.0);
    const float w8curr = GET_TEXEL_QUAD_WEIGHTS(4.0, 4.0);
    #undef GET_TEXEL_QUAD_WEIGHTS
    //  Statically pack weights for runtime:
    const float4 w0 = float4(w0curr, w0adjx, w0adjy, w0diag);
    const float4 w1 = float4(w1curr, w1adjx, w1adjy, w1diag);
    const float4 w2 = float4(w2curr, w2adjx, w2adjy, w2diag);
    const float4 w3 = float4(w3curr, w3adjx, w3adjy, w3diag);
    const float4 w4 = float4(w4curr, w4adjx, w4adjy, w4diag);
    const float4 w5 = float4(w5curr, w5adjx, w5adjy, w5diag);
    const float4 w6 = float4(w6curr, w6adjx, w6adjy, w6diag);
    const float4 w7 = float4(w7curr, w7adjx, w7adjy, w7diag);
    const float4 w8 = float4(w8curr, w8adjx, w8adjy, w8diag);
    //  Get the weight sum inverse (normalization factor):
    const float4 weight_sum4 = w0 + w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8;
    const float2 weight_sum2 = weight_sum4.xy + weight_sum4.zw;
    const float weight_sum = weight_sum2.x + weight_sum2.y;
    const float weight_sum_inv = 1.0/(weight_sum);

    //  LOAD TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Get a uv vector from texel 0q0 of this quadrant to texel 0q3:
    const float2 dxdy_curr = dxdy * quad_vector.xy;
    //  Load bilinear samples for the current quadrant (for this fragment):
    const float3 sample0curr = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0curr_texel_offset).rgb;
    const float3 sample0adjx = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjx_texel_offset).rgb;
    const float3 sample0adjy = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjy_texel_offset).rgb;
    const float3 sample0diag = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0diag_texel_offset).rgb;
    const float3 sample1curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample1_texel_offset)).rgb;
    const float3 sample2curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample2_texel_offset)).rgb;
    const float3 sample3curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample3_texel_offset)).rgb;
    const float3 sample4curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample4_texel_offset)).rgb;
    const float3 sample5curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample5_texel_offset)).rgb;
    const float3 sample6curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample6_texel_offset)).rgb;
    const float3 sample7curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample7_texel_offset)).rgb;
    const float3 sample8curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample8_texel_offset)).rgb;

    //  GATHER NEIGHBORING SAMPLES AND SUM WEIGHTED SAMPLES:
    //  Fetch the samples from other fragments in the 2x2 quad:
    float3 sample1adjx, sample1adjy, sample1diag;
    float3 sample2adjx, sample2adjy, sample2diag;
    float3 sample3adjx, sample3adjy, sample3diag;
    float3 sample4adjx, sample4adjy, sample4diag;
    float3 sample5adjx, sample5adjy, sample5diag;
    float3 sample6adjx, sample6adjy, sample6diag;
    float3 sample7adjx, sample7adjy, sample7diag;
    float3 sample8adjx, sample8adjy, sample8diag;
    quad_gather(quad_vector, sample1curr, sample1adjx, sample1adjy, sample1diag);
    quad_gather(quad_vector, sample2curr, sample2adjx, sample2adjy, sample2diag);
    quad_gather(quad_vector, sample3curr, sample3adjx, sample3adjy, sample3diag);
    quad_gather(quad_vector, sample4curr, sample4adjx, sample4adjy, sample4diag);
    quad_gather(quad_vector, sample5curr, sample5adjx, sample5adjy, sample5diag);
    quad_gather(quad_vector, sample6curr, sample6adjx, sample6adjy, sample6diag);
    quad_gather(quad_vector, sample7curr, sample7adjx, sample7adjy, sample7diag);
    quad_gather(quad_vector, sample8curr, sample8adjx, sample8adjy, sample8diag);
    //  Statically normalize weights (so total = 1.0), and sum weighted samples.
    //  Fill each row of a matrix with an rgb sample and pre-multiply by the
    //  weights to obtain a weighted result:
    float3 sum = float3(0.0,0.0,0.0);
    sum += mul(w0, float4x3(sample0curr, sample0adjx, sample0adjy, sample0diag));
    sum += mul(w1, float4x3(sample1curr, sample1adjx, sample1adjy, sample1diag));
    sum += mul(w2, float4x3(sample2curr, sample2adjx, sample2adjy, sample2diag));
    sum += mul(w3, float4x3(sample3curr, sample3adjx, sample3adjy, sample3diag));
    sum += mul(w4, float4x3(sample4curr, sample4adjx, sample4adjy, sample4diag));
    sum += mul(w5, float4x3(sample5curr, sample5adjx, sample5adjy, sample5diag));
    sum += mul(w6, float4x3(sample6curr, sample6adjx, sample6adjy, sample6diag));
    sum += mul(w7, float4x3(sample7curr, sample7adjx, sample7adjy, sample7diag));
    sum += mul(w8, float4x3(sample8curr, sample8adjx, sample8adjy, sample8diag));
    return sum * weight_sum_inv;
}

float3 tex2Dblur10x10shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector,
    const float sigma)
{
    //  Perform a 1-pass mipmapped blur with shared samples across a pixel quad.
    //  Requires:   Same as tex2Dblur12x12shared()
    //  Returns:    A blurred texture lookup using a "virtual" 10x10 Gaussian
    //              blur (a 5x5 blur of carefully selected bilinear samples)
    //              of the given mip level.  There will be subtle inaccuracies,
    //              especially for small or high-frequency detailed sources.
    //  Description:
    //  First see the description for tex2Dblur12x12shared().  This
    //  function shares the same concept and sample placement, but each fragment
    //  only uses 25 of the 36 samples taken across the pixel quad (to cover a
    //  5x5 sample area, or 10x10 texel area), and it uses a lower standard
    //  deviation to compensate.  Thanks to symmetry, the 11 omitted samples
    //  are always the "same:"
    //      8adjx, 2adjx, 5adjx,
    //      6adjy, 7adjy, 8adjy,
    //      2diag, 5diag, 6diag, 7diag, 8diag

    //  COMPUTE COORDS FOR TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Statically compute bilinear sampling offsets (details in tex2Dblur12x12shared).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0off   = 1.0;
    const float w0_5off = exp(-(0.5*0.5) * denom_inv);
    const float w1off   = exp(-(1.0*1.0) * denom_inv);
    const float w1_5off = exp(-(1.5*1.5) * denom_inv);
    const float w2off   = exp(-(2.0*2.0) * denom_inv);
    const float w2_5off = exp(-(2.5*2.5) * denom_inv);
    const float w3_5off = exp(-(3.5*3.5) * denom_inv);
    const float w4_5off = exp(-(4.5*4.5) * denom_inv);
    const float w5_5off = exp(-(5.5*5.5) * denom_inv);
    const float texel0to1ratio = lerp(w1_5off/(w0_5off + w1_5off), 0.5, error_blurring);
    const float texel2to3ratio = lerp(w3_5off/(w2_5off + w3_5off), 0.5, error_blurring);
    const float texel4to5ratio = lerp(w5_5off/(w4_5off + w5_5off), 0.5, error_blurring);
    //  We don't share sample0*, so use the nearest destination fragment:
    const float texel0to1ratio_nearest = w1off/(w0off + w1off);
    const float texel1to2ratio_nearest = w2off/(w1off + w2off);
    //  Statically compute texel offsets from the bottom-right fragment to each
    //  bilinear sample in the bottom-right quadrant:
    const float2 sample0curr_texel_offset = float2(0.0, 0.0) + float2(texel0to1ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjx_texel_offset = float2(-1.0, 0.0) + float2(-texel1to2ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjy_texel_offset = float2(0.0, -1.0) + float2(texel0to1ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample0diag_texel_offset = float2(-1.0, -1.0) + float2(-texel1to2ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample1_texel_offset = float2(2.0, 0.0) + float2(texel2to3ratio, texel0to1ratio);
    const float2 sample2_texel_offset = float2(4.0, 0.0) + float2(texel4to5ratio, texel0to1ratio);
    const float2 sample3_texel_offset = float2(0.0, 2.0) + float2(texel0to1ratio, texel2to3ratio);
    const float2 sample4_texel_offset = float2(2.0, 2.0) + float2(texel2to3ratio, texel2to3ratio);
    const float2 sample5_texel_offset = float2(4.0, 2.0) + float2(texel4to5ratio, texel2to3ratio);
    const float2 sample6_texel_offset = float2(0.0, 4.0) + float2(texel0to1ratio, texel4to5ratio);
    const float2 sample7_texel_offset = float2(2.0, 4.0) + float2(texel2to3ratio, texel4to5ratio);
    const float2 sample8_texel_offset = float2(4.0, 4.0) + float2(texel4to5ratio, texel4to5ratio);

    //  CALCULATE KERNEL WEIGHTS:
    //  Statically compute bilinear sample weights at each destination fragment
    //  from the sum of their 4 texel weights (details in tex2Dblur12x12shared).
    #define GET_TEXEL_QUAD_WEIGHTS(xoff, yoff) \
        (exp(-LENGTH_SQ(float2(xoff, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff, yoff + 1.0)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff + 1.0)) * denom_inv))
    //  We only need 25 of the 36 sample weights.  Skip the following weights:
    //      8adjx, 2adjx, 5adjx,
    //      6adjy, 7adjy, 8adjy,
    //      2diag, 5diag, 6diag, 7diag, 8diag
    const float w4diag = GET_TEXEL_QUAD_WEIGHTS(-4.0, -4.0);
    const float w3diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -4.0);
    const float w3adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -4.0);
    const float w4adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -4.0);
    const float w5adjy = GET_TEXEL_QUAD_WEIGHTS(4.0, -4.0);
    const float w1diag = GET_TEXEL_QUAD_WEIGHTS(-4.0, -2.0);
    const float w0diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -2.0);
    const float w0adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -2.0);
    const float w1adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -2.0);
    const float w2adjy = GET_TEXEL_QUAD_WEIGHTS(4.0, -2.0);
    const float w1adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 0.0);
    const float w0adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 0.0);
    const float w0curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 0.0);
    const float w1curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 0.0);
    const float w2curr = GET_TEXEL_QUAD_WEIGHTS(4.0, 0.0);
    const float w4adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 2.0);
    const float w3adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 2.0);
    const float w3curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 2.0);
    const float w4curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 2.0);
    const float w5curr = GET_TEXEL_QUAD_WEIGHTS(4.0, 2.0);
    const float w7adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 4.0);
    const float w6adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 4.0);
    const float w6curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 4.0);
    const float w7curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 4.0);
    const float w8curr = GET_TEXEL_QUAD_WEIGHTS(4.0, 4.0);
    #undef GET_TEXEL_QUAD_WEIGHTS
    //  Get the weight sum inverse (normalization factor):
    const float weight_sum_inv = 1.0/(w0curr + w1curr + w2curr + w3curr +
        w4curr + w5curr + w6curr + w7curr + w8curr +
        w0adjx + w1adjx + w3adjx + w4adjx + w6adjx + w7adjx +
        w0adjy + w1adjy + w2adjy + w3adjy + w4adjy + w5adjy +
        w0diag + w1diag + w3diag + w4diag);
    //  Statically pack most weights for runtime.  Note the mixed packing:
    const float4 w0 = float4(w0curr, w0adjx, w0adjy, w0diag);
    const float4 w1 = float4(w1curr, w1adjx, w1adjy, w1diag);
    const float4 w3 = float4(w3curr, w3adjx, w3adjy, w3diag);
    const float4 w4 = float4(w4curr, w4adjx, w4adjy, w4diag);
    const float4 w2and5 = float4(w2curr, w2adjy, w5curr, w5adjy);
    const float4 w6and7 = float4(w6curr, w6adjx, w7curr, w7adjx);

    //  LOAD TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Get a uv vector from texel 0q0 of this quadrant to texel 0q3:
    const float2 dxdy_curr = dxdy * quad_vector.xy;
    //  Load bilinear samples for the current quadrant (for this fragment):
    const float3 sample0curr = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0curr_texel_offset).rgb;
    const float3 sample0adjx = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjx_texel_offset).rgb;
    const float3 sample0adjy = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjy_texel_offset).rgb;
    const float3 sample0diag = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0diag_texel_offset).rgb;
    const float3 sample1curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample1_texel_offset)).rgb;
    const float3 sample2curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample2_texel_offset)).rgb;
    const float3 sample3curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample3_texel_offset)).rgb;
    const float3 sample4curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample4_texel_offset)).rgb;
    const float3 sample5curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample5_texel_offset)).rgb;
    const float3 sample6curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample6_texel_offset)).rgb;
    const float3 sample7curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample7_texel_offset)).rgb;
    const float3 sample8curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample8_texel_offset)).rgb;

    //  GATHER NEIGHBORING SAMPLES AND SUM WEIGHTED SAMPLES:
    //  Fetch the samples from other fragments in the 2x2 quad in order of need:
    float3 sample1adjx, sample1adjy, sample1diag;
    float3 sample2adjx, sample2adjy, sample2diag;
    float3 sample3adjx, sample3adjy, sample3diag;
    float3 sample4adjx, sample4adjy, sample4diag;
    float3 sample5adjx, sample5adjy, sample5diag;
    float3 sample6adjx, sample6adjy, sample6diag;
    float3 sample7adjx, sample7adjy, sample7diag;
    quad_gather(quad_vector, sample1curr, sample1adjx, sample1adjy, sample1diag);
    quad_gather(quad_vector, sample2curr, sample2adjx, sample2adjy, sample2diag);
    quad_gather(quad_vector, sample3curr, sample3adjx, sample3adjy, sample3diag);
    quad_gather(quad_vector, sample4curr, sample4adjx, sample4adjy, sample4diag);
    quad_gather(quad_vector, sample5curr, sample5adjx, sample5adjy, sample5diag);
    quad_gather(quad_vector, sample6curr, sample6adjx, sample6adjy, sample6diag);
    quad_gather(quad_vector, sample7curr, sample7adjx, sample7adjy, sample7diag);
    //  Statically normalize weights (so total = 1.0), and sum weighted samples.
    //  Fill each row of a matrix with an rgb sample and pre-multiply by the
    //  weights to obtain a weighted result.  First do the simple ones:
    float3 sum = float3(0.0,0.0,0.0);
    sum += mul(w0, float4x3(sample0curr, sample0adjx, sample0adjy, sample0diag));
    sum += mul(w1, float4x3(sample1curr, sample1adjx, sample1adjy, sample1diag));
    sum += mul(w3, float4x3(sample3curr, sample3adjx, sample3adjy, sample3diag));
    sum += mul(w4, float4x3(sample4curr, sample4adjx, sample4adjy, sample4diag));
    //  Now do the mixed-sample ones:
    sum += mul(w2and5, float4x3(sample2curr, sample2adjy, sample5curr, sample5adjy));
    sum += mul(w6and7, float4x3(sample6curr, sample6adjx, sample7curr, sample7adjx));
    sum += w8curr * sample8curr;
    //  Normalize the sum (so the weights add to 1.0) and return:
    return sum * weight_sum_inv;
}

float3 tex2Dblur8x8shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector,
    const float sigma)
{
    //  Perform a 1-pass mipmapped blur with shared samples across a pixel quad.
    //  Requires:   Same as tex2Dblur12x12shared()
    //  Returns:    A blurred texture lookup using a "virtual" 8x8 Gaussian
    //              blur (a 4x4 blur of carefully selected bilinear samples)
    //              of the given mip level.  There will be subtle inaccuracies,
    //              especially for small or high-frequency detailed sources.
    //  Description:
    //  First see the description for tex2Dblur12x12shared().  This function
    //  shares the same concept and a similar sample placement, except each
    //  quadrant contains 4x4 texels and 2x2 samples instead of 6x6 and 3x3
    //  respectively.  There could be a total of 16 samples, 4 of which each
    //  fragment is responsible for, but each fragment loads 0a/0b/0c/0d with
    //  its own offset to reduce shared sample artifacts, bringing the sample
    //  count for each fragment to 7.  Sample placement:
    //      3a 2a 2b 3b
    //      1a 0a 0b 1b
    //      1c 0c 0d 1d
    //      3c 2c 2d 3d
    //  Texel placement:
    //      3a3 3a2 2a3 2a2 2b2 2b3 3b2 3b3
    //      3a1 3a0 2a1 2a0 2b0 2b1 3b0 3b1
    //      1a3 1a2 0a3 0a2 0b2 0b3 1b2 1b3
    //      1a1 1a0 0a1 0a0 0b0 0b1 1b0 1b1
    //      1c1 1c0 0c1 0c0 0d0 0d1 1d0 1d1
    //      1c3 1c2 0c3 0c2 0d2 0d3 1d2 1d3
    //      3c1 3c0 2c1 2c0 2d0 2d1 3d0 4d1
    //      3c3 3c2 2c3 2c2 2d2 2d3 3d2 4d3
    
    //  COMPUTE COORDS FOR TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Statically compute bilinear sampling offsets (details in tex2Dblur12x12shared).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0off   = 1.0;
    const float w0_5off = exp(-(0.5*0.5) * denom_inv);
    const float w1off   = exp(-(1.0*1.0) * denom_inv);
    const float w1_5off = exp(-(1.5*1.5) * denom_inv);
    const float w2off   = exp(-(2.0*2.0) * denom_inv);
    const float w2_5off = exp(-(2.5*2.5) * denom_inv);
    const float w3_5off = exp(-(3.5*3.5) * denom_inv);
    const float texel0to1ratio = lerp(w1_5off/(w0_5off + w1_5off), 0.5, error_blurring);
    const float texel2to3ratio = lerp(w3_5off/(w2_5off + w3_5off), 0.5, error_blurring);
    //  We don't share sample0*, so use the nearest destination fragment:
    const float texel0to1ratio_nearest = w1off/(w0off + w1off);
    const float texel1to2ratio_nearest = w2off/(w1off + w2off);
    //  Statically compute texel offsets from the bottom-right fragment to each
    //  bilinear sample in the bottom-right quadrant:
    const float2 sample0curr_texel_offset = float2(0.0, 0.0) + float2(texel0to1ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjx_texel_offset = float2(-1.0, 0.0) + float2(-texel1to2ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjy_texel_offset = float2(0.0, -1.0) + float2(texel0to1ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample0diag_texel_offset = float2(-1.0, -1.0) + float2(-texel1to2ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample1_texel_offset = float2(2.0, 0.0) + float2(texel2to3ratio, texel0to1ratio);
    const float2 sample2_texel_offset = float2(0.0, 2.0) + float2(texel0to1ratio, texel2to3ratio);
    const float2 sample3_texel_offset = float2(2.0, 2.0) + float2(texel2to3ratio, texel2to3ratio);

    //  CALCULATE KERNEL WEIGHTS:
    //  Statically compute bilinear sample weights at each destination fragment
    //  from the sum of their 4 texel weights (details in tex2Dblur12x12shared).
    #define GET_TEXEL_QUAD_WEIGHTS(xoff, yoff) \
        (exp(-LENGTH_SQ(float2(xoff, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff, yoff + 1.0)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff + 1.0)) * denom_inv))
    const float w3diag = GET_TEXEL_QUAD_WEIGHTS(-4.0, -4.0);
    const float w2diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -4.0);
    const float w2adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -4.0);
    const float w3adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -4.0);
    const float w1diag = GET_TEXEL_QUAD_WEIGHTS(-4.0, -2.0);
    const float w0diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -2.0);
    const float w0adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -2.0);
    const float w1adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -2.0);
    const float w1adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 0.0);
    const float w0adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 0.0);
    const float w0curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 0.0);
    const float w1curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 0.0);
    const float w3adjx = GET_TEXEL_QUAD_WEIGHTS(-4.0, 2.0);
    const float w2adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 2.0);
    const float w2curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 2.0);
    const float w3curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 2.0);
    #undef GET_TEXEL_QUAD_WEIGHTS
    //  Statically pack weights for runtime:
    const float4 w0 = float4(w0curr, w0adjx, w0adjy, w0diag);
    const float4 w1 = float4(w1curr, w1adjx, w1adjy, w1diag);
    const float4 w2 = float4(w2curr, w2adjx, w2adjy, w2diag);
    const float4 w3 = float4(w3curr, w3adjx, w3adjy, w3diag);
    //  Get the weight sum inverse (normalization factor):
    const float4 weight_sum4 = w0 + w1 + w2 + w3;
    const float2 weight_sum2 = weight_sum4.xy + weight_sum4.zw;
    const float weight_sum = weight_sum2.x + weight_sum2.y;
    const float weight_sum_inv = 1.0/(weight_sum);

    //  LOAD TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Get a uv vector from texel 0q0 of this quadrant to texel 0q3:
    const float2 dxdy_curr = dxdy * quad_vector.xy;
    //  Load bilinear samples for the current quadrant (for this fragment):
    const float3 sample0curr = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0curr_texel_offset).rgb;
    const float3 sample0adjx = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjx_texel_offset).rgb;
    const float3 sample0adjy = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjy_texel_offset).rgb;
    const float3 sample0diag = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0diag_texel_offset).rgb;
    const float3 sample1curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample1_texel_offset)).rgb;
    const float3 sample2curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample2_texel_offset)).rgb;
    const float3 sample3curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample3_texel_offset)).rgb;

    //  GATHER NEIGHBORING SAMPLES AND SUM WEIGHTED SAMPLES:
    //  Fetch the samples from other fragments in the 2x2 quad:
    float3 sample1adjx, sample1adjy, sample1diag;
    float3 sample2adjx, sample2adjy, sample2diag;
    float3 sample3adjx, sample3adjy, sample3diag;
    quad_gather(quad_vector, sample1curr, sample1adjx, sample1adjy, sample1diag);
    quad_gather(quad_vector, sample2curr, sample2adjx, sample2adjy, sample2diag);
    quad_gather(quad_vector, sample3curr, sample3adjx, sample3adjy, sample3diag);
    //  Statically normalize weights (so total = 1.0), and sum weighted samples.
    //  Fill each row of a matrix with an rgb sample and pre-multiply by the
    //  weights to obtain a weighted result:
    float3 sum = float3(0.0,0.0,0.0);
    sum += mul(w0, float4x3(sample0curr, sample0adjx, sample0adjy, sample0diag));
    sum += mul(w1, float4x3(sample1curr, sample1adjx, sample1adjy, sample1diag));
    sum += mul(w2, float4x3(sample2curr, sample2adjx, sample2adjy, sample2diag));
    sum += mul(w3, float4x3(sample3curr, sample3adjx, sample3adjy, sample3diag));
    return sum * weight_sum_inv;
}

float3 tex2Dblur6x6shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector,
    const float sigma)
{
    //  Perform a 1-pass mipmapped blur with shared samples across a pixel quad.
    //  Requires:   Same as tex2Dblur12x12shared()
    //  Returns:    A blurred texture lookup using a "virtual" 6x6 Gaussian
    //              blur (a 3x3 blur of carefully selected bilinear samples)
    //              of the given mip level.  There will be some inaccuracies,subtle inaccuracies,
    //              especially for small or high-frequency detailed sources.
    //  Description:
    //  First see the description for tex2Dblur8x8shared().  This
    //  function shares the same concept and sample placement, but each fragment
    //  only uses 9 of the 16 samples taken across the pixel quad (to cover a
    //  3x3 sample area, or 6x6 texel area), and it uses a lower standard
    //  deviation to compensate.  Thanks to symmetry, the 7 omitted samples
    //  are always the "same:"
    //      1adjx, 3adjx
    //      2adjy, 3adjy
    //      1diag, 2diag, 3diag

    //  COMPUTE COORDS FOR TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Statically compute bilinear sampling offsets (details in tex2Dblur12x12shared).
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0off   = 1.0;
    const float w0_5off = exp(-(0.5*0.5) * denom_inv);
    const float w1off   = exp(-(1.0*1.0) * denom_inv);
    const float w1_5off = exp(-(1.5*1.5) * denom_inv);
    const float w2off   = exp(-(2.0*2.0) * denom_inv);
    const float w2_5off = exp(-(2.5*2.5) * denom_inv);
    const float w3_5off = exp(-(3.5*3.5) * denom_inv);
    const float texel0to1ratio = lerp(w1_5off/(w0_5off + w1_5off), 0.5, error_blurring);
    const float texel2to3ratio = lerp(w3_5off/(w2_5off + w3_5off), 0.5, error_blurring);
    //  We don't share sample0*, so use the nearest destination fragment:
    const float texel0to1ratio_nearest = w1off/(w0off + w1off);
    const float texel1to2ratio_nearest = w2off/(w1off + w2off);
    //  Statically compute texel offsets from the bottom-right fragment to each
    //  bilinear sample in the bottom-right quadrant:
    const float2 sample0curr_texel_offset = float2(0.0, 0.0) + float2(texel0to1ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjx_texel_offset = float2(-1.0, 0.0) + float2(-texel1to2ratio_nearest, texel0to1ratio_nearest);
    const float2 sample0adjy_texel_offset = float2(0.0, -1.0) + float2(texel0to1ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample0diag_texel_offset = float2(-1.0, -1.0) + float2(-texel1to2ratio_nearest, -texel1to2ratio_nearest);
    const float2 sample1_texel_offset = float2(2.0, 0.0) + float2(texel2to3ratio, texel0to1ratio);
    const float2 sample2_texel_offset = float2(0.0, 2.0) + float2(texel0to1ratio, texel2to3ratio);
    const float2 sample3_texel_offset = float2(2.0, 2.0) + float2(texel2to3ratio, texel2to3ratio);

    //  CALCULATE KERNEL WEIGHTS:
    //  Statically compute bilinear sample weights at each destination fragment
    //  from the sum of their 4 texel weights (details in tex2Dblur12x12shared).
    #define GET_TEXEL_QUAD_WEIGHTS(xoff, yoff) \
        (exp(-LENGTH_SQ(float2(xoff, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff, yoff + 1.0)) * denom_inv) + \
        exp(-LENGTH_SQ(float2(xoff + 1.0, yoff + 1.0)) * denom_inv))
    //  We only need 9 of the 16 sample weights.  Skip the following weights:
    //      1adjx, 3adjx
    //      2adjy, 3adjy
    //      1diag, 2diag, 3diag
    const float w0diag = GET_TEXEL_QUAD_WEIGHTS(-2.0, -2.0);
    const float w0adjy = GET_TEXEL_QUAD_WEIGHTS(0.0, -2.0);
    const float w1adjy = GET_TEXEL_QUAD_WEIGHTS(2.0, -2.0);
    const float w0adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 0.0);
    const float w0curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 0.0);
    const float w1curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 0.0);
    const float w2adjx = GET_TEXEL_QUAD_WEIGHTS(-2.0, 2.0);
    const float w2curr = GET_TEXEL_QUAD_WEIGHTS(0.0, 2.0);
    const float w3curr = GET_TEXEL_QUAD_WEIGHTS(2.0, 2.0);
    #undef GET_TEXEL_QUAD_WEIGHTS
    //  Get the weight sum inverse (normalization factor):
    const float weight_sum_inv = 1.0/(w0curr + w1curr + w2curr + w3curr +
        w0adjx + w2adjx + w0adjy + w1adjy + w0diag);
    //  Statically pack some weights for runtime:
    const float4 w0 = float4(w0curr, w0adjx, w0adjy, w0diag);

    //  LOAD TEXTURE SAMPLES THIS FRAGMENT IS RESPONSIBLE FOR:
    //  Get a uv vector from texel 0q0 of this quadrant to texel 0q3:
    const float2 dxdy_curr = dxdy * quad_vector.xy;
    //  Load bilinear samples for the current quadrant (for this fragment):
    const float3 sample0curr = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0curr_texel_offset).rgb;
    const float3 sample0adjx = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjx_texel_offset).rgb;
    const float3 sample0adjy = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0adjy_texel_offset).rgb;
    const float3 sample0diag = tex2D_linearize(tex, tex_uv.xy + dxdy_curr * sample0diag_texel_offset).rgb;
    const float3 sample1curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample1_texel_offset)).rgb;
    const float3 sample2curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample2_texel_offset)).rgb;
    const float3 sample3curr = tex2Dlod_linearize(tex, tex_uv + uv2_to_uv4(dxdy_curr * sample3_texel_offset)).rgb;

    //  GATHER NEIGHBORING SAMPLES AND SUM WEIGHTED SAMPLES:
    //  Fetch the samples from other fragments in the 2x2 quad:
    float3 sample1adjx, sample1adjy, sample1diag;
    float3 sample2adjx, sample2adjy, sample2diag;
    quad_gather(quad_vector, sample1curr, sample1adjx, sample1adjy, sample1diag);
    quad_gather(quad_vector, sample2curr, sample2adjx, sample2adjy, sample2diag);
    //  Statically normalize weights (so total = 1.0), and sum weighted samples.
    //  Fill each row of a matrix with an rgb sample and pre-multiply by the
    //  weights to obtain a weighted result for sample1*, and handle the rest
    //  of the weights more directly/verbosely:
    float3 sum = float3(0.0,0.0,0.0);
    sum += mul(w0, float4x3(sample0curr, sample0adjx, sample0adjy, sample0diag));
    sum += w1curr * sample1curr + w1adjy * sample1adjy + w2curr * sample2curr +
            w2adjx * sample2adjx + w3curr * sample3curr;
    return sum * weight_sum_inv;
}


///////////////////////  MAX OPTIMAL SIGMA BLUR WRAPPERS  //////////////////////

//  The following blurs are static wrappers around the dynamic blurs above.
//  HOPEFULLY, the compiler will be smart enough to do constant-folding.

//  Resizable separable blurs:
inline float3 tex2Dblur11resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur11resize(tex, tex_uv, dxdy, blur11_std_dev);
}
inline float3 tex2Dblur9resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur9resize(tex, tex_uv, dxdy, blur9_std_dev);
}
inline float3 tex2Dblur7resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur7resize(tex, tex_uv, dxdy, blur7_std_dev);
}
inline float3 tex2Dblur5resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur5resize(tex, tex_uv, dxdy, blur5_std_dev);
}
inline float3 tex2Dblur3resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur3resize(tex, tex_uv, dxdy, blur3_std_dev);
}
//  Fast separable blurs:
inline float3 tex2Dblur11fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur11fast(tex, tex_uv, dxdy, blur11_std_dev);
}
inline float3 tex2Dblur9fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur9fast(tex, tex_uv, dxdy, blur9_std_dev);
}
inline float3 tex2Dblur7fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur7fast(tex, tex_uv, dxdy, blur7_std_dev);
}
inline float3 tex2Dblur5fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur5fast(tex, tex_uv, dxdy, blur5_std_dev);
}
inline float3 tex2Dblur3fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur3fast(tex, tex_uv, dxdy, blur3_std_dev);
}
//  Huge, "fast" separable blurs:
inline float3 tex2Dblur43fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur43fast(tex, tex_uv, dxdy, blur43_std_dev);
}
inline float3 tex2Dblur31fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur31fast(tex, tex_uv, dxdy, blur31_std_dev);
}
inline float3 tex2Dblur25fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur25fast(tex, tex_uv, dxdy, blur25_std_dev);
}
inline float3 tex2Dblur17fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur17fast(tex, tex_uv, dxdy, blur17_std_dev);
}
//  Resizable one-pass blurs:
inline float3 tex2Dblur3x3resize(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur3x3resize(tex, tex_uv, dxdy, blur3_std_dev);
}
//  "Fast" one-pass blurs:
inline float3 tex2Dblur9x9(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur9x9(tex, tex_uv, dxdy, blur9_std_dev);
}
inline float3 tex2Dblur7x7(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur7x7(tex, tex_uv, dxdy, blur7_std_dev);
}
inline float3 tex2Dblur5x5(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur5x5(tex, tex_uv, dxdy, blur5_std_dev);
}
inline float3 tex2Dblur3x3(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy)
{
    return tex2Dblur3x3(tex, tex_uv, dxdy, blur3_std_dev);
}
//  "Fast" shared-sample one-pass blurs:
inline float3 tex2Dblur12x12shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector)
{
    return tex2Dblur12x12shared(tex, tex_uv, dxdy, quad_vector, blur12_std_dev);
}
inline float3 tex2Dblur10x10shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector)
{
    return tex2Dblur10x10shared(tex, tex_uv, dxdy, quad_vector, blur10_std_dev);
}
inline float3 tex2Dblur8x8shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector)
{
    return tex2Dblur8x8shared(tex, tex_uv, dxdy, quad_vector, blur8_std_dev);
}
inline float3 tex2Dblur6x6shared(const sampler2D tex,
    const float4 tex_uv, const float2 dxdy, const float4 quad_vector)
{
    return tex2Dblur6x6shared(tex, tex_uv, dxdy, quad_vector, blur6_std_dev);
}


#endif  //  BLUR_FUNCTIONS_H

////////////////////////////  END BLUR-FUNCTIONS  ///////////////////////////

/***************** END blur-functions.h ******************/

//#include "../include/bloom-functions.h"
/***************** BEGIN bloom-functions.h ******************/

////////////////////////////  BEGIN BLOOM-FUNCTIONS  ///////////////////////////

#ifndef BLOOM_FUNCTIONS_H
#define BLOOM_FUNCTIONS_H

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA


/////////////////////////////////  DESCRIPTION  ////////////////////////////////

//  These utility functions and constants help several passes determine the
//  size and center texel weight of the phosphor bloom in a uniform manner.


//////////////////////////////////  INCLUDES  //////////////////////////////////

//  We need to calculate the correct blur sigma using some .cgp constants:
//#include "../include/user-settings.h"
//#include "../include/derived-settings-and-constants.h"
//#include "../include/blur-functions.h"

///////////////////////////////  BLOOM CONSTANTS  //////////////////////////////

//  Compute constants with manual inlines of the functions below:
static const float bloom_diff_thresh = 1.0/256.0;



///////////////////////////////////  HELPERS  //////////////////////////////////

inline float get_min_sigma_to_blur_triad(const float triad_size,
    const float thresh)
{
    //  Requires:   1.) triad_size is the final phosphor triad size in pixels
    //              2.) thresh is the max desired pixel difference in the
    //                  blurred triad (e.g. 1.0/256.0).
    //  Returns:    Return the minimum sigma that will fully blur a phosphor
    //              triad on the screen to an even color, within thresh.
    //              This closed-form function was found by curve-fitting data.
    //  Estimate: max error = ~0.086036, mean sq. error = ~0.0013387:
    return -0.05168 + 0.6113*triad_size -
        1.122*triad_size*sqrt(0.000416 + thresh);
    //  Estimate: max error = ~0.16486, mean sq. error = ~0.0041041:
    //return 0.5985*triad_size - triad_size*sqrt(thresh)
}

inline float get_absolute_scale_blur_sigma(const float thresh)
{
    //  Requires:   1.) min_expected_triads must be a global float.  The number
    //                  of horizontal phosphor triads in the final image must be
    //                  >= min_allowed_viewport_triads.x for realistic results.
    //              2.) bloom_approx_scale_x must be a global float equal to the
    //                  absolute horizontal scale of BLOOM_APPROX.
    //              3.) bloom_approx_scale_x/min_allowed_viewport_triads.x
    //                  should be <= 1.1658025090 to keep the final result <
    //                  0.62666015625 (the largest sigma ensuring the largest
    //                  unused texel weight stays < 1.0/256.0 for a 3x3 blur).
    //              4.) thresh is the max desired pixel difference in the
    //                  blurred triad (e.g. 1.0/256.0).
    //  Returns:    Return the minimum Gaussian sigma that will blur the pass
    //              output as much as it would have taken to blur away
    //              bloom_approx_scale_x horizontal phosphor triads.
    //  Description:
    //  BLOOM_APPROX should look like a downscaled phosphor blur.  Ideally, we'd
    //  use the same blur sigma as the actual phosphor bloom and scale it down
    //  to the current resolution with (bloom_approx_scale_x/viewport_size_x), but
    //  we don't know the viewport size in this pass.  Instead, we'll blur as
    //  much as it would take to blur away min_allowed_viewport_triads.x.  This
    //  will blur "more than necessary" if the user actually uses more triads,
    //  but that's not terrible either, because blurring a constant fraction of
    //  the viewport may better resemble a true optical bloom anyway (since the
    //  viewport will generally be about the same fraction of each player's
    //  field of view, regardless of screen size and resolution).
    //  Assume an extremely large viewport size for asymptotic results.
    return bloom_approx_scale_x/max_viewport_size_x *
        get_min_sigma_to_blur_triad(
            max_viewport_size_x/min_allowed_viewport_triads.x, thresh);
}

inline float get_center_weight(const float sigma)
{
    //  Given a Gaussian blur sigma, get the blur weight for the center texel.
    #ifdef RUNTIME_PHOSPHOR_BLOOM_SIGMA
        return get_fast_gaussian_weight_sum_inv(sigma);
    #else
        const float denom_inv = 0.5/(sigma*sigma);
        const float w0 = 1.0;
        const float w1 = exp(-1.0 * denom_inv);
        const float w2 = exp(-4.0 * denom_inv);
        const float w3 = exp(-9.0 * denom_inv);
        const float w4 = exp(-16.0 * denom_inv);
        const float w5 = exp(-25.0 * denom_inv);
        const float w6 = exp(-36.0 * denom_inv);
        const float w7 = exp(-49.0 * denom_inv);
        const float w8 = exp(-64.0 * denom_inv);
        const float w9 = exp(-81.0 * denom_inv);
        const float w10 = exp(-100.0 * denom_inv);
        const float w11 = exp(-121.0 * denom_inv);
        const float w12 = exp(-144.0 * denom_inv);
        const float w13 = exp(-169.0 * denom_inv);
        const float w14 = exp(-196.0 * denom_inv);
        const float w15 = exp(-225.0 * denom_inv);
        const float w16 = exp(-256.0 * denom_inv);
        const float w17 = exp(-289.0 * denom_inv);
        const float w18 = exp(-324.0 * denom_inv);
        const float w19 = exp(-361.0 * denom_inv);
        const float w20 = exp(-400.0 * denom_inv);
        const float w21 = exp(-441.0 * denom_inv);
        //  Note: If the implementation uses a smaller blur than the max allowed,
        //  the worst case scenario is that the center weight will be overestimated,
        //  so we'll put a bit more energy into the brightpass...no huge deal.
        //  Then again, if the implementation uses a larger blur than the max
        //  "allowed" because of dynamic branching, the center weight could be
        //  underestimated, which is more of a problem...consider always using
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
            //  43x blur:
            const float weight_sum_inv = 1.0 /
                (w0 + 2.0 * (w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8 + w9 + w10 +
                w11 + w12 + w13 + w14 + w15 + w16 + w17 + w18 + w19 + w20 + w21));
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
            //  31x blur:
            const float weight_sum_inv = 1.0 /
                (w0 + 2.0 * (w1 + w2 + w3 + w4 + w5 + w6 + w7 +
                w8 + w9 + w10 + w11 + w12 + w13 + w14 + w15));
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
            //  25x blur:
            const float weight_sum_inv = 1.0 / (w0 + 2.0 * (
                w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8 + w9 + w10 + w11 + w12));
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
            //  17x blur:
            const float weight_sum_inv = 1.0 / (w0 + 2.0 * (
                w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8));
        #else
            //  9x blur:
            const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
        const float center_weight = weight_sum_inv * weight_sum_inv;
        return center_weight;
    #endif
}

inline float3 tex2DblurNfast(const sampler2D texture, const float2 tex_uv,
    const float2 dxdy, const float sigma)
{
    //  If sigma is static, we can safely branch and use the smallest blur
    //  that's big enough.  Ignore #define hints, because we'll only use a
    //  large blur if we actually need it, and the branches cost nothing.
    #ifndef RUNTIME_PHOSPHOR_BLOOM_SIGMA
        #define PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
    #else
        //  It's still worth branching if the profile supports dynamic branches:
        //  It's much faster than using a hugely excessive blur, but each branch
        //  eats ~1% FPS.
        #ifdef DRIVERS_ALLOW_DYNAMIC_BRANCHES
            #define PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
        #endif
    #endif
    //  Failed optimization notes:
    //  I originally created a same-size mipmapped 5-tap separable blur10 that
    //  could handle any sigma by reaching into lower mip levels.  It was
    //  as fast as blur25fast for runtime sigmas and a tad faster than
    //  blur31fast for static sigmas, but mipmapping two viewport-size passes
    //  ate 10% of FPS across all codepaths, so it wasn't worth it.
    #ifdef PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
        if(sigma <= blur9_std_dev)
        {
            return tex2Dblur9fast(texture, tex_uv, dxdy, sigma);
        }
        else if(sigma <= blur17_std_dev)
        {
            return tex2Dblur17fast(texture, tex_uv, dxdy, sigma);
        }
        else if(sigma <= blur25_std_dev)
        {
            return tex2Dblur25fast(texture, tex_uv, dxdy, sigma);
        }
        else if(sigma <= blur31_std_dev)
        {
            return tex2Dblur31fast(texture, tex_uv, dxdy, sigma);
        }
        else
        {
            return tex2Dblur43fast(texture, tex_uv, dxdy, sigma);
        }
    #else
        //  If we can't afford to branch, we can only guess at what blur
        //  size we need.  Therefore, use the largest blur allowed.
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
            return tex2Dblur43fast(texture, tex_uv, dxdy, sigma);
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
            return tex2Dblur31fast(texture, tex_uv, dxdy, sigma);
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
            return tex2Dblur25fast(texture, tex_uv, dxdy, sigma);
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
            return tex2Dblur17fast(texture, tex_uv, dxdy, sigma);
        #else
            return tex2Dblur9fast(texture, tex_uv, dxdy, sigma);
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
        #endif  //  PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
    #endif  //  PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
}

inline float get_bloom_approx_sigma(const float output_size_x_runtime,
    const float estimated_viewport_size_x)
{
    //  Requires:   1.) output_size_x_runtime == BLOOM_APPROX.output_size.x.
    //                  This is included for dynamic codepaths just in case the
    //                  following two globals are incorrect:
    //              2.) bloom_approx_size_x_for_skip should == the same
    //                  if PHOSPHOR_BLOOM_FAKE is #defined
    //              3.) bloom_approx_size_x should == the same otherwise
    //  Returns:    For gaussian4x4, return a dynamic small bloom sigma that's
    //              as close to optimal as possible given available information.
    //              For blur3x3, return the a static small bloom sigma that
    //              works well for typical cases.  Otherwise, we're using simple
    //              bilinear filtering, so use static calculations.
    //  Assume the default static value.  This is a compromise that ensures
    //  typical triads are blurred, even if unusually large ones aren't.
    static const float mask_num_triads_static =
        max(min_allowed_viewport_triads.x, mask_num_triads_desired_static);
    const float mask_num_triads_from_size =
        estimated_viewport_size_x/mask_triad_size_desired;
    const float mask_num_triads_runtime = max(min_allowed_viewport_triads.x,
        lerp(mask_num_triads_from_size, mask_num_triads_desired,
            mask_specify_num_triads));
    //  Assume an extremely large viewport size for asymptotic results:
    static const float max_viewport_size_x = 1080.0*1024.0*(4.0/3.0);
    if(bloom_approx_filter > 1.5)   //  4x4 true Gaussian resize
    {
        //  Use the runtime num triads and output size:
        const float asymptotic_triad_size =
            max_viewport_size_x/mask_num_triads_runtime;
        const float asymptotic_sigma = get_min_sigma_to_blur_triad(
            asymptotic_triad_size, bloom_diff_thresh);
        const float bloom_approx_sigma =
            asymptotic_sigma * output_size_x_runtime/max_viewport_size_x;
        //  The BLOOM_APPROX input has to be ORIG_LINEARIZED to avoid moire, but
        //  account for the Gaussian scanline sigma from the last pass too.
        //  The bloom will be too wide horizontally but tall enough vertically.
        return length(float2(bloom_approx_sigma, beam_max_sigma));
    }
    else    //  3x3 blur resize (the bilinear resize doesn't need a sigma)
    {
        //  We're either using blur3x3 or bilinear filtering.  The biggest
        //  reason to choose blur3x3 is to avoid dynamic weights, so use a
        //  static calculation.
        #ifdef PHOSPHOR_BLOOM_FAKE
            static const float output_size_x_static =
                bloom_approx_size_x_for_fake;
        #else
            static const float output_size_x_static = bloom_approx_size_x;
        #endif
        static const float asymptotic_triad_size =
            max_viewport_size_x/mask_num_triads_static;
        const float asymptotic_sigma = get_min_sigma_to_blur_triad(
            asymptotic_triad_size, bloom_diff_thresh);
        const float bloom_approx_sigma =
            asymptotic_sigma * output_size_x_static/max_viewport_size_x;
        //  The BLOOM_APPROX input has to be ORIG_LINEARIZED to avoid moire, but
        //  try accounting for the Gaussian scanline sigma from the last pass
        //  too; use the static default value:
        return length(float2(bloom_approx_sigma, beam_max_sigma_static));
    }
}

inline float get_final_bloom_sigma(const float bloom_sigma_runtime)
{
    //  Requires:   1.) bloom_sigma_runtime is a precalculated sigma that's
    //                  optimal for the [known] triad size.
    //              2.) Call this from a fragment shader (not a vertex shader),
    //                  or blurring with static sigmas won't be constant-folded.
    //  Returns:    Return the optimistic static sigma if the triad size is
    //              known at compile time.  Otherwise return the optimal runtime
    //              sigma (10% slower) or an implementation-specific compromise
    //              between an optimistic or pessimistic static sigma.
    //  Notes:      Call this from the fragment shader, NOT the vertex shader,
    //              so static sigmas can be constant-folded!
    const float bloom_sigma_optimistic = get_min_sigma_to_blur_triad(
        mask_triad_size_desired_static, bloom_diff_thresh);
    #ifdef RUNTIME_PHOSPHOR_BLOOM_SIGMA
        return bloom_sigma_runtime;
    #else
        //  Overblurring looks as bad as underblurring, so assume average-size
        //  triads, not worst-case huge triads:
        return bloom_sigma_optimistic;
    #endif
}


#endif  //  BLOOM_FUNCTIONS_H

////////////////////////////  END BLOOM-FUNCTIONS  ///////////////////////////

/***************** END bloom-functions.h ******************/

//#include "../include/gamma-management.h"

///////////////////////////////////  HELPERS  //////////////////////////////////

float3 tex2Dresize_gaussian4x4(sampler2D tex, float2 tex_uv, float2 dxdy, float2 tex_size, float2 texture_size_inv, float2 tex_uv_to_pixel_scale, float sigma)
{
    //  Requires:   1.) All requirements of gamma-management.h must be satisfied!
    //              2.) filter_linearN must == "true" in your .cgp preset.
    //              3.) mipmap_inputN must == "true" in your .cgp preset if
    //                  output_size << SRC.video_size.
    //              4.) dxdy should contain the uv pixel spacing:
    //                      dxdy = max(float2(1.0),
    //                          SRC.video_size/output_size)/SRC.texture_size;
    //              5.) texture_size == SRC.texture_size
    //              6.) texture_size_inv == float2(1.0)/SRC.texture_size
    //              7.) tex_uv_to_pixel_scale == output_size *
    //                      SRC.texture_size / SRC.video_size;
    //              8.) sigma is the desired Gaussian standard deviation, in
    //                  terms of output pixels.  It should be < ~0.66171875 to
    //                  ensure the first unused sample (outside the 4x4 box) has
    //                  a weight < 1.0/256.0.
    //  Returns:    A true 4x4 Gaussian resize of the input.
    //  Description:
    //  Given correct inputs, this Gaussian resizer samples 4 pixel locations
    //  along each downsized dimension and/or 4 texel locations along each
    //  upsized dimension.  It computes dynamic weights based on the pixel-space
    //  distance of each sample from the destination pixel.  It is arbitrarily
    //  resizable and higher quality than tex2Dblur3x3_resize, but it's slower.
    //  TODO: Move this to a more suitable file once there are others like it.
    const float denom_inv = 0.5/(sigma*sigma);
    //  We're taking 4x4 samples, and we're snapping to texels for upsizing.
    //  Find texture coords for sample 5 (second row, second column):
    const float2 curr_texel = tex_uv * tex_size;
    const float2 prev_texel =
        floor(curr_texel - float2(under_half)) + float2(0.5);
    const float2 prev_texel_uv = prev_texel * texture_size_inv;
    const float2 snap = float2((dxdy.x <= texture_size_inv.x), (dxdy.y <= texture_size_inv.y));
    const float2 sample5_downsize_uv = tex_uv - 0.5 * dxdy;
    const float2 sample5_uv = lerp(sample5_downsize_uv, prev_texel_uv, snap);
    //  Compute texture coords for other samples:
    const float2 dx = float2(dxdy.x, 0.0);
    const float2 sample0_uv = sample5_uv - dxdy;
    const float2 sample10_uv = sample5_uv + dxdy;
    const float2 sample15_uv = sample5_uv + 2.0 * dxdy;
    const float2 sample1_uv = sample0_uv + dx;
    const float2 sample2_uv = sample0_uv + 2.0 * dx;
    const float2 sample3_uv = sample0_uv + 3.0 * dx;
    const float2 sample4_uv = sample5_uv - dx;
    const float2 sample6_uv = sample5_uv + dx;
    const float2 sample7_uv = sample5_uv + 2.0 * dx;
    const float2 sample8_uv = sample10_uv - 2.0 * dx;
    const float2 sample9_uv = sample10_uv - dx;
    const float2 sample11_uv = sample10_uv + dx;
    const float2 sample12_uv = sample15_uv - 3.0 * dx;
    const float2 sample13_uv = sample15_uv - 2.0 * dx;
    const float2 sample14_uv = sample15_uv - dx;
    //  Load each sample:
    float3 sample0 = tex2D_linearize(tex, sample0_uv).rgb;
    float3 sample1 = tex2D_linearize(tex, sample1_uv).rgb;
    float3 sample2 = tex2D_linearize(tex, dx).rgb;
    float3 sample3 = tex2D_linearize(tex, sample3_uv).rgb;
    float3 sample4 = tex2D_linearize(tex, sample4_uv).rgb;
    float3 sample5 = tex2D_linearize(tex, sample5_uv).rgb;
    float3 sample6 = tex2D_linearize(tex, sample6_uv).rgb;
    float3 sample7 = tex2D_linearize(tex, sample7_uv).rgb;
    float3 sample8 = tex2D_linearize(tex, sample8_uv).rgb;
    float3 sample9 = tex2D_linearize(tex, sample9_uv).rgb;
    float3 sample10 = tex2D_linearize(tex, sample10_uv).rgb;
    float3 sample11 = tex2D_linearize(tex, sample11_uv).rgb;
    float3 sample12 = tex2D_linearize(tex, sample12_uv).rgb;
    float3 sample13 = tex2D_linearize(tex, sample13_uv).rgb;
    float3 sample14 = tex2D_linearize(tex, sample14_uv).rgb;
    float3 sample15 = tex2D_linearize(tex, sample15_uv).rgb;
    //  Compute destination pixel offsets for each sample:
    const float2 dest_pixel = tex_uv * tex_uv_to_pixel_scale;
    const float2 sample0_offset = sample0_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample1_offset = sample1_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample2_offset = sample2_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample3_offset = sample3_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample4_offset = sample4_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample5_offset = sample5_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample6_offset = sample6_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample7_offset = sample7_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample8_offset = sample8_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample9_offset = sample9_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample10_offset = sample10_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample11_offset = sample11_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample12_offset = sample12_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample13_offset = sample13_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample14_offset = sample14_uv * tex_uv_to_pixel_scale - dest_pixel;
    const float2 sample15_offset = sample15_uv * tex_uv_to_pixel_scale - dest_pixel;
    //  Compute Gaussian sample weights:
    const float w0 = exp(-LENGTH_SQ(sample0_offset) * denom_inv);
    const float w1 = exp(-LENGTH_SQ(sample1_offset) * denom_inv);
    const float w2 = exp(-LENGTH_SQ(sample2_offset) * denom_inv);
    const float w3 = exp(-LENGTH_SQ(sample3_offset) * denom_inv);
    const float w4 = exp(-LENGTH_SQ(sample4_offset) * denom_inv);
    const float w5 = exp(-LENGTH_SQ(sample5_offset) * denom_inv);
    const float w6 = exp(-LENGTH_SQ(sample6_offset) * denom_inv);
    const float w7 = exp(-LENGTH_SQ(sample7_offset) * denom_inv);
    const float w8 = exp(-LENGTH_SQ(sample8_offset) * denom_inv);
    const float w9 = exp(-LENGTH_SQ(sample9_offset) * denom_inv);
    const float w10 = exp(-LENGTH_SQ(sample10_offset) * denom_inv);
    const float w11 = exp(-LENGTH_SQ(sample11_offset) * denom_inv);
    const float w12 = exp(-LENGTH_SQ(sample12_offset) * denom_inv);
    const float w13 = exp(-LENGTH_SQ(sample13_offset) * denom_inv);
    const float w14 = exp(-LENGTH_SQ(sample14_offset) * denom_inv);
    const float w15 = exp(-LENGTH_SQ(sample15_offset) * denom_inv);
    const float weight_sum_inv = 1.0/(
        w0 + w1 + w2 + w3 + w4 + w5 + w6 + w7 +
        w8 +w9 + w10 + w11 + w12 + w13 + w14 + w15);
    //  Weight and sum the samples:
    const float3 sum = w0 * sample0 + w1 * sample1 + w2 * sample2 + w3 * sample3 +
        w4 * sample4 + w5 * sample5 + w6 * sample6 + w7 * sample7 +
        w8 * sample8 + w9 * sample9 + w10 * sample10 + w11 * sample11 +
        w12 * sample12 + w13 * sample13 + w14 * sample14 + w15 * sample15;
    return sum * weight_sum_inv;
}

void main()
{
    //  Would a viewport-relative size work better for this pass?  (No.)
    //  PROS:
    //  1.) Instead of writing an absolute size to user-cgp-constants.h, we'd
    //      write a viewport scale.  That number could be used to directly scale
    //      the viewport-resolution bloom sigma and/or triad size to a smaller
    //      scale.  This way, we could calculate an optimal dynamic sigma no
    //      matter how the dot pitch is specified.
    //  CONS:
    //  1.) Texel smearing would be much worse at small viewport sizes, but
    //      performance would be much worse at large viewport sizes, so there
    //      would be no easy way to calculate a decent scale.
    //  2.) Worse, we could no longer get away with using a constant-size blur!
    //      Instead, we'd have to face all the same difficulties as the real
    //      phosphor bloom, which requires static #ifdefs to decide the blur
    //      size based on the expected triad size...a dynamic value.
    //  3.) Like the phosphor bloom, we'd have less control over making the blur
    //      size correct for an optical blur.  That said, we likely overblur (to
    //      maintain brightness) more than the eye would do by itself: 20/20
    //      human vision distinguishes ~1 arc minute, or 1/60 of a degree.  The
    //      highest viewing angle recommendation I know of is THX's 40.04 degree
    //      recommendation, at which 20/20 vision can distinguish about 2402.4
    //      lines.  Assuming the "TV lines" definition, that means 1201.2
    //      distinct light lines and 1201.2 distinct dark lines can be told
    //      apart, i.e. 1201.2 pairs of lines.  This would correspond to 1201.2
    //      pairs of alternating lit/unlit phosphors, so 2402.4 phosphors total
    //      (if they're alternately lit).  That's a max of 800.8 triads.  Using
    //      a more popular 30 degree viewing angle recommendation, 20/20 vision
    //      can distinguish 1800 lines, or 600 triads of alternately lit
    //      phosphors.  In contrast, we currently blur phosphors all the way
    //      down to 341.3 triads to ensure full brightness.
    //  4.) Realistically speaking, we're usually just going to use bilinear
    //      filtering in this pass anyway, but it only works well to limit
    //      bandwidth if it's done at a small constant scale.
    
    //  Get the constants we need to sample:
//    const sampler2D texture = ORIG_LINEARIZED.texture;
//    const float2 tex_uv = tex_uv;
//    const float2 blur_dxdy = blur_dxdy;
    const float2 texture_size_ = ORIG_LINEARIZEDtexture_size;
//    const float2 texture_size_inv = texture_size_inv;
//    const float2 tex_uv_to_pixel_scale = tex_uv_to_pixel_scale;
    float2 tex_uv_r, tex_uv_g, tex_uv_b;

    if(beam_misconvergence)
    {
        const float2 uv_scanline_step = uv_scanline_step;
        const float2 convergence_offsets_r = get_convergence_offsets_r_vector();
        const float2 convergence_offsets_g = get_convergence_offsets_g_vector();
        const float2 convergence_offsets_b = get_convergence_offsets_b_vector();
        tex_uv_r = tex_uv - convergence_offsets_r * uv_scanline_step;
        tex_uv_g = tex_uv - convergence_offsets_g * uv_scanline_step;
        tex_uv_b = tex_uv - convergence_offsets_b * uv_scanline_step;
    }
    //  Get the blur sigma:
    const float bloom_approx_sigma = get_bloom_approx_sigma(output_size.x,
        estimated_viewport_size_x);

    //  Sample the resized and blurred texture, and apply convergence offsets if
    //  necessary.  Applying convergence offsets here triples our samples from
    //  16/9/1 to 48/27/3, but faster and easier than sampling BLOOM_APPROX and
    //  HALATION_BLUR 3 times at full resolution every time they're used.
    float3 color_r, color_g, color_b, color;
    if(bloom_approx_filter > 1.5)
    {
        //  Use a 4x4 Gaussian resize.  This is slower but technically correct.
        if(beam_misconvergence)
        {
            color_r = tex2Dresize_gaussian4x4(ORIG_LINEARIZED, tex_uv_r,
                blur_dxdy, texture_size_, texture_size_inv,
                tex_uv_to_pixel_scale, bloom_approx_sigma);
            color_g = tex2Dresize_gaussian4x4(ORIG_LINEARIZED, tex_uv_g,
                blur_dxdy, texture_size_, texture_size_inv,
                tex_uv_to_pixel_scale, bloom_approx_sigma);
            color_b = tex2Dresize_gaussian4x4(ORIG_LINEARIZED, tex_uv_b,
                blur_dxdy, texture_size_, texture_size_inv,
                tex_uv_to_pixel_scale, bloom_approx_sigma);
        }
        else
        {
            color = tex2Dresize_gaussian4x4(ORIG_LINEARIZED, tex_uv,
                blur_dxdy, texture_size_, texture_size_inv,
                tex_uv_to_pixel_scale, bloom_approx_sigma);
        }
    }
    else if(bloom_approx_filter > 0.5)
    {
        //  Use a 3x3 resize blur.  This is the softest option, because we're
        //  blurring already blurry bilinear samples.  It doesn't play quite as
        //  nicely with convergence offsets, but it has its charms.
        if(beam_misconvergence)
        {
            color_r = tex2Dblur3x3resize(ORIG_LINEARIZED, tex_uv_r,
                blur_dxdy, bloom_approx_sigma);
            color_g = tex2Dblur3x3resize(ORIG_LINEARIZED, tex_uv_g,
                blur_dxdy, bloom_approx_sigma);
            color_b = tex2Dblur3x3resize(ORIG_LINEARIZED, tex_uv_b,
                blur_dxdy, bloom_approx_sigma);
        }
        else
        {
            color = tex2Dblur3x3resize(ORIG_LINEARIZED, tex_uv, blur_dxdy);
        }
    }
    else
    {
        //  Use bilinear sampling.  This approximates a 4x4 Gaussian resize MUCH
        //  better than tex2Dblur3x3_resize for the very small sigmas we're
        //  likely to use at small output resolutions.  (This estimate becomes
        //  too sharp above ~400x300, but the blurs break down above that
        //  resolution too, unless min_allowed_viewport_triads is high enough to
        //  keep bloom_approx_scale_x/min_allowed_viewport_triads < ~1.1658025.)
        if(beam_misconvergence)
        {
            color_r = tex2D_linearize(ORIG_LINEARIZED, tex_uv_r).rgb;
            color_g = tex2D_linearize(ORIG_LINEARIZED, tex_uv_g).rgb;
            color_b = tex2D_linearize(ORIG_LINEARIZED, tex_uv_b).rgb;
        }
        else
        {
            color = tex2D_linearize(ORIG_LINEARIZED, tex_uv).rgb;
        }
    }
    //  Pack the colors from the red/green/blue beams into a single vector:
    if(beam_misconvergence)
    {
        color = float3(color_r.r, color_g.g, color_b.b);
    }
    //  Encode and output the blurred image:
    FragColor = vec4(color, 1.0);
} 
#endif
