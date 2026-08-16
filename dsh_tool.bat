@echo off
setlocal enabledelayedexpansion
::======================== 全局配置区（统一修改一处全局生效） ========================
set "LOCAL_IP="
set "LOCAL_PORT=8080"
set "SHADOW_DSH_PORT=22222"
set "AUTO_CLEAN_RULE=1"
set "NPM_REGISTRY=https://registry.npmmirror.com"
set "DSH_PKG=@deepseek-ai/dsh"
:: 统一封装npx基础参数，所有调用复用
set "NPX_BASE=npx --yes --registry=%NPM_REGISTRY% %DSH_PKG%"
set "NPX_RUN=%NPX_BASE% web --port %SHADOW_DSH_PORT%"
set "LOCAL_LOOP=127.0.0.1"
::===========================================================
cls
echo ======================================================
echo        DSH 局域网一体化工具 v1.7 优化增强版
echo  前置条件：手动安装 Node.js LTS，脚本无法自动安装Node
echo ======================================================
echo [环境检测]脚本工作目录: "%cd%"
echo.
goto env_check

:recheck_env
cls
:env_check
echo -------- 前置环境检测 --------
set "NODE_OK=0"
set "NPX_OK=0"
:: 管理员校验
fltmc >nul 2>&1
if errorlevel 1 (
    echo [错误]当前不是管理员权限！端口转发netsh必须管理员，请右键脚本[以管理员身份运行]
) else (
    echo [OK]管理员权限校验通过
)
:: Node检测
where node >nul 2>&1
if errorlevel 1 (
    echo [警告]未检测到node.js
    echo 请手动下载安装 Node.js LTS https://nodejs.org/
    echo 安装完成后关闭全部cmd窗口，重新运行本脚本
) else (
    set "NODE_OK=1"
    for /f "delims=" %%v in ('node -v 2^>nul') do echo [OK]node版本: %%v
)
:: Npx检测
where npx >nul 2>&1
if errorlevel 1 (
    echo [警告]未检测到npx Node安装异常
) else (
    set "NPX_OK=1"
    for /f "delims=" %%v in ('npx -v 2^>nul') do echo [OK]npx版本: %%v
)
:: DSH端口占用检测
netstat -ano | findstr ":%SHADOW_DSH_PORT%" >nul
if not errorlevel 1 (
    echo [警告]端口%SHADOW_DSH_PORT%已经被占用！DSH服务端口冲突
) else (
    echo [OK]%SHADOW_DSH_PORT%端口空闲
)
echo ------------------------------
echo.

::======================== 内网IP自动探测函数 ========================
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
echo !curr_ip! | findstr "^127\." >nul && goto :eof
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
echo [npx启动命令] npx !NPX_RUN!
echo.

::===================== 一级主菜单 =====================
:main_menu
echo ====================== 主功能菜单 ======================
echo 1. 创建端口转发规则
echo 2. 查看本机现有端口转发
echo 3. 删除全部端口转发规则
echo 4. 一键配置DSH局域网隧道
echo 5. 启动DSH(npx)独立窗口
echo 6. 终止全部Node/DSH进程
echo 7. 重新执行环境自检
echo 8. 进入进阶设置(版本/镜像管理)
echo 9. 退出脚本
echo =====================================================
set "sel="
set /p sel="请输入功能序号:"
echo.
if "!sel!"=="1" goto add_rule
if "!sel!"=="2" goto show_rule
if "!sel!"=="3" goto clean_all
if "!sel!"=="4" goto setup_dsh_tunnel
if "!sel!"=="5" goto start_dsh_npx
if "!sel!"=="6" goto stop_dsh_node
if "!sel!"=="7" goto recheck_env
if "!sel!"=="8" goto sub_adv_setting
if "!sel!"=="9" goto exit_script
echo [错误]无效输入，请重新选择
echo.
goto main_menu

::===================== 二级进阶设置子菜单 =====================
:sub_adv_setting
cls
echo ================== 进阶设置子菜单 ==================
echo 1. 检测DSH版本信息
echo 2. 更新DSH至最新版本
echo 3. NPM镜像源管理
echo 0. 返回主菜单
echo =====================================================
set "sub_sel="
set /p sub_sel="请输入子菜单序号:"
echo.
if "!sub_sel!"=="1" goto check_dsh_ver
if "!sub_sel!"=="2" goto update_dsh
if "!sub_sel!"=="3" goto npm_registry
if "!sub_sel!"=="0" goto main_menu
echo [错误]无效子菜单序号，请重新选择
echo.
pause
goto sub_adv_setting

