@echo off
rem ============================================================
rem  sync-workshop-pack.bat
rem  把 gamemodes/fireteam 仓库源镜像到工坊打包目录
rem  （coldwar_content\00_游戏模式），随后可对该目录执行
rem  gmad create 上传。
rem
rem  镜像规则：
rem   - 排除 README.md        ：.md 不在 GMA 白名单，进不了包
rem   - 排除 branding\        ：门面图仅存档用，非运行时资产
rem   - 排除 icon24/logo.png  ：打包目录独有，gmad 拒收大写盘路径外
rem                             无所谓，关键是不能被镜像删除
rem ============================================================
setlocal
set SRC=%~dp0..\gamemodes\fireteam
set DST=%~dp0..\..\coldwar_content\00_游戏模式\gamemodes\fireteam

if not exist "%SRC%\gamemode" (
    echo [错误] 未找到源目录: %SRC%
    pause & exit /b 1
)

robocopy "%SRC%" "%DST%" /MIR ^
    /XD branding .git ^
    /XF README.md icon24.png logo.png Thumbs.db
if errorlevel 8 (
    echo [错误] robocopy 失败，errorlevel=%ERRORLEVEL%
    pause & exit /b 1
)

echo.
echo [完成] 已镜像到 %DST%
echo 下一步: cd 到 coldwar_content\00_游戏模式 执行 gmad create 打包上传
pause
