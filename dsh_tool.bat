@echo off
chcp 936 >nul
setlocal enabledelayedexpansion

set FIREWALL_RULE=DSH-3080-LAN
:: 置空自动探测；多网卡识别异常手动设置 set LOCAL_IP=192.168.1.19
set LOCAL_IP=
set PORT=3080
set DSH_PATH=%APPDATA%\npm\dsh.cmd
set TAOBAO_REGISTRY=https://registry.npmmirror.com
set OFFICIAL_REGISTRY=https://registry.npmjs.org

:: ==========【可选】是否开启Node自动静默安装 true开启 false关闭 ==========
set AUTO_INSTALL_NODE=false
:: ====================================================================

:: ==========自动获取本机局域网IPv4==========
echo [信息]正在自动探测本机局域网IP...
for /f "delims=[] tokens=2" %%a in ('ping -4 -n 1 %computername% ^| findstr "["') do (
    set "LOCAL_IP=%%a"
)
if "!LOCAL_IP!"=="" (
    echo [错误]自动获取IP失败，请手动在脚本设置 LOCAL_IP
    pause >nul
    exit
)
echo [信息]探测到本机局域网IP: !LOCAL_IP!
echo.
:: ==========================================

:: ==========依赖检测：Node/npm / DSH自动安装逻辑 ==========
call :CHECK_NODE_NPM
call :CHECK_INSTALL_DSH
:: ========================================================

fltmc >nul 2>&1
set "ADMIN_OK=!errorlevel!"

:MENU
cls
echo ============= DSH局域网一体化工具 V1.6 =============
echo 当前局域网IP：!LOCAL_IP!  端口：%PORT%
if !ADMIN_OK! NEQ 0 (
    echo [警告]：非管理员，1/2功能需要右键以管理员身份运行！
)
echo.
echo [状态自检]
call :CHECK_FORWARD
call :CHECK_DSH
echo.
echo 1. 开启局域网端口转发(管理员)
echo 2. 关闭局域网端口转发清理规则(管理员)
echo 3. 启动DSH Web服务
echo 4. 一键自检全部状态
echo 5. 退出
echo 6. NPM镜像源设置
echo =====================================================
set /p opt=请输入选项[1-6]:

if "%opt%"=="1" goto START_FORWARD
if "%opt%"=="2" goto STOP_FORWARD
if "%opt%"=="3" goto START_DSH
if "%opt%"=="4" goto SELF_CHECK
if "%opt%"=="5" goto EXIT_CHECK
if "%opt%"=="6" goto MIRROR_SUBMENU

echo 输入无效，回车返回菜单
pause >nul
goto MENU

:: =================NPM镜像子菜单=================
:MIRROR_SUBMENU
cls
echo ========== NPM镜像源设置子菜单 ==========
echo 1 = 切换淘宝镜像(npmmirror国内源)
echo 2 = 还原NPM官方原始镜像
echo 3 = 查看当前使用镜像源
echo 0 = 返回主菜单
echo =========================================
set /p mopt=请输入操作:
if "%mopt%"=="1" goto SET_TAOBAO
if "%mopt%"=="2" goto SET_OFFICIAL
if "%mopt%"=="3" goto SHOW_CURR_MIRROR
if "%mopt%"=="0" goto MENU
echo 无效输入，按任意键返回镜像子菜单
pause >nul
goto MIRROR_SUBMENU

:SET_TAOBAO
echo [操作]正在设置npm registry为淘宝镜像 !TAOBAO_REGISTRY!
npm config set registry !TAOBAO_REGISTRY!
if !errorlevel! equ 0 (
    echo [OK]镜像切换成功。
) else (
    echo [错误]镜像切换失败，请检查npm环境。
)
pause >nul
goto MIRROR_SUBMENU

:SET_OFFICIAL
echo [操作]正在还原npm官方源 !OFFICIAL_REGISTRY!
npm config set registry !OFFICIAL_REGISTRY!
if !errorlevel! equ 0 (
    echo [OK]已还原官方原始镜像。
) else (
    echo [错误]镜像还原失败，请检查npm环境。
)
pause >nul
goto MIRROR_SUBMENU

