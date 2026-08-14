@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ======================配置区======================
set "AUTO_INSTALL_NODE=false"
set "LOCAL_IP="
set "PORT=3080"
set "PDU_FW_RULE=DSH_LAN_TOOL_%PORT%"
:: ==================================================

cls
echo ==============================================
echo        DSH 局域网一体化工具 v1.6.1
echo ==============================================
echo.

:: --------------------------判断管理员权限--------------------------
fltmc >nul 2>&1
if !errorlevel! neq 0 (
    echo [警告] 当前未以管理员身份运行！
    echo [提示] 端口转发、防火墙功能需要管理员权限。
    echo.
    pause
)

:: --------------------------获取内网私有IP 过滤VPN/公网虚拟IP--------------------------
echo [信息]正在自动探测本机局域网IP...
if defined LOCAL_IP goto SKIP_AUTO_IP

set "LOCAL_IP="
for /f "delims=[] tokens=2" %%a in ('ping -4 -n 1 %computername% ^| findstr "["') do (
    set "TEST_IP=%%a"
    call :IS_PRIVATE_IP !TEST_IP!
    if !IS_PRIVATE! equ 1 (
        set "LOCAL_IP=%%a"
    )
)

if "!LOCAL_IP!"=="" (
    echo [错误]自动获取内网IP失败！检测到VPN/虚拟网卡，请手动在脚本配置区填写 LOCAL_IP
    pause >nul
    exit
)
:SKIP_AUTO_IP
echo [信息]探测到本机局域网IP: !LOCAL_IP!
echo.

:: --------------------------校验Node/NPM环境（修复延迟扩展卡死bug）--------------------------
:CHECK_NODE_NPM
echo [信息]校验 Node.js / NPM 环境...
setlocal disabledelayedexpansion
npm -v >nul 2>&1
set NPM_EXIT=!errorlevel!
endlocal & set "NPM_EXIT=%NPM_EXIT%"

if %NPM_EXIT% neq 0 (
    echo [警告]本机未检测到 NPM / Node.js！
    if "!AUTO_INSTALL_NODE!"=="true" (
        echo [信息]将执行Node.js LTS静默安装，需要网络与管理员权限
        call :AUTO_DOWNLOAD_NODE
    ) else (
        echo.
        echo 提示：修改脚本顶部 AUTO_INSTALL_NODE=true 开启自动安装Node
        echo 请手动下载安装 Node.js LTS：https://nodejs.org/
        echo ⚠️安装完成必须完全关闭脚本窗口，重新运行！
        pause >nul
        exit
    )
)

set "NPM_VER="
setlocal disabledelayedexpansion
for /f "delims=" %%i in ('npm -v 2^>nul') do set "TMP_VER=%%i"
endlocal & set "NPM_VER=%TMP_VER%"

if defined NPM_VER echo [OK]检测NPM版本: !NPM_VER!
echo.

:: --------------------------检查DSH是否已经全局安装--------------------------
set "DSH_PATH=%APPDATA%\npm\dsh.cmd"
if exist "!DSH_PATH!" (
    echo [OK]已检测全局DSH，进入主菜单
    echo.
    goto MAIN_MENU
)

echo [提示]未检测到全局DSH，是否执行 npm install -g dsh
set /p INSTALL_DSH="输入Y确认安装 / N退出(Y/N): "
if /i "!INSTALL_DSH!"=="Y" (
    echo [信息]正在执行 npm install -g dsh ...
    setlocal disabledelayedexpansion
    npm install -g dsh
    endlocal
) else (
    echo [退出]用户取消安装DSH
    pause >nul
    exit
)

if not exist "!DSH_PATH!" (
    echo [错误]DSH安装失败！检查网络、npm全局权限、镜像源
    pause >nul
    exit
)
echo [OK]DSH全局安装完成
echo.

goto MAIN_MENU

:: =====================主菜单=====================
:MAIN_MENU
cls
echo ==============================================
echo          DSH‑LAN‑TOOL v1.6.1 主菜单
echo    本机内网IP:!LOCAL_IP! 端口:!PORT!
echo ==============================================
echo 1.开启端口转发+防火墙放行
echo 2.关闭端口转发+删除防火墙规则
echo 3.启动DSH‑Web服务，自动打开浏览器
echo 4.一键状态自检
echo 6.NPM镜像源设置子菜单
echo 5.退出程序
echo ==============================================
set /p SEL="请输入功能数字:"

if "!SEL!"=="1" goto SETUP_FORWARD
if "!SEL!"=="2" goto CLEAR_FORWARD
if "!SEL!"=="3" goto START_DSH_WEB
if "!SEL!"=="4" goto CHECK_ALL_STATUS
if "!SEL!"=="6" goto NPM_MIRROR_SUBMENU
if "!SEL!"=="5" goto SAFE_EXIT
echo [错误]无效输入，请重新选择
timeout /t 1 /nobreak >nul
goto MAIN_MENU

:: =====================端口转发开启=====================
:SETUP_FORWARD
echo.
netsh interface portproxy show all | findstr ":!PORT!" >nul
if !errorlevel! equ 0 (
    echo [提示]端口 !PORT!转发规则已存在，跳过重复创建
) else (
    echo [信息]新增portproxy端口转发 !PORT!^->!LOCAL_IP!:!PORT!
    netsh interface portproxy add v4tov4 listenport=!PORT! listenaddress=0.0.0.0 connectport=!PORT! connectaddress=!LOCAL_IP!
)

