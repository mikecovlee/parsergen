@echo off
setlocal
set CS="C:\Program Files (x86)\CovScript\bin\cs.exe"
set IMPORT_PATH=%~dp0..
set FAILED=0

echo ==============================
echo  ParserGen Unit Tests
echo ==============================
echo.

echo --- test_parsergen.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_parsergen.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_core_semantics.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_core_semantics.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_ebnf_parser.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_ebnf_parser.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_ebnfigen.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_ebnfigen.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_roundtrip.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_roundtrip.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_analysis.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_analysis.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_analysis_edge.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_analysis_edge.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_recovery.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_recovery.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- Generate parsers for codegen test ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0..\misc\test_codegen_full.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- Generate parsers for codegen core test ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0..\misc\test_codegen_core.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_codegen_full.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_codegen_full.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo --- test_codegen_core.csc ---
%CS% --import-path "%IMPORT_PATH%" "%~dp0test_codegen_core.csc"
if %errorlevel% neq 0 set FAILED=1
echo.

echo ==============================
if %FAILED% equ 0 (
    echo  ALL TESTS PASSED
) else (
    echo  SOME TESTS FAILED
)
echo ==============================
exit /b %FAILED%