:SHOW_CURR_MIRROR
echo [信息]读取当前npm registry配置：
npm config get registry
pause >nul
goto MIRROR_SUBMENU
:: ================================================

:: 检测node和npm是否可用
:CHECK_NODE_NPM
echo [信息]校验 Node.js / NPM 环境...
npm -v >nul 2>&1
if !errorlevel! neq 0 (
    echo [警告]本机未检测到 NPM / Node.js！
    if "!AUTO_INSTALL_NODE!"=="true" (
        echo [信息]开启Node自动静默安装，需要管理员权限与网络。
        call :AUTO_DOWNLOAD_NODE
    ) else (
        echo.
        echo 提示：脚本内修改 AUTO_INSTALL_NODE=true 可以开启自动下载安装Node
        echo 请手动下载安装 Node.js(LTS版本)：https://nodejs.org/
        echo ??安装完成后必须完全关闭脚本，重新运行本bat！
        pause >nul
        exit
    )
)
for /f "delims=" %%i in ('npm -v 2^>nul') do set NPM_VER=%%i
if defined NPM_VER echo [OK]检测NPM版本: !NPM_VER!
echo.
goto :eof

:: Node.js自动下载静默安装子过程
:AUTO_DOWNLOAD_NODE
fltmc >nul 2>&1
if !errorlevel! neq 0 (
    echo [错误]自动安装Node需要管理员权限，请右键管理员运行脚本！
    pause >nul
    exit
)
echo [信息]正在下载Node.js LTS安装包...
set "NODE_INSTALLER=%temp%\nodejs_lts.msi"
:: 国内镜像下载LTS msi
powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://npmmirror.com/mirrors/node/v22.14.0/node-v22.14.0-x64.msi','!NODE_INSTALLER!')"
if not exist "!NODE_INSTALLER!" (
    echo [错误]Node安装包下载失败，请检查网络！
    pause >nul
    exit
)
echo [信息]执行静默安装Node.js，等待完成...
msiexec /i "!NODE_INSTALLER!" /qn /norestart
echo [信息]Node安装程序执行完毕！
echo.
echo ??【重要】Windows进程限制！环境变量PATH不会在当前脚本生效！
echo 请关闭本脚本窗口，重新右键管理员运行dsh_tool.bat！
echo.
pause >nul
exit
goto :eof

:: 检测DSH，不存在则交互式自动安装
:CHECK_INSTALL_DSH
echo [信息]校验DSH全局安装状态...
if exist "%DSH_PATH%" (
    echo [OK]DSH已全局安装。
    echo.
    goto :eof
)
echo [NO]未找到 dsh.cmd，DSH未全局安装！
echo 提示：下载慢可以先到【6 NPM镜像源设置】切换国内淘宝镜像
set /p do_install=是否执行 npm install -g dsh 自动安装？(Y/N):
if /i "!do_install!"=="Y" (
    echo [信息]开始全局安装DSH，请等待网络下载完成...
    npm install -g dsh
    :: 刷新环境变量，重新读取npm路径
    set "DSH_PATH=%APPDATA%\npm\dsh.cmd"
    if exist "!DSH_PATH!" (
        echo.
        echo [OK]DSH安装成功！
    ) else (
        echo.
        echo [错误]npm执行完毕，但仍然找不到dsh.cmd，安装失败！
        echo 建议切换国内镜像源后重试，检查网络、npm全局权限。
        pause >nul
        exit
    )
) else (
    echo [提示]用户选择不安装DSH，脚本退出。
    pause >nul
    exit
)
echo.
goto :eof

:: 检测端口转发是否存在，检索listenport
:CHECK_FORWARD
netsh interface portproxy show all | findstr /c:"listenport=%PORT%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK]端口转发：已开启
) else (
    echo [NO]端口转发：未开启
)
goto :eof

