local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"
local runconfig = require "runconfig"
local pb = require "protobuf"


conns = {} --[socket_id] = conn
players = {} --[playerid] = gateplayer

--连接类，维护客户端的连接信息
function conn()
    local m = {
        fd = nil,
        playerid = nil,
    }
    return m
end

--玩家类，维护已登录的玩家信息
function gateplayer()
    local m = {
        playerid = nil,
        agent = nil,
		conn = nil,
    }
    return m
end

local str_pack = function(cmd, msg)
    return table.concat( msg, ",").."\r\n"
end

local str_unpack = function(msgstr)
    local msg = {}

    while true do
        local arg, rest = string.match( msgstr, "(.-),(.*)")
        if arg then
            msgstr = rest
            table.insert(msg, arg)
        else
            table.insert(msg, msgstr)
            break
        end
    end

    return msg[1], msg
end

s.resp.send_by_fd = function(source, fd, msg)
    if not conns[fd] then
        return
    end
    
    --local buff = str_pack(msg[1], msg)
    --skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat( msg, ",").."}")
    local sendmsg = {
        first_element = msg[1],
        integer_elements = {},
    }
    local optional_string_found = false  -- 用于标记是否找到了可选字符串元素
    -- 从第二个元素开始，将整数元素添加到integer_elements表格中
    for i = 2, #msg do
        local element = msg[i]

        if type(element) == "string" and not optional_string_found then
            sendmsg.optional_string_element = element
            optional_string_found = true
        elseif type(element) == "number" then
            table.insert(sendmsg.integer_elements, element)
        else
            -- 处理其他情况，这里可以根据实际需要进行扩展
        end
    end
    sendmsg = pb.encode("client.Client",sendmsg)
	socket.write(fd, sendmsg)
end

s.resp.send = function(source, playerid, msg)--发现消息到客户端，这个函数由其他的sevice调用
	local gplayer = players[playerid]
    if gplayer == nil then
		return
    end
    local c = gplayer.conn
    if c == nil then
		return
    end
    
    s.resp.send_by_fd(nil, c.fd, msg)
end

s.resp.sure_agent = function(source, fd, playerid, agent)--确认是否已经登录，如果存在登录，则踢其下线，在本端上线
	local conn = conns[fd]
	if not conn then --登陆过程中已经下线
		skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登陆即下线")--call是阻塞调用！
		return false
	end
	
	conn.playerid = playerid
	
    local gplayer = gateplayer()
    gplayer.playerid = playerid
    gplayer.agent = agent
	gplayer.conn = conn
    players[playerid] = gplayer
	return true
end

local disconnect = function(fd)
    local c = conns[fd]
    if not c then
        return
    end

    local playerid = c.playerid
    --还没完成登录
    if not playerid then
        return
    --已在游戏中
    else
        players[playerid] = nil
        local reason = "断线"
        skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
    end
end

s.resp.kick = function(source, playerid)--踢出玩家，使其下线，删除其记录
    local gplayer = players[playerid]
    if not gplayer then
        return
    end

    local c = gplayer.conn
	players[playerid] = nil
	
    if not c then
        return
    end
    conns[c.fd] = nil

    disconnect(c.fd)
    socket.close(c.fd)
end






local process_msg = function(fd, msgstr) --处理从客户端传来的命令
    local cmd, msg = str_unpack(msgstr)
    skynet.error("recv "..fd.." ["..cmd.."] {"..table.concat( msg, ",").."}")

    local conn = conns[fd]
    local playerid = conn.playerid
    --尚未完成登录流程
    if not playerid then
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        local login = "login"..loginid
		skynet.send(login, "lua", "client", fd, cmd, msg)
    --完成登录流程，剩余的请求都发送给client
    else
        local gplayer = players[playerid]
        local agent = gplayer.agent
		skynet.send(agent, "lua", "client", cmd, msg)
    end
end


local process_buff = function(fd, readbuff)
    
    while true do
        local msgstr, rest = string.match( readbuff, "(.-)\r\n(.*)")--获取消息队列中最前的消息--要在这之前处理proto解码！
        if msgstr then
            readbuff = rest
            process_msg(fd, msgstr)
        else
            return readbuff
        end
    end
end

--每一条连接接收数据处理
--协议格式 cmd,arg1,arg2,...#
--这里收到的都是客户端的消息
local recv_loop = function(fd)
    socket.start(fd)
    skynet.error("socket connected " ..fd)
    local readbuff = ""
    while true do
        local recvstr = socket.read(fd) --read无第二参数，说明尽力读取，会阻塞
        if recvstr then
            local pb_data = pb.decode("client.Client", recvstr)
            --这里要proto.decode，假客户端传来的是protobuf编码的消息
            readbuff = readbuff..pb_data.first_element--将读取到的信息追加到buff上
            readbuff = process_buff(fd, readbuff)
        else
            skynet.error("socket close " ..fd) --如果没有返回为空，说明连接关闭
			disconnect(fd) --调用下线函数
            socket.close(fd)
            return
        end
    end
end

--有新连接时
local connect = function(fd, addr)--处理新到的连接
    print("connect from " .. addr .. " " .. fd)
	local c = conn()--登记已连接端口
    conns[fd] = c
    c.fd = fd
    skynet.fork(recv_loop, fd)--创建线程recv_loop函数，传入fd
end

function s.init() --服务器启动后，调用init()
    local node = skynet.getenv("node")--从config中获取当前的node节点
    local nodecfg = runconfig[node]--从当前的node节点获取配置
    local port = nodecfg.gateway[s.id].port--获取gateway的端口
    pb.register_file("service/gateway/proto/client.pb")

    local listenfd = socket.listen("0.0.0.0", port)--在当前gateway端口启动监听，开始获取客户端信息
    skynet.error("Listen socket :", "0.0.0.0", port)
    socket.start(listenfd , connect)--新连接来的时候就调用connect函数
end

s.start(...)

