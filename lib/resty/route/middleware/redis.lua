local setmetatable = setmetatable
local type         = type
local redis        = require('resty.redis')
local options      = {
  max_idle_timeout = 10000,
  pool_size        = 100,
  timeout          = 1000,
  keepalive        = 1000,
  port             = 6379,
  host             = '127.0.0.1'
}

local Redis   = {}
Redis.__index = Redis
Redis.__call  = (function() end)
function Redis:new(ops)
  local okay, err = nil, nil
  local redis     = redis:new()
  
  for k, v in pairs(ops) do options[k] = v end

  redis:set_timeout(options.timeout)
  
  okay, err = redis:connect(options.host, options.port)
  if not okay then
    print(err)
  end
  
  return setmetatable({ redis_context = redis, options = options }, Redis)
end
function Redis:set(key, val)
  local okay, err = self.redis_context:set(key, val)
  if not okay then
    print(err)
  end
end
function Redis:get(key)
  local res, err = self.redis_context:get(key)
  if not res then
    print(err)
  end
  
  return res
end
function Redis:close()
  if self.options.max_idle_timeout and self.options.pool_size then
    self.redis_context:set_keepalive(options.max_idle_timeout, options.pool_size)
  else
    local okay, err = self.redis_context:close()
    if not okay then
      print(err)
    end
  end
end
return Redis