::======================== DSH版本检测（统一缓存版本变量，仅一次网络请求） ========================
:check_dsh_ver
echo ----- DSH 版本检测 -----
if !NODE_OK! EQU 0 (
    echo [错误]未检测Node.js，无法执行版本检测
    pause
    goto sub_adv_setting
)
if !NPX_OK! EQU 0 (
    echo [错误]npx不可用，无法执行版本检测
    pause
    goto sub_adv_setting
)
:: 一次性拉取版本，不重复请求
set "LOCAL_DSH_VER=未知"
set "LATEST_DSH_VER=未知"
echo [信息]正在拉取本地与线上版本信息，请稍候...
for /f "delims=" %%v in ('!NPX_BASE! --version 2^>nul') do set "LOCAL_DSH_VER=%%v"
for /f "delims=" %%v in ('npm view %DSH_PKG% version --registry=%NPM_REGISTRY% 2^>nul') do set "LATEST_DSH_VER=%%v"

echo.
if "!LOCAL_DSH_VER!"=="未知" (
    echo [警告]本地无DSH缓存包，需先执行启动或更新下载
) else (
    echo [OK]本地DSH版本: !LOCAL_DSH_VER!
)
if "!LATEST_DSH_VER!"=="未知" (
    echo [警告]线上版本拉取失败，网络/镜像异常，请切换镜像重试
) else (
    echo [OK]NPM线上最新版本: !LATEST_DSH_VER!
)

echo.
if not "!LOCAL_DSH_VER!"=="未知" if not "!LATEST_DSH_VER!"=="未知" (
    if "!LOCAL_DSH_VER!"=="!LATEST_DSH_VER!" (
        echo [信息]当前DSH已是最新版本，无需更新
    ) else (
        echo [提示]存在新版本，可选择子菜单2一键更新
    )
)
echo.
pause
goto sub_adv_setting

::======================== DSH一键更新（复用预查询版本，无重复请求） ========================
:update_dsh
echo ----- 更新 DSH 到最新版 -----
if !NODE_OK! EQU 0 (
    echo [错误]未检测Node.js，无法执行更新
    pause
    goto sub_adv_setting
)
if !NPX_OK! EQU 0 (
    echo [错误]npx不可用，无法执行更新
    pause
    goto sub_adv_setting
)
:: 复用版本查询逻辑，不重复请求
set "LATEST_VER=未知"
set "LOCAL_VER=未知"
echo [信息]查询线上最新版本...
for /f "delims=" %%v in ('npm view %DSH_PKG% version --registry=%NPM_REGISTRY% 2^>nul') do set "LATEST_VER=%%v"
for /f "delims=" %%v in ('!NPX_BASE! --version 2^>nul') do set "LOCAL_VER=%%v"

if "!LATEST_VER!"=="未知" (
    echo [警告]线上版本获取失败，尝试强制拉取安装包...
    goto do_update
)
if "!LOCAL_VER!"=="未知" (
    echo [信息]本地无缓存，执行首次安装
    goto do_update
)
:: 版本相同直接跳过
if "!LOCAL_VER!"=="!LATEST_VER!" (
    echo [信息]当前已是最新版本 [!LOCAL_VER!]，无需执行更新
    echo.
    pause
    goto sub_adv_setting
)
echo [信息]发现新版本: !LOCAL_VER! --> !LATEST_VER!

:do_update
echo [信息]开始拉取安装包，无进度条，请等待1~3分钟
echo [说明]使用npmmirror国内镜像加速，首次下载耗时较长
echo.
!NPX_BASE!@latest --version >nul 2>&1
if !errorlevel! equ 0 (
    echo.
    echo [成功]DSH更新完成，当前版本:
    !NPX_BASE! --version
) else (
    echo [失败]更新拉取失败
    echo 排错建议: 1.切换镜像源 2.清理npm缓存 3.检查网络
)
echo.
pause
goto sub_adv_setting

::======================== NPM镜像管理 ========================
:npm_registry
cls
echo ===== NPM镜像源管理 =====
echo 1. 切换npmmirror国内镜像
echo 2. 恢复官方npm源
echo 3. 查看当前生效镜像
echo 4. 清理npm与npx缓存
echo 0. 返回进阶菜单
echo.

set "reg_opt="
set /p reg_opt=请输入选项:

