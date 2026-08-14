@echo off
chcp 936 >nul
setlocal enabledelayedexpansion

set FIREWALL_RULE=DSH-3080-LAN
:: 置空，脚本自动探测；如果自动识别错误，可以手动写死 set LOCAL_IP=192.168.1.19
set LOCAL_IP=
set PORT=3080
set DSH_PATH=%APPDATA%\npm\dsh.cmd

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

fltmc >nul 2>&1
set "ADMIN_OK=!errorlevel!"

:MENU
cls
echo ============= DSH局域网一体化工具 V1.3 =============
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
echo =====================================================
set /p opt=请输入选项[1-5]:

if "%opt%"=="1" goto START_FORWARD
if "%opt%"=="2" goto STOP_FORWARD
if "%opt%"=="3" goto START_DSH
if "%opt%"=="4" goto SELF_CHECK
if "%opt%"=="5" goto EXIT_CHECK

echo 输入无效，回车返回菜单
pause >nul
goto MENU

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
    echo [NO]DSH程序：未找到 dsh.cmd，请确认已安装dsh
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