netsh advfirewall firewall show rule name="!PDU_FW_RULE!" >nul
if !errorlevel! equ 0 (
    echo [提示]防火墙规则已存在
) else (
    echo [信息]创建防火墙入站放行规则 !PDU_FW_RULE!
    netsh advfirewall firewall add rule name="!PDU_FW_RULE!" dir=in action=allow protocol=TCP localport=!PORT! profile=any enable=yes >nul
)
echo [完成]端口转发配置完成
echo.
pause
goto MAIN_MENU

:: =====================清理端口转发=====================
:CLEAR_FORWARD
echo.
netsh interface portproxy show all | findstr ":!PORT!" >nul
if !errorlevel! equ 0 (
    echo [信息]删除portproxy !PORT!转发
    netsh interface portproxy delete v4tov4 listenport=!PORT! listenaddress=0.0.0.0
) else (
    echo [提示]未找到portproxy转发规则
)

netsh advfirewall firewall show rule name="!PDU_FW_RULE!" >nul
if !errorlevel! equ 0 (
    echo [信息]删除防火墙规则 !PDU_FW_RULE!
    netsh advfirewall firewall delete rule name="!PDU_FW_RULE!" >nul
) else (
    echo [提示]未找到防火墙规则
)
echo [完成]转发与防火墙规则清理完毕
echo.
pause
goto MAIN_MENU

:: =====================启动DSH Web=====================
:START_DSH_WEB
echo.
if not exist "!DSH_PATH!" (
    echo [错误]dsh.cmd不存在，无法启动！
    pause
    goto MAIN_MENU
)
echo [信息]启动DSH‑Web，等待3秒后自动打开浏览器
start "" cmd /k dsh web
timeout /t 3 /nobreak >nul
start http://127.0.0.1:!PORT!
echo.
pause
goto MAIN_MENU

:: =====================全部状态自检=====================
:CHECK_ALL_STATUS
cls
echo ========== 状态自检报告 ==========
echo 本机内网IP: !LOCAL_IP!
echo.
echo 1.portproxy端口转发(!PORT!):
netsh interface portproxy show all | findstr ":!PORT!"
if !errorlevel! neq 0 echo     → 无转发规则
echo.
echo 2.防火墙规则(!PDU_FW_RULE!):
netsh advfirewall firewall show rule name="!PDU_FW_RULE!" >nul
if !errorlevel! equ 0 (echo     → 规则存在) else (echo     → 不存在)
echo.
echo 3.DSH全局文件(!DSH_PATH!):
if exist "!DSH_PATH!" (echo     → 文件存在) else (echo     → 文件缺失)
echo.
echo ==================================
pause
goto MAIN_MENU

:: =====================NPM镜像子菜单=====================
:NPM_MIRROR_SUBMENU
cls
echo ========== NPM镜像源设置 ==========
echo 1.切换淘宝npmmirror国内镜像
echo 2.还原官方npm原始源
echo 3.查看当前生效镜像地址
echo 0.返回主菜单
echo ==================================
set /p MIR_SEL="请输入选择:"
if "!MIR_SEL!"=="1" (
    echo [信息]设置npm registry为淘宝镜像
    setlocal disabledelayedexpansion
    npm config set registry https://registry.npmmirror.com
    endlocal
)
if "!MIR_SEL!"=="2" (
    echo [信息]恢复npm官方源
    setlocal disabledelayedexpansion
    npm config set registry https://registry.npmjs.org
    endlocal
)
if "!MIR_SEL!"=="3" (
    echo [信息]当前registry:
    setlocal disabledelayedexpansion
    npm config get registry
    endlocal
)
if "!MIR_SEL!"=="0" goto MAIN_MENU
echo.
pause
goto NPM_MIRROR_SUBMENU

:: =====================安全退出，检测残留规则=====================
:SAFE_EXIT
echo.
netsh interface portproxy show all | findstr ":!PORT!" >nul
if !errorlevel! equ 0 (
    echo ⚠️警告：检测到本脚本创建的 !PORT!端口转发规则尚未清理！
    echo portproxy属于系统持久规则，重启电脑不会自动清除，请回到菜单执行选项2清理！
)
echo 即将退出脚本
timeout /t 2
exit

:: =====================私有IP判断函数，过滤公网/VPNIP=====================
:IS_PRIVATE_IP
set "IS_PRIVATE=0"
echo %~1 | findstr /r "^192\.168\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^10\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.16\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.17\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.18\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.19\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.20\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.21\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.22\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.23\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.24\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.25\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.26\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.27\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.28\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.29\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.30\." >nul && set IS_PRIVATE=1
echo %~1 | findstr /r "^172\.31\." >nul && set IS_PRIVATE=1
goto :eof

:: =====================Node自动安装（简易静默安装，可按需开启AUTO_INSTALL_NODE=true）=====================
:AUTO_DOWNLOAD_NODE
echo [提示]Node自动安装逻辑，你可以根据需要完善，当前版本提示手动安装
echo ⚠️静默MSI安装会被Windows Defender拦截
echo 请手动安装Node.js LTS，安装完成关闭脚本窗口重新运行
pause >nul
exit
