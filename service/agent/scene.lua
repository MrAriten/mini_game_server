
local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode = nil --scene_node
s.sname = nil --scene_id

local function random_scene()--随机选取一个战斗场景，获取其节点和id
    --选择node
    local nodes = {}
    for i, v in pairs(runconfig.scene) do
        table.insert(nodes, i)
        if runconfig.scene[mynode] then
            table.insert(nodes, mynode)
        end
    end
    local idx = math.random( 1, #nodes)
    local scenenode = nodes[idx]
    --具体场景
    local scenelist = runconfig.scene[scenenode]
    local idx = math.random( 1, #scenelist)
    local sceneid = scenelist[idx]
    return scenenode, sceneid
end

s.client.enter = function(msg)--这里本质都agent服务下的函数
    if s.sname then
        return {"enter",1,"已在场景"}
    end
    local snode, sid = random_scene()
    local sname = "scene"..sid
    local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())--转发功能到scene服务下，处理
    if not isok then
        return {"enter",1,"进入失败"}
    end
    s.snode = snode
    s.sname = sname
    return nil
end

s.client.leave = function(msg)--客户主动请求离开战场--这段代码是我写的，原来的没有
    if s.name then
        s.resp.kick()
        return {"leave",0,"退出战斗"}
    end
    return {"leave",1,"不在战场"}
end
    


--改变方向
s.client.shift  = function(msg)
    if not s.sname then
        return
    end
    local x = msg[2] or 0
    local y = msg[3] or 0
    s.call(s.snode, s.sname, "shift", s.id, x, y)--向scene发送改变方向的消息
end

s.leave_scene = function()
    --不在场景
    if not s.sname then
        return
    end
    --更新mysql的同时要删除缓存
    rds:del(playerid.."_coin")
	local res = db:query("UPDATE player SET coin = coin + 1 WHERE player_id = '"..playerid.."';")
    s.call(s.snode, s.sname, "leave", s.id)--向scene发送退出战场的消息
    s.snode = nil
    s.sname = nil
end