local skynet = require "skynet"
local s = require "service"

--状态
STATUS = {
	LOGIN = 2,
	GAME = 3,
	LOGOUT = 4,
}

--玩家列表
local players = {}

--玩家类
function mgrplayer()
    local m = {
        playerid = nil,
		node = nil,
        agent = nil,
		status = nil,
		gate = nil,
    }
    return m
end

s.resp.reqlogin = function(source, playerid, node, gate)--处理上线请求
	local mplayer = players[playerid]
	--登陆过程禁止顶替
	if mplayer and mplayer.status == STATUS.LOGOUT then --正处于登出状态
		skynet.error("reqlogin fail, at status LOGOUT " ..playerid )
		return false
	end
	if mplayer and mplayer.status == STATUS.LOGIN then --正处于登录状态
		skynet.error("reqlogin fail, at status LOGIN " ..playerid)
		return false
	end
	--在线，顶替
	if mplayer then
		local pnode = mplayer.node
		local pagent = mplayer.agent
		local pgate = mplayer.gate
		mplayer.status = STATUS.LOGOUT,
		s.call(pnode, pagent, "kick")
		s.send(pnode, pagent, "exit")
		s.send(pnode, pgate, "send", playerid, {"kick","顶替下线"})--向客户端发送下线信息
		s.call(pnode, pgate, "kick", playerid)
	end
	--上线
	local player = mgrplayer()
	player.playerid = playerid
	player.node = node
	player.gate = gate
    player.agent = nil
	player.status = STATUS.LOGIN
	players[playerid] = player
	local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)--创建一个新的agent给客户端的gate
	player.agent = agent
	player.status = STATUS.GAME
	return true, agent
end

s.resp.reqkick = function(source, playerid, reason)--请求下线，向agent和gate发送下线命令
	local mplayer = players[playerid]
	if not mplayer then
		return false
	end
	
	if mplayer.status ~= STATUS.GAME then
		return false
	end

	local pnode = mplayer.node
	local pagent = mplayer.agent
	local pgate = mplayer.gate
	mplayer.status = STATUS.LOGOUT

	s.call(pnode, pagent, "kick")
	s.send(pnode, pagent, "exit")
	s.send(pnode, pgate, "kick", playerid)
	players[playerid] = nil

	return true
end

--情况 永不下线


s.start(...)