if "!reg_opt!"=="1" (
    cmd /c npm config set registry "%NPM_REGISTRY%"
    echo [OK]已切换国内镜像
    pause >nul
    goto npm_registry
)
if "!reg_opt!"=="2" (
    cmd /c npm config set registry https://registry.npmjs.org/
    echo [OK]已恢复官方源
    pause >nul
    goto npm_registry
)
if "!reg_opt!"=="3" (
    echo 当前registry地址:
    cmd /c npm config get registry
    echo.
    pause >nul
    goto npm_registry
)
if "!reg_opt!"=="4" (
    echo 正在清理npm缓存...
    cmd /c npm cache clean --force 2^>nul
    rd /s /q "%LocalAppData%\npm-cache\_npx" 2>nul
    echo [OK]缓存清理完成
    pause >nul
    goto npm_registry
)
if "!reg_opt!"=="0" goto sub_adv_setting

::无效输入兜底，防止跑飞退出
echo [错误]无效选项，请重新输入！
pause >nul
goto npm_registry
::======================== DSH启动 ========================
:start_dsh_npx
if !NODE_OK! EQU 0 (
    echo [警告]无法启动：未安装Node LTS
    pause
    goto main_menu
)
if !NPX_OK! EQU 0 (
    echo [警告]无法启动：npx异常，请修复Node安装
    pause
    goto main_menu
)
echo ----- 新开窗口启动DSH服务 -----
echo [说明]请勿关闭弹出的DSH-Service窗口
echo 本地访问地址: http://!LOCAL_LOOP!:!SHADOW_DSH_PORT!
echo.
start "DSH-Service" cmd /k "!NPX_RUN!"
echo [完成]DSH服务窗口已拉起
echo.
pause
goto main_menu

::======================== 进程终止 ========================
:stop_dsh_node
echo ----- 终止全部Node/DSH进程 -----
taskkill /f /im node.exe 2>nul
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq DSH-Service*" 2>nul
echo [完成]已强制关闭所有node与DSH窗口
echo.
pause
goto main_menu

::======================== 自定义端口转发创建（增加端口数字校验） ========================
:add_rule
echo ----- 创建自定义端口转发 -----
set "in_port="
set /p in_port="输入本机监听端口(1-65535):"
:: 端口合法性校验
echo !in_port!| findstr "^[0-9]*$" >nul || (
    echo [错误]端口必须为纯数字
    pause
    goto add_rule
)
if !in_port! LSS 1 || !in_port! GTR 65535 (
    echo [错误]端口范围仅限1~65535
    pause
    goto add_rule
)
set "dst_ip="
set /p dst_ip="输入目标内网IP:"
set "dst_port="
set /p dst_port="输入目标端口(1-65535):"
echo !dst_port!| findstr "^[0-9]*$" >nul || (
    echo [错误]目标端口必须为纯数字
    pause
    goto add_rule
)
if !dst_port! LSS 1 || !dst_port! GTR 65535 (
    echo [错误]目标端口范围仅限1~65535
    pause
    goto add_rule
)
netsh interface portproxy add v4tov4 listenport=!in_port! listenaddress=!LOCAL_IP! connectport=!dst_port! connectaddress=!dst_ip!
if !errorlevel! equ 0 (
    echo [成功]转发 !LOCAL_IP!:!in_port! --> !dst_ip!:!dst_port!
) else (
    echo [失败]创建转发失败，检查管理员/端口占用
)
echo.
pause
goto main_menu

::======================== 查看转发规则 ========================
:show_rule
echo ----- 当前全部端口转发列表 -----
netsh interface portproxy show all
echo.
pause
goto main_menu

::======================== 清空所有转发 ========================
:clean_all
echo 确认清空全部portproxy转发规则？(Y/N)
set "confirm="
set /p confirm="输入选择:"
if /i not "!confirm!"=="Y" goto main_menu
netsh interface portproxy reset
echo [完成]所有转发规则已清空
echo.
pause
goto main_menu

::======================== DSH一键隧道 ========================
:setup_dsh_tunnel
echo ----- 一键创建DSH局域网隧道 -----
netsh interface portproxy add v4tov4 listenport=!LOCAL_PORT! listenaddress=!LOCAL_IP! connectport=!SHADOW_DSH_PORT! connectaddress=!LOCAL_LOOP!
if !errorlevel! equ 0 (
    echo [成功]隧道配置完成
    echo 局域网访问地址: http://!LOCAL_IP!:!LOCAL_PORT!
) else (
    echo [失败]隧道创建失败，请确认管理员权限
)
echo.
pause
goto main_menu

::======================== 退出脚本 ========================
:exit_script
if !AUTO_CLEAN_RULE! EQU 1 (
    echo [提示]自动清理开启，正在清空全部端口转发
    netsh interface portproxy reset
)
echo 脚本即将退出
timeout /t 2 /nobreak >nul
popd
endlocal
exit /b
