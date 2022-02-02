/*/////////////////////////////////////////

    ReshadeLib for Unity
    Developer               : Heisenberg
    Backup Developer        : Cyclone
    License                 : Not Decided Yet (Private Project)

    ReshadeFX
    Developer               : Patrick Mours
    License                 : https://github.com/crosire/reshade#license

/*/////////////////////////////////////////*/

#pragma once
static char* BaseURFXHeader = R"()";
static char* FlipYScreenShader = R"(
// Default Screen Flipping Texture Shader
SamplerState ScreenSampler { Filter = TEXT_1BIT; AddressU = Clamp; AddressV = Clamp; };
Texture2D<float4> texture_input : register(t0);
void VS_MAIN(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}
float4 PS_MAIN(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_TARGET
{
	texcoord.y = 1.0f - texcoord.y;
	return texture_input.Sample(ScreenSampler, texcoord);
}
)";

