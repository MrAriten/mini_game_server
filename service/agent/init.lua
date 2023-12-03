local skynet = require "skynet"
local s = require "service"
local mysql = require "skynet.db.mysql"
local redis = require "skynet.db.redis"

s.client = {}
s.gate = nil
--scene.lua模块封装的是战斗场景的逻辑设计
require "scene"
--每一个agent对应一个gate，每一个gate对应一个客户端

s.resp.client = function(source, cmd, msg)
    s.gate = source
    if s.client[cmd] then
		local ret_msg = s.client[cmd]( msg, source)
		if ret_msg then
			skynet.send(source, "lua", "send", s.id, ret_msg)
		end
    else
        skynet.error("s.resp.client fail", cmd)
    end
end

s.client.check = function(msg) --手动查看用户的数据
	--这里仅展示用户的金币，先查看缓存，缓存没有则调用mysql
	local player_coin = rds:get(playerid.."_coin")
	if not player_coin then
		local resp_db = db:query("select * from player where player_id = '"..playerid.."'");
		rds:set(playerid.."_coin",resp_db[1].coin)
		player_coin = resp_db[1].coin
	end
	return {"用户"..playerid.."当前的金币：", player_coin}
end

s.resp.kick = function(source) --退出战斗
	s.leave_scene()--调用在scene.lua中的函数
	--离开战斗进行结算
	--在此处保存角色数据
end

s.resp.exit = function(source) --关闭服务
	skynet.exit()
end

s.resp.send = function(source, msg)
	skynet.send(s.gate, "lua", "send", s.id, msg)
end

s.init = function( )
	db = mysql.connect({
        host="127.0.0.1",
        port=3306,
        database="game_server",
        user="root",
        password="Yt544128289",
        max_packet_size = 1024 * 1024,
        on_connect = nil
    })
	skynet.error(s.id)
	playerid = s.id
	rds = redis.connect({ auth = "Yt544128289", db = 1, host = "127.0.0.1", port = 6379})
end

s.start(...)