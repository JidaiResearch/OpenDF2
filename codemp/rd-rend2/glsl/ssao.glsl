/*[Vertex]*/
in vec4 attr_Position;
in vec4 attr_TexCoord0;

out vec2 var_ScreenTex;

void main()
{
	gl_Position = attr_Position;
	var_ScreenTex = attr_TexCoord0.xy;
	//vec2 screenCoords = gl_Position.xy / gl_Position.w;
	//var_ScreenTex = screenCoords * 0.5 + 0.5;
}

/*[Fragment]*/
uniform sampler2D u_ScreenDepthMap;
uniform vec4 u_ViewInfo; // zfar / znear, zfar

in vec2 var_ScreenTex;

out vec4 out_Color;

vec2 poissonDisc[9] = vec2[9](
vec2(-0.7055767, 0.196515),    vec2(0.3524343, -0.7791386),
vec2(0.2391056, 0.9189604),    vec2(-0.07580382, -0.09224417),
vec2(0.5784913, -0.002528916), vec2(0.192888, 0.4064181),
vec2(-0.6335801, -0.5247476),  vec2(-0.5579782, 0.7491854),
vec2(0.7320465, 0.6317794)
);

//from https://github.com/OpenGLInsights/OpenGLInsightsCode/blob/master/Chapter%2015%20Depth%20of%20Field%20with%20Bokeh%20Rendering/src/glf/ssao.cpp
const vec2 halton[32] = vec2[32](
	vec2(-0.353553, 0.612372),
	vec2(-0.25, -0.433013),
	vec2(0.663414, 0.55667),
	vec2(-0.332232, 0.120922),
	vec2(0.137281, -0.778559),
	vec2(0.106337, 0.603069),
	vec2(-0.879002, -0.319931),
	vec2(0.191511, -0.160697),
	vec2(0.729784, 0.172962),
	vec2(-0.383621, 0.406614),
	vec2(-0.258521, -0.86352),
	vec2(0.258577, 0.34733),
	vec2(-0.82355, 0.0962588),
	vec2(0.261982, -0.607343),
	vec2(-0.0562987, 0.966608),
	vec2(-0.147695, -0.0971404),
	vec2(0.651341, -0.327115),
	vec2(0.47392, 0.238012),
	vec2(-0.738474, 0.485702),
	vec2(-0.0229837, -0.394616),
	vec2(0.320861, 0.74384),
	vec2(-0.633068, -0.0739953),
	vec2(0.568478, -0.763598),
	vec2(-0.0878153, 0.293323),
	vec2(-0.528785, -0.560479),
	vec2(0.570498, -0.13521),
	vec2(0.915797, 0.0711813),
	vec2(-0.264538, 0.385706),
	vec2(-0.365725, -0.76485),
	vec2(0.488794, 0.479406),
	vec2(-0.948199, 0.263949),
	vec2(0.0311802, -0.121049)
);

// Input: It uses texture coords as the random number seed.
// Output: Random number: [0,1), that is between 0.0 and 0.999999... inclusive.
// Author: Michael Pohoreski
// Copyright: Copyleft 2012 :-)
// Source: http://stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader

float random( const vec2 p )
{
  // We need irrationals for pseudo randomness.
  // Most (all?) known transcendental numbers will (generally) work.
  const vec2 r = vec2(
    23.1406926327792690,  // e^pi (Gelfond's constant)
     2.6651441426902251); // 2^sqrt(2) (Gelfond-Schneider constant)
  //return fract( cos( mod( 123456789., 1e-7 + 256. * dot(p,r) ) ) );
  return mod( 123456789., 1e-7 + 256. * dot(p,r) );  
}

mat2 randomRotation( const vec2 p )
{
	float r = random(p);
	float sinr = sin(r);
	float cosr = cos(r);
	return mat2(cosr, sinr, -sinr, cosr);
}

float getLinearDepth(sampler2D depthMap, const vec2 tex, const float zFarDivZNear)
{
		float sampleZDivW = texture(depthMap, tex).r;
		return 1.0 / mix(zFarDivZNear, 1.0, sampleZDivW);
}

float ambientOcclusion(sampler2D depthMap, const vec2 tex, const float zFarDivZNear, const float zFar)
{
	float result = 0;

	float sampleZ = zFar * getLinearDepth(depthMap, tex, zFarDivZNear);

	vec2 expectedSlope = vec2(dFdx(sampleZ), dFdy(sampleZ)) / vec2(dFdx(tex.x), dFdy(tex.y));
	
	if (length(expectedSlope) > 5000.0)
		return 1.0;
	
	vec2 offsetScale = vec2(15.0 / sampleZ);
	
	mat2 rmat = randomRotation(tex);
		
	/*int i;
	for (i = 0; i < 9; i++)
	{
		vec2 offset = rmat * poissonDisc[i] * offsetScale;
		float sampleZ2 = zFar * getLinearDepth(depthMap, tex + offset, zFarDivZNear);

		if (abs(sampleZ - sampleZ2) > 20.0)
			result += 1.0;
		else
		{
			float expectedZ = sampleZ + dot(expectedSlope, offset);
			result += step(expectedZ - 1.0, sampleZ2);
		}
	}*/

	int i;
	for (i = 0; i < 32; i++)
	{
		vec2 offset = rmat * halton[i] * offsetScale;
		float sampleZ2 = zFar * getLinearDepth(depthMap, tex + offset, zFarDivZNear);

		if (abs(sampleZ - sampleZ2) > 20.0)
			result += 1.0;
		else
		{
			float expectedZ = sampleZ + dot(expectedSlope, offset);
			result += step(expectedZ - 1.0, sampleZ2);
		}
	}
	
	result *= 0.03125;
	
	return result;
}

void main()
{
	float result = ambientOcclusion(u_ScreenDepthMap, var_ScreenTex, u_ViewInfo.x, u_ViewInfo.y);
			
	out_Color = vec4(vec3(result), 1.0);
}
