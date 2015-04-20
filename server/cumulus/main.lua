--local lq = require("lsqlite3")
local redis = require('redis')

local redis_client = redis.connect('127.0.0.1', 6379)

function onStart(path)
    print('server start');
end

function onStop(path)
    print('server stop');
    local apps = redis_client:smembers('cumulus_app');
    
    for key, app in pairs(apps) do
        redis_client:del(app)
    end
end

function shuffled(tab, size)
    local n, order, res = #tab, {}, {}
     
    for i=1,n do order[i] = { rnd = math.random(), idx = i } end
    table.sort(order, function(a,b) return a.rnd < b.rnd end)
    if size > n then
        size = n
    end
    for i=1,size do res[i] = tab[order[i].idx] end
    return res
end

function onDisconnection(client)
    print(client.app.." disconnect "..client.id)
    redis_client:lrem(client.app, 1, client.id)
end

function onConnection(client, app)
    client.app = app
    --local db = lq.open('/tmp/test.db')
    --db:exec('CREATE TABLE t(a,b)')
    --db:close()
    
    print(client.id);
    redis_client:sadd('cumulus_app', app);
    redis_client:lpush(app, client.id);

    NOTE("client connect to app: "..app)

    function client:getParticipants(app)
        result = {};
        i = 0;
        for key, cur_client in cumulus.clients:pairs() do
            if (cur_client.app == app and cur_client.id ~= client.id) then
                i = i+1;
                participant = {};
                if cur_client.id then
                    participant.protocol = 'rtmfp';
                end
                
                participant.farID = cur_client.id;          
                result[i] = participant;
            end
        end 
        result = shuffled(result, 20)
        INFO(result)
        return result;
    end

    function client:getPlaylist(fileName)
        print "xxxxxxxxxxxxxx"
        local f = io.open("/usr/local/tvie/www/ms_web3/pp", "r")
        local data = f:read("*all")
        f:close()
        print "yyyyyyyyyyyy"
        return data
    end

    function client:getPiece(filename, start, len)
        local f = io.open("/usr/local/tvie/www/ms_web3/x.flv", "rb")
        f:seek("set", start)
        local x = {}
        local d = f:read(len)
        d:gsub(".",function(c) table.insert(x,c) end)
        f:close()
        return x
    end

    --sendParticipantUpdate(app, client.id);
end

function sendParticipantUpdate(app,farID)
    for key, cur_client in cumulus.clients:pairs() do
        if (cur_client.app == app) then     
            cur_client.writer:writeAMFMessage("participantChanged", farID);
        end
    end
end
