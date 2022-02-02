/*/////////////////////////////////////////

    ReshadeLib for Unity
    Developer               : Heisenberg
    Backup Developer        : Cyclone
    License                 : Not Decided Yet (Private Project)
    
    ReshadeFX 
    Developer               : Patrick Mours
    License                 : https://github.com/crosire/reshade#license

/*/////////////////////////////////////////*/

// Windows/Runtime SDK
#define NOMINMAX
#define _CRT_SECURE_NO_WARNINGS
#include <Windows.h>
#include <iostream>
#include <fstream>
#include <string>
#include <unordered_map>
#include <random>
#include <chrono>

// DirectX11 SDK
#include <d3d11_1.h>
#include <d3dcompiler.h>
#include <d3d11sdklayers.h>
#include <DirectX11/D3DX11tex.h>

// Unity SDK
#include <Unity/IUnityInterface.h>
#include <Unity/IUnityGraphics.h>
#include <Unity/IUnityGraphicsD3D11.h>

// ReshadeFX SDK
#include <Reshade/effect_parser.hpp>
#include <Reshade/effect_codegen.hpp>
#include <Reshade/effect_preprocessor.hpp>

// Unity ReshadeFX
#include "rlib-comptr.hpp"
#include "rlib-include.h"
#include "rlib-resources.h"
#include "rlib-objects.h"

// Namespaces
using namespace std;

// Global Buffers
char TextBuffer[512]; HRESULT res;

// Pre Processor Configs
#define RTVS_COUNT 8
#define SMPS_COUNT D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT
#define SRVS_COUNT D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT
#define DEFAULT_COLOR_BUFFER_FORMAT DXGI_FORMAT_R16G16B16A16_FLOAT
#define DEFAULT_DEPTH_BUFFER_FORMAT DXGI_FORMAT_R32G32B32A32_FLOAT

// Macros
#define SET_LOG_COLOR           SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), 0x03);
#define SET_LOG_DEFAULT         SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), 0x08);
#define cstr const char*
#define ptr void*
#define spmi ShaderParameterInfo*
#define log(fmt,...) {SET_LOG_COLOR; printf("[ %s ] " fmt "\n", GetFormattedTime(), __VA_ARGS__); SET_LOG_DEFAULT;}
#define _DLL_EXPORT extern "C" _declspec(dllexport) 
#define RESHADE_VERSION to_string(4 * 10000 + 9 * 100 + 1)
#define StrDatabase unordered_map<string, string>
#define ComDatabase(key,obj) unordered_map<key, com_ptr<obj>>
#define PtrDatabase(key,obj) unordered_map<key, obj*>
#define ResetObject(obj) if (obj) { obj->Release(); obj = NULL; }
#define ResetComObject(obj) obj.reset();
#define ReleaseDatabase(db) { for (const auto& element : db) element.second->Release(); }
#define ResetComDatabase(db) for (const auto& element : db) { auto _comobj = element.second; _comobj.reset(); }
#define ResetPtrDatabase(db) for (const auto& element : db) { delete element.second;}
#define ReleaseDatabaseVector(db) { for (const auto& element : db) element->Release(); }
#define ResetFixedHolders(hldr,cnt) { for (size_t idx = 0; idx < cnt; idx++) hldr[idx] = nullptr; }
#define DX_ERROR_CHECK if (FAILED(res)) DXERROR(res, __LINE__)
#define RESET_REJECT if (_is_resetting) return true;
#define ShaderDataType(t) reshadefx::type::datatype::t
#define HighresClockDuration std::chrono::high_resolution_clock::duration
#define HighresClockTimePoint std::chrono::high_resolution_clock::time_point
#define HighresClockNow std::chrono::high_resolution_clock::now()
#define ChronoDurationCastMS std::chrono::duration_cast<std::chrono::milliseconds>
#define SetAllTypeValues(i,val) param.parameter_floats[i] = param.parameter_uints[i] = param.parameter_ints[i] = val

// Remove Comment to Disable Logs
// #define log(fmt,...)

// Config Values [Make Them Local in Class?]
bool    useFlipBuffersModel     = true;                         // Flip Input/Output for Unity Compatilbi
int     shaderModel             = 50;                           // Shader Model 5.0
bool    specConstants           = false;
float   clearColor[4]           = { 0.0f, 0.0f, 0.0f, 1.0f };   // Black

// Global Objects
static IUnityInterfaces*        _UnityInterfaces                = NULL;
static IUnityGraphics*          _Graphics                       = NULL;
static UnityGfxRenderer         _RendererType                   = kUnityGfxRendererNull;

IUnityGraphicsD3D11*            _Interface     = 0;
ID3D11Device*                   _Device        = 0;
ID3D11DeviceContext*            _Context       = 0;
ID3D11Buffer*                   _VertexBuffer  = 0;
D3D11_BUFFER_DESC               _VertexBuffer_Desc;
HighresClockTimePoint           _PluginStartTimePoint;

// Vertex Data
struct VertexData
{
    float x, y, z;
    unsigned int color;
};
const int triangleCount = 2;
VertexData quadVerts[] =
{
    // Triangle 1
    { -1.0f, -1.0f, 0, 0xFFff0000 },
    { -1.0f, 1.0f,  0, 0xFF00ff00 },
    { 1.0f,  1.0f,  0, 0xFF0000ff },

    // Triangle 2
    { -1.0f, -1.0f, 0, 0xFFffff00 },
    { 1.0f,  1.0f,  0, 0xFF00ffff },
    { 1.0f, -1.0f,  0, 0xFFff00ff }
};

