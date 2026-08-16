@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
::======================== 脚本配置区 ========================
set "LOCAL_IP="
set "LOCAL_PORT=8080"
set "SHADOW_DSH_PORT=22222"
set "AUTO_CLEAN_RULE=1"
::npx内置镜像，不修改系统全局npm配置
set "NPM_REGISTRY=https://registry.npmmirror.com"
set "NPX_CMD=--registry=%NPM_REGISTRY% @deepseek-ai/dsh web --port %SHADOW_DSH_PORT%"
::===========================================================
cls
echo ======================================================
echo        DSH 局域网一体化工具 v1.9.0 增强NPX版
echo  ?前置条件：手动安装 Node.js LTS，脚本无法自动安装Node
echo ======================================================
echo [环境检测]脚本工作目录: %cd%
echo.
goto env_check
:recheck_env
cls
:env_check
echo -------- 前置环境检测 --------
set "NODE_OK=0"
set "NPX_OK=0"
fltmc >nul 2>&1
if errorlevel 1 (
    echo [?错误]当前不是管理员权限！端口转发netsh必须管理员，请右键脚本【以管理员身份运行】
) else (
    echo [?OK]管理员权限校验通过
)
where node >nul 2>&1
if errorlevel 1 (
    echo [?未检测到node.js]
    echo 请手动下载安装 Node.js LTS https://nodejs.org/
    echo 安装完成后关闭全部cmd窗口，重新运行本脚本
) else (
    set "NODE_OK=1"
    for /f "delims=" %%v in ('node -v 2^>nul') do echo [?OK]node版本: %%v
)
where npx >nul 2>&1
if errorlevel 1 (
    echo [?未检测到npx] Node安装异常
) else (
    set "NPX_OK=1"
    for /f "delims=" %%v in ('npx -v 2^>nul') do echo [?OK]npx版本: %%v
)
netstat -ano | findstr ":%SHADOW_DSH_PORT%" >nul
if not errorlevel 1 (
    echo [?警告]端口%SHADOW_DSH_PORT%已经被占用！DSH服务端口冲突
) else (
    echo [?OK]%SHADOW_DSH_PORT%端口空闲
)
echo ------------------------------
echo.
::IP自动探测
if defined LOCAL_IP (
    echo [信息]已使用手动配置IP: !LOCAL_IP!
    goto ip_probe_done
)
set /a ip_count=0
set "ip_list[0]="
echo [信息]正在自动探测本机局域网IP...
for /f "delims=: tokens=2" %%a in ('ipconfig ^| findstr /i "IPv4 地址"') do (
    set "tmp_ip=%%a"
    set "tmp_ip=!tmp_ip: =!"
    call :filter_ip "!tmp_ip!"
)
if !ip_count! EQU 0 (
    echo [错误]未探测到有效局域网IP，请手动在脚本头部配置 LOCAL_IP
    pause
    goto main_menu
)
if !ip_count! EQU 1 (
    set "LOCAL_IP=!ip_list[1]!"
    echo [信息]自动选中本机IP: !LOCAL_IP!
    goto ip_probe_done
)
echo.
echo [提示]检测到多张内网网卡，请选择本机实际局域网IP：
for /l %%i in (1,1,!ip_count!) do (
    echo   %%i: !ip_list[%%i]!
)
echo.
:input_ip_choose
set "choose="
set /p "choose=请输入序号数字: "
if not defined choose goto input_ip_choose
echo !choose!| findstr "^[0-9]*$" >nul
if errorlevel 1 (
    echo [错误]请输入合法数字序号
    goto input_ip_choose
)
if !choose! LSS 1 goto input_ip_choose
if !choose! GTR !ip_count! goto input_ip_choose
set "LOCAL_IP=!ip_list[!choose!]!"
echo [信息]已选择IP: !LOCAL_IP!
:ip_probe_done
goto ip_probe_end
:filter_ip
set "curr_ip=%~1"
if not defined curr_ip goto :eof
echo !curr_ip! | findstr "^127\." >nul
if not errorlevel 1 goto :eof
echo !curr_ip! | findstr "^192\.168\." >nul && goto add_ip
echo !curr_ip! | findstr "^10\." >nul && goto add_ip
echo !curr_ip! | findstr "^172\." >nul
if not errorlevel 1 (
    for /f "delims=." %%b in ("!curr_ip!") do set b1=%%b
    for /f "delims=." %%c in ("!curr_ip:*.=!") do set b2=%%c
    if !b1! EQU 172 if !b2! GEQ 16 if !b2! LEQ 31 goto add_ip
)
goto :eof
:add_ip
set /a ip_count+=1
set "ip_list[!ip_count!]=!curr_ip!"
goto :eof
:ip_probe_end
echo.
echo [本机信息] 局域网IP: !LOCAL_IP!
echo [本机信息] 外部访问端口: !LOCAL_PORT!
echo [本机信息] DSH本地端口: !SHADOW_DSH_PORT!
echo [npx启动命令] npx !NPX_CMD!
echo.
:main_menu
echo ====================== 功能菜单 ======================
echo 1. 创建端口转发规则
echo 2. 查看本机现有端口转发
echo 3. 删除全部端口转发规则
echo 4. 一键配置DSH局域网隧道
echo 5. 退出脚本
echo 6. 启动 DSH(npx)服务【新开独立窗口】
echo 7. 终止全部 Node / DSH 进程
echo 8. 重新执行环境自检
echo 9. 检测 DSH 版本信息
echo 10. 更新 DSH 到最新版本
echo =====================================================
set "sel="
set /p sel="请输入功能序号:"
echo.
if "!sel!"=="1" goto add_rule
if "!sel!"=="2" goto show_rule
if "!sel!"=="3" goto clean_all
if "!sel!"=="4" goto setup_dsh_tunnel
if "!sel!"=="5" goto exit_script
if "!sel!"=="6" goto start_dsh_npx
if "!sel!"=="7" goto stop_dsh_node
if "!sel!"=="8" goto recheck_env
if "!sel!"=="9" goto check_dsh_ver
if "!sel!"=="10" goto update_dsh
echo [错误]无效输入，请重新选择
echo.
goto main_menu

