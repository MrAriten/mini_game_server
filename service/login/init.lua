--登录服务，用于处理登录逻辑的服务，比如账号校验。
local skynet = require "skynet"
local s = require "service"

s.client = {}
s.resp.client = function(source, fd, cmd, msg)--client是用来封装处理服务器功能的，这样可以便于之后拓展处理客户端信息的功能
    if s.client[cmd] then
        local ret_msg = s.client[cmd]( fd, msg, source)
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
    else
        skynet.error("s.resp.client fail", cmd)
    end
end

--可以再封装一个注册功能

s.client.login = function(fd, msg, source)--处理注册请求
	local playerid = tonumber(msg[2])
	local pw = tonumber(msg[3])
	local gate = source
	node = skynet.getenv("node")--获取当前节点信息
    --校验用户名密码--这里调用mysql数据库，根据playerid获取密码
	if pw ~= 123 then
		return {"login", 1, "密码错误"}
	end
	--发给agentmgr
	local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate)--call为阻塞调用
	if not isok then
		return {"login", 1, "请求mgr失败"}
	end
	--回应gate
	local isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent)--call为阻塞调用
	if not isok then
		return {"login", 1, "gate注册失败"}
	end
    skynet.error("login succ "..playerid)
    return {"login", 0, "登陆成功"}
end

s.start(...)