// Helpers
void makeLower(string& data) 
{
    std::transform(data.begin(), data.end(), data.begin(),
        [](unsigned char c) { return std::tolower(c); });
}
string getLower(string data) 
{
    std::transform(data.begin(), data.end(), data.begin(),
        [](unsigned char c) { return std::tolower(c); });
    return data;
}
string getShaderType(reshadefx::shader_type sh_t)
{
    switch (sh_t)
    {
    case reshadefx::shader_type::vs:
        return "Vertex Shader";
    case reshadefx::shader_type::ps:
        return "Pixel Shader";
    case reshadefx::shader_type::cs:
        return "Compute Shader";
    default:
        return "Unkown";
    }
}
string getShaderCompileType(reshadefx::shader_type sh_t)
{
    switch (sh_t)
    {
    case reshadefx::shader_type::vs:
        return "vs_5_0";
    case reshadefx::shader_type::ps:
        return "ps_5_0";
    case reshadefx::shader_type::cs:
        return "cs_5_0";
    default:
        return "invalid";
    }
}
HRESULT CompileHLSLShader(string shaderSource, LPCSTR sourceName, LPCSTR entryPoint, LPCSTR profile, ID3DBlob** blob)
{
    if (!sourceName || !entryPoint || !profile || !blob)
        return E_INVALIDARG;
    *blob = nullptr;
    UINT flags = D3DCOMPILE_ENABLE_STRICTNESS;
    const D3D_SHADER_MACRO defines[] =
    {
        "RESHADE_HLSL", "1",
        NULL, NULL
    };
    ID3DBlob* shaderBlob = nullptr;
    ID3DBlob* errorBlob = nullptr;
    HRESULT hr = D3DCompile(shaderSource.data(), shaderSource.size(), sourceName,
        defines, D3D_COMPILE_STANDARD_FILE_INCLUDE,
        entryPoint, profile, flags, 0, &shaderBlob, &errorBlob);
    if (FAILED(hr))
    {
        if (errorBlob)
        {
            MessageBoxA(0, (char*)errorBlob->GetBufferPointer(), "Shader Compiler Error", MB_ICONSTOP);
            errorBlob->Release();
        }
        if (shaderBlob)
            shaderBlob->Release();
        return hr;
    }
    *blob = shaderBlob;
    return hr;
}
void DXERROR(HRESULT res, int line = 0)
{
    sprintf_s(TextBuffer, sizeof TextBuffer, "DirectX Error at line %d : 0x%08x", line, res);
    MessageBoxA(0, TextBuffer, "DX ERROR", MB_ICONERROR);
    exit(line);
}
void PrintINT(const char* fmt, int value)
{
    sprintf_s(TextBuffer, sizeof TextBuffer, fmt, value);
    MessageBoxA(0, TextBuffer, "INT PRINTER", MB_ICONINFORMATION);
}
string ReadTextFile(const char* filename) 
{
    ifstream ifs(filename);
    string content((istreambuf_iterator<char>(ifs)),
        (istreambuf_iterator<char>()));
    return content;
}
int gtoftd(struct timeval* tp, struct timezone* tzp) {
    namespace sc = std::chrono;
    sc::system_clock::duration d = sc::system_clock::now().time_since_epoch();
    sc::seconds s = sc::duration_cast<sc::seconds>(d);
    tp->tv_sec = s.count();
    tp->tv_usec = sc::duration_cast<sc::microseconds>(d - s).count();
    return 0;
}
char* GetFormattedTime() {
    static char buffer[26];

    // For Miliseconds
    int millisec;
    struct tm* tm_info;
    struct timeval tv;

    // For Time
    time_t rawtime;
    struct tm* timeinfo;

    gtoftd(&tv, NULL);

    millisec = lrint(tv.tv_usec / 1000.0);
    if (millisec >= 1000)
    {
        millisec -= 1000;
        tv.tv_sec++;
    }

    time(&rawtime);
    timeinfo = localtime(&rawtime);

    strftime(buffer, 26, "%Y:%m:%d %H:%M:%S", timeinfo);
    sprintf_s(buffer, 26, "%s.%03d", buffer, millisec);

    return buffer;
}

// Special Parameters Tools
void GetDateFloat4(float* float4)
{
    const std::time_t t = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
    tm tm; localtime_s(&tm, &t);

    float4[0] = tm.tm_year + 1900;
    float4[1] = tm.tm_mon + 1;
    float4[2] = tm.tm_mday;
    float4[3] = tm.tm_hour * 3600 + tm.tm_min * 60 + tm.tm_sec;
    float4[4] = tm.tm_sec;
}
void GetPingPongValue(float min, float max, float step_min, float step_max, float smoothing, float* float2, long long frame_duration)
{
    float increment = step_max == 0 ? step_min : (step_min + std::fmodf(static_cast<float>(std::rand()), step_max - step_min + 1));
    float value[2] = { float2[0], float2[1] };

    if (value[1] >= 0)
    {
        increment = std::max(increment - std::max(0.0f, smoothing - (max - value[0])), 0.05f);
        increment *= frame_duration * 1e-9f;
        if ((value[0] += increment) >= max) value[0] = max, value[1] = -1;
    }
    else
    {
        increment = std::max(increment - std::max(0.0f, smoothing - (value[0] - min)), 0.05f);
        increment *= frame_duration * 1e-9f;
        if ((value[0] -= increment) <= min) value[0] = min, value[1] = +1;
    }

    float2[0] = value[0];
    float2[1] = value[1];
}
int GetRandomNumber(int min, int max)
{
    return min + (std::rand() % (std::abs(max - min) + 1));
}

// Custom Types
typedef int ShaderID;
typedef enum ReshadeParamterType
{
    rlib_bool_t = 0,
    rlib_float_t = 1,
    rlib_int_t = 3,
    rlib_uint_t = 4
} rlib_t;
struct PreprocessorMacro
{
    const char* id;
    int value = 0;
};
struct Macro
{
    string macro_id;
    string macro_val;
};
struct RenderMetadata
{
    ID3D11Resource*             in;
    ID3D11Resource*             in_depth;
    ID3D11Resource*             out;
    ID3D11VertexShader*         vs;
    ID3D11PixelShader*          ps;
    ID3D11InputLayout*          il;
    reshadefx::pass_info*       pass;
    int                         pass_index;
};
struct ParameterValue
{
    float       parameter_floats[16]    = {0};
    int32_t     parameter_ints[16]      = {0};
    uint32_t    parameter_uints[16]     = {0};
    uint8_t     parameter_type          = 0;
};
struct ShaderParameter
{
    uint32_t    parameter_offset        = 0;
    string      parameter_name          = "null";
    string      parameter_string        = "";
    float       parameter_floats[16]    = {0};
    int32_t     parameter_ints[16]      = {0};
    uint32_t    parameter_uints[16]     = {0};
    rlib_t      parameter_type          ;
    uint16_t    parameter_size          = 0;
    BOOL        parameter_is_special    = 0;
    uint32_t    parameter_index         = 0;
};
struct ShaderParameterInfo
{
    LPSTR       parameter_name          = "null";
    float       parameter_floats[16]    = {};
    int32_t     parameter_ints[16]      = {};
    uint32_t    parameter_uints[16]     = {};
    rlib_t      parameter_type          = rlib_t::rlib_bool_t;
    uint16_t    parameter_count         = 0;
};

// Defaults
ShaderParameterInfo spmi_default;

// Effect Object
class ReshadeEffect
{
public:
    // Basic Methods
    ReshadeEffect(cstr shaderCode, PreprocessorMacro* ppMacros, int macroCount)
    {
        _shaderCode = new string(shaderCode);
        _macros.resize(macroCount);
        for (size_t i = 0; i < macroCount; i++)
        {
            _macros[i].macro_id = string(ppMacros[i].id);
            _macros[i].macro_val = to_string(ppMacros[i].value);
        }

        // Generate UID
        random_device dev; mt19937 rng(dev());
        uniform_int_distribution<mt19937::result_type> dist(111111, 999999); 
        _id = dist(rng);
    }
    ~ReshadeEffect() {}
    void SetState(bool state) { _disabled = state; }
    void SetTime(UINT frameCount, float frameLong) { _frame_count = frameCount; /*_frame_time = frameLong;*/ }
    ShaderID GetID() { return _id; }
    bool IsInitialized() { return _initialized; }

    // Methods
    bool Initialize();
    bool CreateEffect();
    bool UpdateBufferSize(int _w, int _h);
    bool Reset();
    bool RenderEffect(ID3D11Resource* in, ID3D11Resource* in_depth, ID3D11Resource* out);
    bool RenderPass(RenderMetadata& renderMeta);
    bool RebuildParameters();
    int  GetParameterNum() { return _parameters.size(); }
    spmi GetParameters(int index);
    bool SetParameters(int index, cstr parameterData);
    bool Destroy();

private:

