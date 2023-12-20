REM Get it from swagger/ui. This method throws an error with Azure Functions (works against Web API.)

ECHO OFF
REM Usage: dotnet swagger tofile [options] [startupassembly] [swaggerdoc]
REM startupassembly:
REM   relative path to the application's startup assembly
REM swaggerdoc:
REM   name of the swagger doc you want to retrieve, as configured in your startup class
REM options:
REM   --output:  relative path where the Swagger will be output, defaults to stdout
REM   --host:  a specific host to include in the Swagger output
REM   --basepath:  a specific basePath to include in the Swagger output
REM   --serializeasv2:  output Swagger in the V2 format rather than V3
REM   --yaml:  exports swagger in a yaml format
REM CD to script directory

REM *** Change to CurrentDir..\
set curr_dir=%~dp0
set curr_drive=%curr_dir:~0,2%
%curr_drive%
cd %curr_dir%
cd ..\
REM *******************************

Set TargetPath=.\bin\Debug\netcoreapp3.1\MyApi.dll
Set ProjectDir=.

dotnet new tool-manifest
dotnet tool install --global Swashbuckle.AspNetCore.Cli
dotnet tool update --global Swashbuckle.AspNetCore.Cli

cd
ECHO dotnet swagger tofile --output %ProjectDir%\swagger.json %TargetPath% v1
dotnet swagger tofile --output %ProjectDir%\swagger.json %TargetPath% v1

Exit 0