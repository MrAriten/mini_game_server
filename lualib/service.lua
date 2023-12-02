--封装常用的功能
local skynet = require "skynet"
local cluster = require "skynet.cluster"

--这个脚本最后是return M的，也就是把M这个类作为封装
local M = {
	--类型和id，这些变量相当于C++里的类成员变量
	name = "",
	id = 0,
	--回调函数
	exit = nil,
	init = nil,
	--分发方法
	resp = {},--resp内的方法是由别的service激活的
}

--[[
function exit_dispatch()
	if M.exit then
		M.exit()
	end
	skynet.ret()
	skynet.exit()
end
--]]

--下面这些没有 M. 的函数说明不是M的类成员函数，而是一个只在脚本内生效的函数
function traceback(err)
	skynet.error(tostring(err))
	skynet.error(debug.traceback())
end

local dispatch = function(session, address, cmd, ...)--address是发送方，cmd是指令
	local fun = M.resp[cmd]--在类中查找是否有此方法
	if not fun then
		skynet.ret()
		return
	end
	
	local ret = table.pack(xpcall(fun, traceback, address, ...))--安全地调用fun方法，返回值的第一个值为是否成功调用
	local isok = ret[1]
	
	if not isok then
		skynet.ret()
		return
	end

	skynet.retpack(table.unpack(ret,2))--解析出返回的报文，并返回给发送方
end

function init()--由M.start发起调用
	skynet.dispatch("lua", dispatch)--每当收到lua信息时，调用dispatch函数
	if M.init then
		M.init()--启动服务
	end
end

--下面的 M. 开头的函数才是M的成员函数
function M.start(name, id, ...) --这个函数在每个service中都会被调用，属于是服务的启动器
	M.name = name
	if(name ~= "agent") then
		M.id = tonumber(id)--记录成员变量
    else
		M.id = id
	end
	skynet.start(init)--用skynet.start调用init函数
end

function M.call(node, srv, ...)
	local mynode = skynet.getenv("node")
	if node == mynode then
		return skynet.call(srv, "lua", ...)
	else
		return cluster.call(node, srv, ...)
	end
end

function M.send(node, srv, ...)
	local mynode = skynet.getenv("node")
	if node == mynode then
		return skynet.send(srv, "lua", ...)
	else
		return cluster.send(node, srv, ...)
	end
end


return M