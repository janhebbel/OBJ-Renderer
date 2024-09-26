@echo off

if not exist bin mkdir bin
pushd bin

echo Compiling Vertex Shader...
fxc -nologo -T "vs_5_0" -E "vertex_main" -WX -Zi -Fo "default_vertex.cso" -Fd "default_vertex.pdb" -Ges "../src/shaders/default_vertex.hlsl"
if %ERRORLEVEL% NEQ 0 (
        popd
        EXIT /B 1
)
echo Success!
echo:

echo Compiling Pixel Shader...
fxc -nologo -T "ps_5_0" -E "pixel_main" -WX -Zi -Fo "default_pixel.cso" -Fd "default_pixel.pdb" -Ges "../src/shaders/default_pixel.hlsl"
if %ERRORLEVEL% NEQ 0 (
        popd
        EXIT /B 1
)
echo Success!
echo:

popd