:check_dsh_ver
echo ----- DSH 版本检测 -----
if !NODE_OK! EQU 0 (
    echo [错误]未检测Node.js，无法执行版本检测
    pause
    goto main_menu
)
if !NPX_OK! EQU 0 (
    echo [错误]npx不可用，无法执行版本检测
    pause
    goto main_menu
)

echo [信息]正在获取本地DSH运行版本...
set "LOCAL_DSH_VER=未知"
for /f "delims=" %%v in ('npx --registry=%NPM_REGISTRY% @deepseek-ai/dsh --version 2^>nul') do set "LOCAL_DSH_VER=%%v"
if "!LOCAL_DSH_VER!"=="未知" (
    echo [警告]未获取到本地版本，可能尚未下载过DSH包
) else (
    echo [OK]本地DSH版本: !LOCAL_DSH_VER!
)

echo.
echo [信息]正在获取npm源最新版本...
set "LATEST_DSH_VER=未知"
for /f "delims=" %%v in ('npm view @deepseek-ai/dsh version --registry=%NPM_REGISTRY% 2^>nul') do set "LATEST_DSH_VER=%%v"
if "!LATEST_DSH_VER!"=="未知" (
    echo [警告]获取最新版本失败，请检查网络连接或镜像源
) else (
    echo [OK]npm最新版本: !LATEST_DSH_VER!
)

echo.
if not "!LOCAL_DSH_VER!"=="未知" if not "!LATEST_DSH_VER!"=="未知" (
    if "!LOCAL_DSH_VER!"=="!LATEST_DSH_VER!" (
        echo [信息]当前DSH已是最新版本
    ) else (
        echo [提示]存在可用更新，可选择菜单「10」更新到最新版
    )
)
echo.
pause
goto main_menu

:update_dsh
echo ----- 更新 DSH 到最新版 -----
if !NODE_OK! EQU 0 (
    echo [错误]未检测Node.js，无法执行更新
    pause
    goto main_menu
)
if !NPX_OK! EQU 0 (
    echo [错误]npx不可用，无法执行更新
    pause
    goto main_menu
)

echo [信息]正在查询最新版本号...
set "LATEST_VER=未知"
set "LOCAL_VER=未知"
for /f "delims=" %%v in ('npm view @deepseek-ai/dsh version --registry=%NPM_REGISTRY% 2^>nul') do set "LATEST_VER=%%v"
for /f "delims=" %%v in ('npx --yes --registry=%NPM_REGISTRY% @deepseek-ai/dsh --version 2^>nul') do set "LOCAL_VER=%%v"