    // Properties
    UINT _frame_count                                       = 0;
    float _frame_time                                       = 0;
    bool _initialized                                       = false;
    bool _is_compiled                                       = false;
    bool _is_destorying                                     = false;
    bool _is_resetting                                      = false;
    bool _disabled                                          = false;
    bool _auto_parameter_update                             = true;
    ShaderID _id                                            = 0;
    string* _shaderCode                                     = 0;
    int bufferWidth                                         = 0;
    int bufferHeight                                        = 0;

    // Basic Objects
    int vertSize                                            = 0;
    int rtvOffsetID                                         = 0;
    UINT vpCount                                            = 1;
    UINT stride                                             = 0;
    UINT offset                                             = 0;
    int colorBufferOffset                                   = 0;
    int depthBufferOffset                                   = 0;
    int parameterCount                                      = 0;

    // Dirty Flags
    bool needSizeUpdate                                     = false;
    bool needBackupBufferSizeUpdate                         = false;
    bool needParametersCreation                             = false;
    bool needParametersUpdate                               = false;
    bool hasParameters                                      = false;

    // Reshade Objects
    reshadefx::parser*                                      parser;
    reshadefx::preprocessor*                                pp;
    reshadefx::module*                                      module;
    unique_ptr<reshadefx::codegen>                          backend;

    // Reshade Shader Data
    vector<reshadefx::pass_info>                            _passes;
    vector<reshadefx::uniform_info>                         _uniforms;

    ID3D11RenderTargetView*                                 _rtvs[RTVS_COUNT];
    vector<ID3D11SamplerState*>                             _smps;
    ID3D11ShaderResourceView*                               _texViews[SRVS_COUNT];
    D3D11_VIEWPORT                                          _views[RTVS_COUNT];

    // Databases
    vector<Macro>                                           _macros;
    vector<ShaderParameter>                                 _parameters;
    ComDatabase(string, ID3D11Texture2D)                    _textures;
    ComDatabase(string, ID3D11RenderTargetView)             _renderTargets;
    ComDatabase(string, ID3D11ShaderResourceView)           _shaderViews;
    ComDatabase(string, ID3D11SamplerState)                 _samplers;
    ComDatabase(string, ID3D11UnorderedAccessView)          _storageViews;
    ComDatabase(string, ID3D11VertexShader)                 _vertexShaders;
    ComDatabase(string, ID3D11InputLayout)                  _inputLayouts;
    ComDatabase(string, ID3D11PixelShader)                  _pixelShaders;
    PtrDatabase(string, D3D11_VIEWPORT)                     _viewports;

    // DirectX Objects
    com_ptr<ID3D11Buffer>                                   uniformBuffer;
    com_ptr<ID3D11Texture2D>                                outputTex;
    com_ptr<ID3D11RenderTargetView>                         outputRTV;
    com_ptr<ID3D11ShaderResourceView>                       outputSRV;
    com_ptr<ID3D11Texture2D>                                outputDepthTex;
    com_ptr<ID3D11RenderTargetView>                         outputDepthRTV;
    com_ptr<ID3D11RenderTargetView>                         finalRTV;
    com_ptr<ID3D11Texture2D>                                colorBufferTex;
    com_ptr<ID3D11Texture2D>                                depthBufferTex;
    com_ptr<ID3D11Texture2D>                                depthBufferTexPre;
    com_ptr<ID3D11ShaderResourceView>                       colorBuffer;
    com_ptr<ID3D11ShaderResourceView>                       depthBuffer;
    com_ptr<ID3D11ShaderResourceView>                       depthBufferPre;
    com_ptr<ID3D11VertexShader>                             bufferFlipperVS;
    com_ptr<ID3D11PixelShader>                              bufferFlipperPS;

    // DirectX Descriptors
    D3D11_VIEWPORT                                          defaultVP               = {};
    D3D11_TEXTURE2D_DESC                                    t2d_desc                = {};
    D3D11_RENDER_TARGET_VIEW_DESC                           rtv_desc                = {};
    D3D11_SHADER_RESOURCE_VIEW_DESC                         srv_desc                = {};
    D3D11_RESOURCE_DIMENSION                                res_desc                = {};
    D3D11_SAMPLER_DESC                                      smp_desc                = {};

    // Timers & Performancers
    HighresClockDuration                                    frame_duration;
    HighresClockTimePoint                                   frame_start;
    HighresClockTimePoint                                   frame_end;

    // Singleton Objects
    ShaderParameterInfo                                     shaderParamInfo;
};

