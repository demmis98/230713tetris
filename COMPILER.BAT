for /f %%G in ('dir *.asm /b') do D:\THiNGS\CODE\Res\cc65\bin\cl65 %%~G --verbose --target nes -o %%~nG.nes
pause