if "!LATEST_VER!"=="未知" (
    echo [警告]获取最新版本失败，尝试直接拉取...
    goto do_update
)
if "!LOCAL_VER!"=="未知" (
    echo [信息]本地未检测到DSH缓存，执行首次安装...
    goto do_update
)

:: 版本一致，直接跳过更新
if "!LOCAL_VER!"=="!LATEST_VER!" (
    echo [信息]当前已是最新版本 [!LOCAL_VER!]，无需更新
    echo.
    pause
    goto main_menu
)

echo [信息]发现新版本：!LOCAL_VER! --^> !LATEST_VER!

:do_update
echo [信息]正在拉取安装包（无进度条，请耐心等待1-3分钟）...
echo [说明]全程使用npmmirror国内镜像加速，首次更新耗时较长
echo.

npx --yes --registry=%NPM_REGISTRY% @deepseek-ai/dsh@latest --version >nul 2>&1

if !errorlevel! equ 0 (
    echo.
    echo [成功]DSH已更新完成
    for /f "delims=" %%v in ('npx --yes --registry=%NPM_REGISTRY% @deepseek-ai/dsh --version 2^>nul') do echo 当前生效版本: %%v
) else (
    echo [失败]更新执行失败
    echo 建议: 1. 检查网络  2. 执行 npx --clear-cache 清理缓存后重试
)
echo.
pause
goto main_menu


:start_dsh_npx
if !NODE_OK! EQU 0 (
    echo [?无法启动]未检测Node.js，请先手动安装Node LTS版本
    pause
    goto main_menu
)
if !NPX_OK! EQU 0 (
    echo [?无法启动]npx不可用，请修复Node安装
    pause
    goto main_menu
)
echo ----- 通过npx启动 DSH服务 -----
echo [说明]将弹出新CMD窗口运行DSH，请勿关闭该窗口
echo 本地访问地址: http://127.0.0.1:!SHADOW_DSH_PORT!
echo 首次运行需要联网下载包，已经内置npmmirror镜像
echo.
start "DSH?Service" cmd /k "npx !NPX_CMD!"
echo [完成]DSH服务窗口已拉起！
echo.
pause
goto main_menu
:stop_dsh_node
echo ----- 终止Node/DSH相关进程 -----
taskkill /f /im node.exe 2>nul
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq DSH?Service*" 2>nul
echo [完成]已尝试杀掉所有node进程以及DSH服务窗口
echo.
pause
goto main_menu
:add_rule
echo ----- 创建端口转发 -----
set "in_port="
set /p in_port="输入本机监听端口:"
set "dst_ip="
set /p dst_ip="输入目标内网IP:"
set "dst_port="
set /p dst_port="输入目标端口:"
netsh interface portproxy add v4tov4 listenport=!in_port! listenaddress=!LOCAL_IP! connectport=!dst_port! connectaddress=!dst_ip!
if !errorlevel! equ 0 (
    echo [成功]转发规则已创建 !LOCAL_IP!:!in_port! ===^> !dst_ip!:!dst_port!
) else (
    echo [失败]创建端口转发失败，请检查管理员权限、端口是否占用
)
echo.
pause
goto main_menu
:show_rule
echo ----- 当前端口转发列表 -----
netsh interface portproxy show all
echo.
pause
goto main_menu
:clean_all
echo 即将清除全部 portproxy 转发规则，确认继续？(Y/N)
set "confirm="
set /p confirm="输入选择:"
if /i not "!confirm!"=="Y" goto main_menu
netsh interface portproxy reset
echo [完成]全部端口转发规则已清空
echo.
pause
goto main_menu
:setup_dsh_tunnel
echo ----- DSH局域网隧道配置 -----
netsh interface portproxy add v4tov4 listenport=!LOCAL_PORT! listenaddress=!LOCAL_IP! connectport=!SHADOW_DSH_PORT! connectaddress=127.0.0.1
if !errorlevel! equ 0 (
    echo [成功]DSH隧道转发已配置完成
    echo ?局域网其他设备访问：http://!LOCAL_IP!:!LOCAL_PORT!
) else (
    echo [失败]DSH隧道配置失败，请确认管理员权限
)
echo.
pause
goto main_menu
:exit_script
if !AUTO_CLEAN_RULE! EQU 1 (
    echo [提示]自动清理模式开启，正在清空所有portproxy规则
    netsh interface portproxy reset
)
echo 程序退出
timeout /t 2 /nobreak >nul
popd
endlocal
exit /b