// Effect Object :: Methods
bool ReshadeEffect::Initialize() 
{ 
    log("Initializing Shader %d...", _id);

    ZeroMemory(&t2d_desc, sizeof(t2d_desc));
    t2d_desc.Width = this->bufferWidth;
    t2d_desc.Height = this->bufferHeight;
    t2d_desc.MipLevels = 1;
    t2d_desc.ArraySize = 1;
    t2d_desc.Format = DEFAULT_COLOR_BUFFER_FORMAT;
    t2d_desc.SampleDesc.Count = 1;
    t2d_desc.Usage = D3D11_USAGE_DEFAULT;
    t2d_desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
    t2d_desc.CPUAccessFlags = 0;
    t2d_desc.MiscFlags = 0;

    // Initialized!
    _initialized = true;
    return _initialized;
}
bool ReshadeEffect::CreateEffect()
{
    log("Compiling Shader %d...", _id);

    // Create Parser & PreProcessor
    parser = new reshadefx::parser();
    pp = new reshadefx::preprocessor();
    module = new reshadefx::module();

    // Add Macros
    pp->add_macro_definition("__RESHADE__", RESHADE_VERSION);
    pp->add_macro_definition("__RESHADE_PERFORMANCE_MODE__", "0");
    pp->add_macro_definition("RESHADE_DEPTH_LINEARIZATION_FAR_PLANE", "1000");
    pp->add_macro_definition("BUFFER_WIDTH", to_string(bufferWidth).c_str());
    pp->add_macro_definition("BUFFER_HEIGHT", to_string(bufferHeight).c_str());
    pp->add_macro_definition("BUFFER_RCP_WIDTH", "(1.0 / BUFFER_WIDTH)");
    pp->add_macro_definition("BUFFER_RCP_HEIGHT", "(1.0 / BUFFER_HEIGHT)");
    for (size_t i = 0; i < _macros.size(); i++) pp->add_macro_definition(_macros[i].macro_id, _macros[i].macro_val);

    // Add Includes (This Makes Random VC++ Runtime Error)
    // pp->add_include_path(".\\Include"); 

    // Create Default Viewport
    defaultVP = { 0.0f, 0.0f, (FLOAT)bufferWidth,(FLOAT)bufferHeight, 0.0f, 1.0f };

    // Parse & Compile Reshade Shader
    if (!pp->append_string(*_shaderCode))
    {
        cout << "Pre Processor Error : " << pp->errors() << endl;
        return false;
    }
    backend.reset(reshadefx::create_codegen_hlsl(shaderModel, false, specConstants));
    if (!parser->parse(pp->output(), backend.get()))
    {
        cout << "Parser Error : " << parser->errors() << endl;
        return false;
    }
    backend->write_result(*module);

    // Create Layout Description
    D3D11_INPUT_ELEMENT_DESC DefaultInputElements[] =
    {
        { "POSITION",   0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0,  D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",      0, DXGI_FORMAT_R8G8B8A8_UNORM,  0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "DIFFUSE",    0, DXGI_FORMAT_R8G8B8A8_UNORM,  0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };

    // Compile & Create DirectX 11 Shaders
    for (int i = 0; i < module->entry_points.size(); i++)
    {
        log("Compiling Entrypoint `%s` (%s) ...",
            module->entry_points[i].name.c_str(), getShaderType(module->entry_points[i].type).c_str());

        ID3DBlob* shaderBlob = nullptr;
        res = CompileHLSLShader(module->hlsl, "ReshadeFX-HLSL", module->entry_points[i].name.c_str(), 
            getShaderCompileType(module->entry_points[i].type).c_str(), &shaderBlob); DX_ERROR_CHECK;

        // Create Shaders & Add to Database
        switch (module->entry_points[i].type)
        {
        case reshadefx::shader_type::vs:
            ID3D11VertexShader* vs;
            ID3D11InputLayout* il;
            res = _Device->CreateVertexShader(shaderBlob->GetBufferPointer(), shaderBlob->GetBufferSize(), nullptr, &vs); DX_ERROR_CHECK;
            this->_vertexShaders.insert({ module->entry_points[i].name , vs });
            res = _Device->CreateInputLayout(DefaultInputElements, _countof(DefaultInputElements), shaderBlob->GetBufferPointer(), shaderBlob->GetBufferSize(), &il);
            if (FAILED(res)) log("DX Error : Input Layout for vertex shader [%s] failed to create, Set to Null.", module->entry_points[i].name.c_str());
            this->_inputLayouts.insert({ module->entry_points[i].name , il });
            break;
        case reshadefx::shader_type::ps:
            ID3D11PixelShader* ps;
            res = _Device->CreatePixelShader(shaderBlob->GetBufferPointer(), shaderBlob->GetBufferSize(), nullptr, &ps); DX_ERROR_CHECK;
            this->_pixelShaders.insert({ module->entry_points[i].name , ps });
            break;
        case reshadefx::shader_type::cs:
            ID3D11ComputeShader* cs;
            res = _Device->CreateComputeShader(shaderBlob->GetBufferPointer(), shaderBlob->GetBufferSize(), nullptr, &cs); DX_ERROR_CHECK;
            // this->_computeShaders.insert({ module->entry_points[i].name , cs });
            break;
        }

        // Clean Up
        shaderBlob->Release();
    }

    // Add & Collect Passes
    if (module->techniques.size() == 1)
    {
        auto tech = module->techniques[0];
        auto passes = tech.passes;
        for (int p = 0; p < passes.size(); p++)
        {
            _passes.push_back(passes[p]);
        }
    }

    // Add & Collect Uniforms
    for (int p = 0; p < module->uniforms.size(); p++) _uniforms.push_back(module->uniforms[p]);

    // Initialize Objects
    if (!this->Initialize()) return false;

    // Create Resources
    for (const reshadefx::texture_info& texture : module->textures)
    {
        // Collect Meta Data
        bool hasSource = false;
        string textureSource = "";
        for (const auto& meta : texture.annotations)
        {
            if (getLower(meta.name) == "source")
            {
                hasSource = true;
                textureSource = meta.value.string_data;
            }
        }

        // Create Textures
        if (texture.semantic == "")
        {
            D3D11_TEXTURE2D_DESC _desc = {}; D3D11_RENDER_TARGET_VIEW_DESC _rtvdesc = {};
            D3D11_SHADER_RESOURCE_VIEW_DESC _srvdesc = {}; D3DX11_IMAGE_LOAD_INFO texLoadInfo = {};
            com_ptr<ID3D11Texture2D> _tex; com_ptr<ID3D11RenderTargetView> _rtv; com_ptr<ID3D11ShaderResourceView> _srv; 

            // Create Descriptors
            _desc.Width = texture.width; _desc.Height = texture.height;
            _desc.MipLevels = 1; _desc.ArraySize = 1;
            _desc.Format = DEFAULT_COLOR_BUFFER_FORMAT;
            _desc.SampleDesc.Count = 1; _desc.Usage = D3D11_USAGE_DEFAULT;
            _desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
            _desc.CPUAccessFlags = 0; _desc.MiscFlags = 0;

            _rtvdesc.Format = _desc.Format;
            _rtvdesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
            _rtvdesc.Texture2D.MipSlice = 0;

            _srvdesc.Format = _desc.Format;
            _srvdesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
            _srvdesc.Texture2D.MipLevels = _desc.MipLevels;

            // Create Texture
            if (hasSource)
            {
                log("Loading Texture File `%s`...", textureSource.c_str());

                // Load Texture from Disk
                texLoadInfo.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
                texLoadInfo.CpuAccessFlags = 0;
                texLoadInfo.Usage = D3D11_USAGE_DEFAULT;
                texLoadInfo.MipLevels = 1; texLoadInfo.MiscFlags = 0;
                res = D3DX11CreateTextureFromFileA(
                    _Device, textureSource.c_str(), &texLoadInfo, 0, (ID3D11Resource**)&_tex, 0); 

                // Handle Missing Textures
                if (res == 0x887C0002)
                {
                    log("Texture File `%s` is Missing, It's replaced by Default Texture.", textureSource.c_str());
                    res = D3DX11CreateTextureFromMemory(
                        _Device, MissingTexturePNG, sizeof MissingTexturePNG,
                        &texLoadInfo, 0, (ID3D11Resource**)&_tex, 0); DX_ERROR_CHECK;
                }

                // Update Render Target & Shader Resource Format 
                _tex->GetDesc(&_desc);
                _rtvdesc.Format = _srvdesc.Format = _desc.Format;
                this->_textures.insert({ texture.unique_name, _tex });
            }
            else
            {
                res = _Device->CreateTexture2D(&_desc, 0, &_tex); DX_ERROR_CHECK;
                this->_textures.insert({ texture.unique_name, _tex });
            }
   
            // Create Render Target View
            res = _Device->CreateRenderTargetView(_tex.get(), &_rtvdesc, &_rtv); DX_ERROR_CHECK;
            this->_renderTargets.insert({ texture.unique_name, _rtv });

            // Create Shader Resource View
            res = _Device->CreateShaderResourceView(_tex.get(), &_srvdesc, &_srv); DX_ERROR_CHECK;
            this->_shaderViews.insert({ texture.unique_name, _srv });

            // Create Viewports
            D3D11_VIEWPORT* vp = new D3D11_VIEWPORT({ 0.0f, 0.0f, (FLOAT)texture.width,(FLOAT)texture.height, 0.0f, 1.0f });
            this->_viewports.insert({ texture.unique_name, vp });
        }
        else
        {
            if (texture.semantic == "COLOR") colorBufferOffset = texture.binding;
            if (texture.semantic == "DEPTH") depthBufferOffset = texture.binding;
        }
    }
   
    // Create Samplers
    for (const reshadefx::sampler_info& sampler : module->samplers)
    {
        com_ptr<ID3D11SamplerState> new_sampler;

        // Description
        smp_desc.Filter = static_cast<D3D11_FILTER>(sampler.filter);
        smp_desc.AddressU = static_cast<D3D11_TEXTURE_ADDRESS_MODE>(sampler.address_u);
        smp_desc.AddressV = static_cast<D3D11_TEXTURE_ADDRESS_MODE>(sampler.address_v);
        smp_desc.AddressW = static_cast<D3D11_TEXTURE_ADDRESS_MODE>(sampler.address_w);
        smp_desc.MipLODBias = sampler.lod_bias; smp_desc.MaxAnisotropy = 1;
        smp_desc.ComparisonFunc = D3D11_COMPARISON_NEVER;
        memset(smp_desc.BorderColor, 0, sizeof(smp_desc.BorderColor));
        smp_desc.MinLOD = sampler.min_lod; smp_desc.MaxLOD = sampler.max_lod;
        res = _Device->CreateSamplerState(&smp_desc, &new_sampler); DX_ERROR_CHECK;
        this->_samplers.insert({ sampler.unique_name, new_sampler });
    }

    // Create Uniform Buffer
    if (module->total_uniform_size != 0)
    {
        log("Creating Constant Buffer...");

        // Create Parameters Database
        if (needParametersCreation == false)
        {
            // Create Parameters
            for (const auto& uniform : _uniforms)
            {
                ShaderParameter param;
                param.parameter_is_special = false;

                // Search for Parameter Source
                for (const auto& paramMeta : uniform.annotations)
                {
                    if (getLower(paramMeta.name) == "source")
                    {
                        param.parameter_is_special = true;
                        param.parameter_string = paramMeta.value.string_data;
                    }
                }

                // Set Basic Parameters
                param.parameter_name = uniform.name;
                param.parameter_offset = uniform.offset;
                param.parameter_size = uniform.size;
                param.parameter_index = parameterCount;

                // Set Parameter Type
                switch (uniform.type.base)
                {
                case reshadefx::type::t_int:
                    param.parameter_type = rlib_t::rlib_int_t;
                    break;
                case reshadefx::type::t_bool:
                    param.parameter_type = rlib_t::rlib_bool_t;
                    break;
                case reshadefx::type::t_uint:
                    param.parameter_type = rlib_t::rlib_uint_t;
                    break;
                case reshadefx::type::t_float:
                    param.parameter_type = rlib_t::rlib_float_t;
                    break;
                }

                // Set Default Parameter Values
                memcpy(param.parameter_floats, uniform.initializer_value.as_float, sizeof uniform.initializer_value.as_float);
                memcpy(param.parameter_ints, uniform.initializer_value.as_int, sizeof uniform.initializer_value.as_int);
                memcpy(param.parameter_uints, uniform.initializer_value.as_uint, sizeof uniform.initializer_value.as_uint);

                _parameters.push_back(param);
                parameterCount++;
            }

            // Create Parameter Database
            needParametersCreation = true;
        }

        // Create Constant Buffer
        const D3D11_BUFFER_DESC constBufferDesc = 
        { (UINT)(module->total_uniform_size + 15) & ~15, D3D11_USAGE_DYNAMIC, D3D11_BIND_CONSTANT_BUFFER, D3D11_CPU_ACCESS_WRITE, 0, 0 };
        res = _Device->CreateBuffer(&constBufferDesc, nullptr, &uniformBuffer); DX_ERROR_CHECK;
        log("Const Buffer Created -> Size : %d | Aligned Size : %d", module->total_uniform_size, constBufferDesc.ByteWidth);

        // Use Constant Buffer
        hasParameters = true;

        // Serialize Shader Parameters
        this->RebuildParameters();
    }

    // Compile Extra Shaders
    if (useFlipBuffersModel)
    {
        ID3DBlob* extraShader = nullptr;
        res = CompileHLSLShader(FlipYScreenShader, "Xtra-Shader", "VS_MAIN", "vs_5_0", &extraShader); DX_ERROR_CHECK;
        res = _Device->CreateVertexShader(extraShader->GetBufferPointer(), extraShader->GetBufferSize(), nullptr, &bufferFlipperVS); DX_ERROR_CHECK;
        extraShader->Release();
        res = CompileHLSLShader(FlipYScreenShader, "Xtra-Shader", "PS_MAIN", "ps_5_0", &extraShader); DX_ERROR_CHECK;
        res = _Device->CreatePixelShader(extraShader->GetBufferPointer(), extraShader->GetBufferSize(), nullptr, &bufferFlipperPS); DX_ERROR_CHECK;
        extraShader->Release();
    }

    // Success
    _is_compiled = true;
    return true;
}
bool ReshadeEffect::UpdateBufferSize(int _w, int _h)
{ 
    bufferWidth = _w; 
    bufferHeight = _h; 
    defaultVP = { 0.0f, 0.0f, (FLOAT)bufferWidth,(FLOAT)bufferHeight, 0.0f, 1.0f }; 
    return true; 
}
bool ReshadeEffect::Reset()
{
    // !NOTE! :: Reset Makes Some Memory Leaks on Resize, Fix it Later

    RESET_REJECT;

    log("Resetting Shader %d...", _id);
    _is_resetting = true;

    // Clear Parser and PreProcessor
    delete parser;
    delete pp;
    delete module;

    // Clear Up Database Elements
    ResetComDatabase(_vertexShaders);
    ResetComDatabase(_pixelShaders);
    ResetComDatabase(_inputLayouts);
    ResetComDatabase(_textures);
    ResetComDatabase(_shaderViews);
    ResetComDatabase(_samplers);
    ResetComDatabase(_storageViews);
    ResetComDatabase(_renderTargets);
    ResetPtrDatabase(_viewports);

    // Clean Up Databases
    _vertexShaders.clear();
    _pixelShaders.clear();
    _inputLayouts.clear();
    _renderTargets.clear();
    _textures.clear();
    _shaderViews.clear();
    _samplers.clear();
    _storageViews.clear();
    _viewports.clear();
    _passes.clear();
    _uniforms.clear();

    // Swap Databases
    vector<reshadefx::pass_info>().swap(_passes);
    vector<reshadefx::uniform_info>().swap(_uniforms);

    // Clean Fixed Size Holders
    ResetFixedHolders(_rtvs, RTVS_COUNT);
    ResetFixedHolders(_texViews, SRVS_COUNT);
    ResetFixedHolders(_smps, _smps.size());

    // Clean Up Effect
    ResetComObject(outputTex);
    ResetComObject(outputRTV);
    ResetComObject(outputSRV);
    ResetComObject(outputDepthTex);
    ResetComObject(outputDepthRTV);
    ResetComObject(finalRTV);
    ResetComObject(colorBufferTex);
    ResetComObject(depthBufferTex);
    ResetComObject(colorBuffer);
    ResetComObject(depthBuffer);
    ResetComObject(depthBufferTexPre);
    ResetComObject(depthBufferPre);
    ResetComObject(bufferFlipperVS);
    ResetComObject(bufferFlipperPS);
    ResetComObject(uniformBuffer);

    // Update Dirty Flags
    needSizeUpdate = true;
    needBackupBufferSizeUpdate = true;
    
    // Recreate Effect
    if (!_is_destorying) { _is_compiled = false; CreateEffect(); }
    if (_is_resetting) { _is_resetting = false;}

    // Only On Exit
    if (_is_destorying) _parameters.clear();

    return true;
}
bool ReshadeEffect::RenderEffect(ID3D11Resource* in, ID3D11Resource* in_depth, ID3D11Resource* out) 
{
    if (_is_resetting || _disabled || !_is_compiled) { _Context->CopyResource(out, in); return true; }

    // Update Frame Start
    frame_start = HighresClockNow;

    // Auto Parameter Update
    if (_auto_parameter_update) this->RebuildParameters();

    // Render Effect
    if (in && in_depth && out)
    {
        // Set Geometry & Update Vertex Buffer
        vertSize = 12 + 4; stride = vertSize; offset = 0;
        _Context->UpdateSubresource(_VertexBuffer, 0, NULL, quadVerts, triangleCount * 3 * vertSize, 0);
        _Context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        _Context->IASetVertexBuffers(0, 1, &_VertexBuffer, &stride, &offset);

        in->GetType(&res_desc);
        if (res_desc == D3D11_RESOURCE_DIMENSION::D3D11_RESOURCE_DIMENSION_TEXTURE2D)
        {
            // Create Output Buffer
            if (!outputTex.get())
            {
                ((ID3D11Texture2D*)out)->GetDesc(&t2d_desc);
                t2d_desc.Width = t2d_desc.Width;
                t2d_desc.Height = t2d_desc.Height;
                t2d_desc.Format = DEFAULT_COLOR_BUFFER_FORMAT;
                res = _Device->CreateTexture2D(&t2d_desc, NULL, &outputTex);

                // Create Render Target View
                rtv_desc.Format = t2d_desc.Format;
                rtv_desc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
                rtv_desc.Texture2D.MipSlice = 0;
                srv_desc.Format = t2d_desc.Format;
                srv_desc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
                srv_desc.Texture2D.MipLevels = 1;
                if (outputTex.get())
                {
                    res = _Device->CreateRenderTargetView(outputTex.get(), &rtv_desc, &outputRTV); DX_ERROR_CHECK;
                    res = _Device->CreateShaderResourceView(outputTex.get(), &srv_desc, &outputSRV); DX_ERROR_CHECK;
                }
            }

            // Create Output Depth Buffer
            if (!outputDepthTex.get())
            {
                ((ID3D11Texture2D*)out)->GetDesc(&t2d_desc);
                t2d_desc.Width = t2d_desc.Width;
                t2d_desc.Height = t2d_desc.Height;
                t2d_desc.Format = DEFAULT_DEPTH_BUFFER_FORMAT;
                res = _Device->CreateTexture2D(&t2d_desc, NULL, &outputDepthTex);

                // Create Render Target View
                rtv_desc.Format = t2d_desc.Format;
                rtv_desc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
                rtv_desc.Texture2D.MipSlice = 0;
                if (outputDepthTex.get())
                {
                    res = _Device->CreateRenderTargetView(outputDepthTex.get(), &rtv_desc, &outputDepthRTV); DX_ERROR_CHECK;
                }
            }

            // Create Final Render View
            if (!finalRTV.get() && useFlipBuffersModel)
            {
                rtv_desc.Format = DEFAULT_COLOR_BUFFER_FORMAT;
                rtv_desc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
                rtv_desc.Texture2D.MipSlice = 0;
                res = _Device->CreateRenderTargetView(out, &rtv_desc, &finalRTV); DX_ERROR_CHECK;
            }

            // Create Color Buffer
            if (!colorBufferTex.get())
            {
                ((ID3D11Texture2D*)in)->GetDesc(&t2d_desc);
                t2d_desc.Width = t2d_desc.Width;
                t2d_desc.Height = t2d_desc.Height;
                t2d_desc.Format = DEFAULT_COLOR_BUFFER_FORMAT;
                res = _Device->CreateTexture2D(&t2d_desc, NULL, &colorBufferTex); DX_ERROR_CHECK;

                // Create Shader Resource View
                srv_desc.Format = t2d_desc.Format;
                srv_desc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
                srv_desc.Texture2D.MipLevels = 1;
                if (colorBufferTex.get())
                {
                    res = _Device->CreateShaderResourceView(colorBufferTex.get(), &srv_desc, &colorBuffer); DX_ERROR_CHECK;
                    _Context->CopyResource(colorBufferTex.get(), in);
                }
            }
            else
            {
                if (useFlipBuffersModel)
                {
                    _Context->CopyResource(colorBufferTex.get(), in);
                    _Context->OMSetRenderTargets(1, &outputRTV, NULL);
                    _Context->ClearRenderTargetView(outputRTV.get(), clearColor);
                    _Context->VSSetShader(bufferFlipperVS.get(), NULL, 0);
                    _Context->PSSetShader(bufferFlipperPS.get(), NULL, 0);
                    _Context->PSSetShaderResources(0, 1, &colorBuffer);
                    _Context->IASetInputLayout(nullptr);

                    // Draw & Render
                    _Context->Draw(triangleCount * 3, 0);
                    _Context->CopyResource(colorBufferTex.get(), outputTex.get());
                }
                else
                {
                    // Update From Unity
                    _Context->CopyResource(colorBufferTex.get(), in);
                }
            }

            // Create Depth Buffer
            if (!depthBufferTex.get())
            {
                ((ID3D11Texture2D*)in)->GetDesc(&t2d_desc);
                t2d_desc.Width = t2d_desc.Width;
                t2d_desc.Height = t2d_desc.Height;
                t2d_desc.MipLevels = 1;
                t2d_desc.Format = DEFAULT_DEPTH_BUFFER_FORMAT;
                res = _Device->CreateTexture2D(&t2d_desc, NULL, &depthBufferTex); DX_ERROR_CHECK;

                // Create Shader Resource View
                srv_desc.Format = t2d_desc.Format;
                srv_desc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
                srv_desc.Texture2D.MipLevels = t2d_desc.MipLevels;
                if (depthBufferTex.get())
                {
                    res = _Device->CreateShaderResourceView(depthBufferTex.get(), &srv_desc, &depthBuffer); DX_ERROR_CHECK;
                }
            }

            // Create Depth Buffer (Mono)
            if (!depthBufferTexPre.get())
            {
                ((ID3D11Texture2D*)in_depth)->GetDesc(&t2d_desc);
                t2d_desc.Format = DXGI_FORMAT_R32G8X24_TYPELESS;
                t2d_desc.BindFlags = D3D11_BIND_DEPTH_STENCIL | D3D11_BIND_SHADER_RESOURCE;;
                res = _Device->CreateTexture2D(&t2d_desc, NULL, &depthBufferTexPre); DX_ERROR_CHECK;

                // Create Shader Resource View
                srv_desc.Format = DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS;
                srv_desc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
                srv_desc.Texture2D.MipLevels = 1;
                if (depthBufferTexPre.get())
                {
                    res = _Device->CreateShaderResourceView(depthBufferTexPre.get(), &srv_desc, &depthBufferPre); DX_ERROR_CHECK;
                    _Context->CopyResource(depthBufferTexPre.get(), in_depth);
                }
            }
            else
            {
                if (useFlipBuffersModel)
                {
                    _Context->CopyResource(depthBufferTexPre.get(), in_depth);
                    _Context->OMSetRenderTargets(1, &outputDepthRTV, NULL);
                    _Context->ClearRenderTargetView(outputDepthRTV.get(), clearColor);
                    _Context->VSSetShader(bufferFlipperVS.get(), NULL, 0);
                    _Context->PSSetShader(bufferFlipperPS.get(), NULL, 0);
                    _Context->PSSetShaderResources(0, 1, &depthBufferPre);
                    _Context->IASetInputLayout(nullptr);

                    // Draw & Render
                    _Context->Draw(triangleCount * 3, 0);
                    if (depthBufferTex.get()) _Context->CopyResource(depthBufferTex.get(), outputDepthTex.get());
                }
                else
                {
                    // Update From Unity
                    _Context->CopyResource(depthBufferTexPre.get(), in_depth);
                }
            }

            // Render Passes
            for (size_t i = 0; i < _passes.size(); i++)
            {
                RenderMetadata rmd;
                rmd.in = in;
                rmd.in_depth = in_depth;
                rmd.out = out;
                rmd.vs = _vertexShaders[_passes[i].vs_entry_point].get();
                rmd.il = _inputLayouts[_passes[i].vs_entry_point].get();
                rmd.ps = _pixelShaders[_passes[i].ps_entry_point].get();
                rmd.pass = &_passes[i];
                rmd.pass_index = i;
                if (!this->RenderPass(rmd)) return false;
            }

            // Process Final Output & Copy to Unity Output Buffer
            if (useFlipBuffersModel)
            {
                _Context->OMSetRenderTargets(1, &finalRTV, NULL);
                _Context->ClearRenderTargetView(finalRTV.get(), clearColor);
                _Context->VSSetShader(bufferFlipperVS.get(), NULL, 0);
                _Context->PSSetShader(bufferFlipperPS.get(), NULL, 0);
                _Context->PSSetShaderResources(0, 1, &outputSRV);
                _Context->IASetInputLayout(nullptr);

                // Draw & Render
                _Context->Draw(triangleCount * 3, 0);
            }
            else
            {
                _Context->CopyResource(out, outputTex.get());
            }

            // Update Dirty Flags
            needSizeUpdate = false;
            needBackupBufferSizeUpdate = false;
        }
    }

    // Update Frame Time
    frame_end = HighresClockNow; frame_duration = frame_end - frame_start;
    _frame_time = frame_duration.count() * 1e-6f;

    // Success
    return true;
}
bool ReshadeEffect::RenderPass(RenderMetadata& renderMeta)
{
    RESET_REJECT;

    // Reset Holders
    for (size_t i = 0; i < RTVS_COUNT; i++) _rtvs[i] = nullptr;
    for (size_t i = 0; i < RTVS_COUNT; i++) _views[i] = defaultVP;
    for (size_t i = 0; i < SRVS_COUNT; i++) _texViews[i] = nullptr;
    _smps.clear(); _smps.resize(module->num_sampler_bindings);

    // Setup Render Targets
    rtvOffsetID = 0;
    for (UINT k = 0; k < RTVS_COUNT && !renderMeta.pass->render_target_names[k].empty(); ++k)
    {
        if (!renderMeta.pass->render_target_names[k].empty())
        {
            _rtvs[k] = _renderTargets[renderMeta.pass->render_target_names[k]].get();
            if (renderMeta.pass->clear_render_targets) _Context->ClearRenderTargetView(_rtvs[k], clearColor);
            _views[k] = *_viewports[renderMeta.pass->render_target_names[k]];
        }
    }

    _Context->OMSetRenderTargets(RTVS_COUNT, _rtvs, NULL);
    _Context->RSSetViewports(RTVS_COUNT, _views);

    // Default Render Target
    if (renderMeta.pass->render_target_names[0].empty())
    {
        _Context->OMSetRenderTargets(1, &outputRTV, NULL);
        if (renderMeta.pass->clear_render_targets)
        {
            _Context->ClearRenderTargetView(outputRTV.get(), clearColor);
        }
    }

    // Set Samplers
    for (const auto& _smp : module->samplers)
    {
        _smps[_smp.binding] = _samplers[_smp.unique_name].get();
    }
    _Context->VSSetSamplers(0, _smps.size(), _smps.data());
    _Context->PSSetSamplers(0, _smps.size(), _smps.data());

    // Set Shaders
    _Context->VSSetShader(renderMeta.vs, NULL, 0);
    _Context->PSSetShader(renderMeta.ps, NULL, 0);

    // Set Uniforms
    if (hasParameters)
    {
        _Context->VSSetConstantBuffers(0, 1, &uniformBuffer);
        _Context->PSSetConstantBuffers(0, 1, &uniformBuffer);
    }

    // Set Internal Textures
    _texViews[colorBufferOffset] = colorBuffer.get();
    _texViews[depthBufferOffset] = depthBuffer.get();
    if (!useFlipBuffersModel) _texViews[depthBufferOffset] = depthBufferPre.get();

    // Set Textures
    for (const auto& _tex : module->textures)
    {
        if (_tex.semantic == "")
        {
            _texViews[_tex.binding] = _shaderViews[_tex.unique_name].get();
        }
    }
    _Context->VSSetShaderResources(0, SRVS_COUNT, _texViews);
    _Context->PSSetShaderResources(0, SRVS_COUNT, _texViews);

    // Set Input Assembler Data
    _Context->IASetInputLayout(renderMeta.il);

    // Draw & Render
    _Context->Draw(triangleCount * 3, 0);

    // Reset RTV & SRV
    _Context->OMSetRenderTargets(0, nullptr, nullptr);
    ID3D11ShaderResourceView* null_srv[SRVS_COUNT] = { nullptr };
    _Context->VSSetShaderResources(0, _shaderViews.size(), null_srv);
    _Context->PSSetShaderResources(0, _shaderViews.size(), null_srv);

    return true;
}
bool ReshadeEffect::RebuildParameters() 
{
    if (!hasParameters) return false;

    // Map Buffer to CPU
    D3D11_MAPPED_SUBRESOURCE mapped;
    res = _Context->Map(uniformBuffer.get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped); DX_ERROR_CHECK;
    std::byte* buffer = (std::byte*)mapped.pData;

    // Serialize Data to Buffer
    for (auto& param : _parameters)
    {
        // Set Special Values
        if (param.parameter_is_special)
        {
            // Set Frame Time
            if (param.parameter_string == "frametime") SetAllTypeValues(0, this->_frame_time);

            // Set Frame Count
            if (param.parameter_string == "framecount") SetAllTypeValues(0, this->_frame_count);

            // Set Timer
            if (param.parameter_string == "timer") SetAllTypeValues(0, ChronoDurationCastMS(frame_end - _PluginStartTimePoint).count());
            
            // Set Date
            if (param.parameter_string == "date")  GetDateFloat4(param.parameter_floats);

            // Set Ping Pong
            if (param.parameter_string == "pingpong") 
            {
                const auto refParam = (reshadefx_extra::uniform*)&_uniforms[param.parameter_index];
                GetPingPongValue(
                    refParam->annotation_as_float("min", 0, 0.0f),
                    refParam->annotation_as_float("max", 0, 1.0f),
                    refParam->annotation_as_float("step", 0),
                    refParam->annotation_as_float("step", 1),
                    refParam->annotation_as_float("smoothing"),
                    param.parameter_floats,
                    this->frame_duration.count());
            }

            // Set Random
            if (param.parameter_string == "random") 
            {
                const auto refParam = (reshadefx_extra::uniform*)&_uniforms[param.parameter_index];
                SetAllTypeValues(0, GetRandomNumber(refParam->annotation_as_int("min", 0, 0.0f),
                                                    refParam->annotation_as_int("max", 0, RAND_MAX)));
            }
        }

        // Copy Data to GPU Buffer
        if (param.parameter_type == rlib_t::rlib_uint_t || param.parameter_type == rlib_t::rlib_bool_t)
            memcpy(&buffer[param.parameter_offset], &param.parameter_uints[0], param.parameter_size);
        if (param.parameter_type == rlib_t::rlib_int_t)
            memcpy(&buffer[param.parameter_offset], &param.parameter_ints[0], param.parameter_size);
        if (param.parameter_type == rlib_t::rlib_float_t)
            memcpy(&buffer[param.parameter_offset], &param.parameter_floats[0], param.parameter_size);
    }

    //  Upload Data to GPU
    _Context->Unmap(uniformBuffer.get(), 0);

    return true;
}
spmi ReshadeEffect::GetParameters(int index)
{
    shaderParamInfo.parameter_name = (LPSTR)_parameters[index].parameter_name.c_str();
    shaderParamInfo.parameter_type = _parameters[index].parameter_type;
    shaderParamInfo.parameter_count = _parameters[index].parameter_size / 4; // Use Typebased for this like bool = 1

    memcpy(shaderParamInfo.parameter_floats,    _parameters[index].parameter_floats,    16 * sizeof(float));
    memcpy(shaderParamInfo.parameter_ints,      _parameters[index].parameter_ints,      16 * sizeof(int));
    memcpy(shaderParamInfo.parameter_uints,     _parameters[index].parameter_uints,     16 * sizeof(unsigned int));

    return &shaderParamInfo;
}
bool ReshadeEffect::SetParameters(int index, cstr parameterData)
{
    return true;
}
bool ReshadeEffect::Destroy() 
{ 
    log("Destroying Shader %d...", _id);

    // Update Properties
    _initialized = false; 
    _is_destorying = true;
    this->Reset();

    return true; 
}

// Shader Database
unordered_map<int, ReshadeEffect*> shaders;

// Entrypoint
BOOL WINAPI DllMain(HINSTANCE const instance, DWORD const reason, LPVOID const reserved)
{
    UNREFERENCED_PARAMETER(instance);
    UNREFERENCED_PARAMETER(reason);
    UNREFERENCED_PARAMETER(reserved);
    return TRUE;
}

// Unity Internal Setup
static void UNITY_INTERFACE_API
OnGraphicsDeviceEvent(UnityGfxDeviceEventType eventType)
{
    switch (eventType)
    {
    case kUnityGfxDeviceEventInitialize:
        _RendererType = _Graphics->GetRenderer();
        if (_RendererType == kUnityGfxRendererNull)
        {
            log("Internal Device Bypassed (Renderer Null)");
            break;
        }
        if (_RendererType == kUnityGfxRendererD3D11)
        {
            // Initialize
            _Interface = _UnityInterfaces->Get<IUnityGraphicsD3D11>();
            _Device = _Interface->GetDevice();
            _Device->GetImmediateContext(&_Context);

            // Create Vertex Buffer
            memset(&_VertexBuffer_Desc, 0, sizeof(_VertexBuffer_Desc));
            _VertexBuffer_Desc.Usage = D3D11_USAGE_DEFAULT;
            _VertexBuffer_Desc.ByteWidth = 1024;
            _VertexBuffer_Desc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
            _Device->CreateBuffer(&_VertexBuffer_Desc, NULL, &_VertexBuffer);

            // Start Timer
            _PluginStartTimePoint = HighresClockNow;
        }
        else 
        {
            MessageBox(0, L"Graphic device is not compatibilite wtih plugin.\nMake sure you build on DirectX 11.", L"Compatibility Error", MB_ICONSTOP);
            exit(EXIT_FAILURE);
        }
        break;
    case kUnityGfxDeviceEventShutdown:
        _RendererType = kUnityGfxRendererNull;
        // for (int i = 0; i < shaders.size(); i++) shaders[i]->Destroy();
        break;
    case kUnityGfxDeviceEventBeforeReset:
        for (int i = 0; i < shaders.size(); i++) shaders[i]->Reset();
        break;
    case kUnityGfxDeviceEventAfterReset:
        for (int i = 0; i < shaders.size(); i++) shaders[i]->Reset();
        break;
    };
}
_DLL_EXPORT void UnityPluginLoad(IUnityInterfaces* unityInterfaces)
{
    _UnityInterfaces = unityInterfaces;
    _Graphics = unityInterfaces->Get<IUnityGraphics>();
    _Graphics->RegisterDeviceEventCallback(OnGraphicsDeviceEvent);
    OnGraphicsDeviceEvent(kUnityGfxDeviceEventInitialize);
}
_DLL_EXPORT void UnityPluginUnload()
{
    _Graphics->UnregisterDeviceEventCallback(OnGraphicsDeviceEvent);
}

// Unity ReshadeFX API
_DLL_EXPORT ShaderID CompileShader(cstr shaderCode, PreprocessorMacro* ppMacros, int macroCount, int bufferW, int bufferH)
{
    ReshadeEffect* newShader = new ReshadeEffect(shaderCode, ppMacros, macroCount);
    newShader->UpdateBufferSize(bufferW, bufferH);
    newShader->CreateEffect();
    shaders.insert({ newShader->GetID(), newShader });
    return newShader->GetID();
}
_DLL_EXPORT bool RenderEffect(ShaderID shader, ID3D11Resource* in, ID3D11Resource* in_depth, ID3D11Resource* out)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return false;
    return getShader->RenderEffect(in, in_depth, out);
}
_DLL_EXPORT bool UpdateEffect(ShaderID shader, int bufferW, int bufferH)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return false;
    if(!getShader->UpdateBufferSize(bufferW, bufferH))return false;
    if (!getShader->IsInitialized()) return true;
    if (!getShader->Reset()) return false;
    return true;
}
_DLL_EXPORT bool SetShaderState(ShaderID shader, bool active)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return false;
    getShader->SetState(active);
    return true;
}
_DLL_EXPORT bool SetShaderTimeValues(ShaderID shader, int frameCount, float frameLong)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return false;
    getShader->SetTime(frameCount, frameLong);
    return true;
}
_DLL_EXPORT int  GetShaderParameterNum(ShaderID shader)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return false;
    return getShader->GetParameterNum();
}
_DLL_EXPORT spmi GetShaderParameters(ShaderID shader, int parameterIndex)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return &spmi_default;
    return getShader->GetParameters(parameterIndex);
}
_DLL_EXPORT bool SetShaderParameters(ShaderID shader, int parameterIndex, cstr parameterData)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return false;
    return getShader->SetParameters(parameterIndex, parameterData);
}
_DLL_EXPORT bool DestroyShader(ShaderID shader)
{
    ReshadeEffect* getShader = shaders[shader];
    if (!getShader) return false;
    if (getShader->Destroy()) 
    {
        shaders.erase(shader);
        return true;
    }
    return false;
}
_DLL_EXPORT uint16_t GetLoadedShadersNum()
{
    return shaders.size();
}