:: 检测dsh.cmd是否存在
:CHECK_DSH
if exist "%DSH_PATH%" (
    echo [OK]DSH程序：检测正常
) else (
    echo [NO]DSH程序：未找到 dsh.cmd
)
goto :eof

:SELF_CHECK
cls
echo ==================== 完整自检报告 ====================
echo 本机局域网IP      : !LOCAL_IP!:%PORT%
echo 本机访问地址      : http://127.0.0.1:%PORT%
echo 局域网访问地址    : http://!LOCAL_IP!:%PORT%
echo.
call :CHECK_FORWARD
call :CHECK_DSH
netsh advfirewall firewall show rule name="%FIREWALL_RULE%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK]防火墙规则：已存在
) else (
    echo [NO]防火墙规则：不存在
)
echo.
echo [安全提醒]portproxy为系统持久规则，重启电脑不会自动清除，用完务必执行关闭！
pause >nul
goto MENU

:START_FORWARD
if !ADMIN_OK! NEQ 0 (
    echo [错误]：必须右键【以管理员身份运行】脚本！
    pause >nul
    goto MENU
)
netsh interface portproxy show all | findstr /c:"listenport=%PORT%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [提示]端口转发已经存在，无需重复添加
    pause >nul
    goto MENU
)

netsh interface portproxy add v4tov4 listenport=%PORT% listenaddress=!LOCAL_IP! connectport=%PORT% connectaddress=127.0.0.1
netsh advfirewall firewall add rule name="%FIREWALL_RULE%" dir=in action=allow protocol=TCP localport=%PORT% enable=yes

echo.
echo --------当前转发规则--------
netsh interface portproxy show all
echo.
echo [OK]端口转发已启用！
echo 本机访问：http://127.0.0.1:%PORT%
echo 局域网访问：http://!LOCAL_IP!:%PORT%
echo [安全警告]仅限家庭内网，DSH存在远程代码执行风险，禁止暴露公网！
echo.
pause >nul
goto MENU

:STOP_FORWARD
if !ADMIN_OK! NEQ 0 (
    echo [错误]：必须右键【以管理员身份运行】脚本！
    pause >nul
    goto MENU
)
netsh interface portproxy show all | findstr /c:"listenport=%PORT%" >nul 2>&1
if !errorlevel! neq 0 (
    echo [提示]端口转发不存在，无需删除
) else (
    netsh interface portproxy delete v4tov4 listenport=%PORT% listenaddress=!LOCAL_IP!
)
netsh advfirewall firewall delete rule name="%FIREWALL_RULE%" >nul 2>&1

echo.
echo --------清理后转发列表--------
netsh interface portproxy show all
echo [OK]端口转发、防火墙规则已全部清除
echo.
pause >nul
goto MENU

:START_DSH
if not exist "%DSH_PATH%" (
    echo [错误]未找到 dsh.cmd，请确认dsh已经正确安装！
    pause >nul
    goto MENU
)
echo 正在启动DSH Web，仅监听本机127.0.0.1:%PORT%
echo 需要局域网访问请先选1开启转发
echo.
start "" "%DSH_PATH%" web
echo [等待]DSH服务正在初始化，请稍候...
timeout /t 8 /nobreak >nul
echo 尝试打开浏览器 http://127.0.0.1:%PORT%
start http://127.0.0.1:%PORT%
echo.
echo [提示]不要关闭弹出的dsh黑色服务窗口！
echo 局域网访问地址：http://!LOCAL_IP!:%PORT%
echo 如果拒绝连接，请等待数秒后手动刷新浏览器
echo.
pause >nul
goto MENU

:: 退出前安全校验
:EXIT_CHECK
cls
echo [退出安全校验]
call :CHECK_FORWARD
netsh advfirewall firewall show rule name="%FIREWALL_RULE%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [警告]防火墙规则仍然存在！建议执行选项2清理后再退出
)
echo.
echo 确认退出脚本？任意键继续
pause >nul
echo 脚本退出
exit
