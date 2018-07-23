local server       = require "resty.websocket.server"
local setmetatable = setmetatable
local type         = type
local Websocket    = {}
Websocket.__index = Websocket
local function make(method, method_type)
  local method_metatable = {}
  if not method_type then
  elseif method_type == "table" then
    method_metatable = method
  elseif method_type == "function" then
    method_metatable.text = method
  elseif method_type == "string" then
    method_metatable = require(method)
  end
  return method_metatable
end
function Websocket:new(method)
  local ws_server, err = server:new{
    timeout         = 5000,
    max_payload_len = 65535
  }
  
  if not ws_server then print("We failed...") end
  
  local ws_table = make(method, type(method))
  
  ws_table.socket = ws_server
  ws_table.exit   = false
  
  return setmetatable(ws_table, Websocket)
end
function Websocket:timeout()
  local _, err = self.socket:send_ping()
end
function Websocket:recv_frame()
  return self.socket:recv_frame()
end
function Websocket:send_text(text)
  return self.socket:send_text(text)
end
function Websocket:close()
  self.exit = true
end
function Websocket:ping()
  self.socket:send_pong()
end
function Websocket:pong()
  self.socket:send_ping()
end
function Websocket:text(data)
  self.socket:send_text(data)
end
function Websocket:unkown(data)
  self.socket:send_text(data)
end
return function(method)
    return function(self)
      local websocket = Websocket:new(method)
      self.websocket  = websocket
      while not websocket.exit do
        local data, typ, err = websocket:recv_frame()
        if not data then
          websocket:timeout()
        else
          if not typ then typ = "unkown" end
          if websocket[typ] then 
            websocket[typ](websocket, data) 
          end
        end
      end
    end
end
-- TODO: Rewrite needed
--[[
local require      = require
local server       = require "resty.websocket.server"
local setmetatable = setmetatable
local ngx          = ngx
local var          = ngx.var
local flush        = ngx.flush
local abort        = ngx.on_abort
local kill         = ngx.thread.kill
local spawn        = ngx.thread.spawn
local exiting      = ngx.worker.exiting
local sub          = string.sub
local ipairs       = ipairs
local select       = select
local type         = type
local mt, handler  = {}, {}
local noop         = function() end
local function find(func)
    local t = type(func)
    if t == "function" then
        return { receive = func }
    elseif t == "table" then
        return func
    end
    return nil
end
function mt:__call(func)
    local self = find(func)
    return function(context, ...)
        local self = setmetatable(self, handler)
        self.n = select("#", ...)
        self.args = { ... }
        self.context = context
        self:upgrade()
        local websocket, e = server:new(self)
        if not websocket then self:fail(e) end
        self.websocket = websocket
        abort(self.abort(self))
        self:connect()
        flush(true)
        local d, t = websocket:recv_frame()
        while not websocket.fatal and not exiting() do
            if not d then
                self:timeout()
            else
                if self.receive then
                    self:receive(d, t)
                else
                    if not t then t = "unknown" end
                    if self[t] then self[t](self, d) end
                end
            end
            d, t = websocket:recv_frame()
        end
        self:close()
    end
end
handler.__index = handler
function handler:upgrading() end
function handler:upgrade()
    self.upgrade = noop
    self:upgrading();
    local host = var.host
    local s =  #var.scheme + 4
    local e = #host + s - 1
    if sub(var.http_origin or "", s, e) ~= host then
        return self:forbidden()
    end
    self:upgraded()
end
function handler:upgraded() end
function handler:connect() end
function handler:timeout()
    local websocket = self.websocket
    local _, e = websocket:send_ping()
    if websocket.fatal then
        self:error(e)
    end
end
function handler:continuation() end
function handler:text() end
function handler:binary() end
function handler:closign() end
function handler:close()
    self.close = noop
    self:closing();
    local threads = self.threads
    if threads then
        for _, v in ipairs(self.threads) do
            kill(v)
        end
    end
    self.threads = {}
    if not self.websocket.fatal then
        local b, e = self.websocket:send_close()
        if not b and self.websocket.fatal then
            return self:error(e)
        else
            return self.websocket.fatal and self:error(e) or self:exit()
        end
    end
    self:closed();
end
function handler:closed() end
function handler:forbidden()
    return self.route:forbidden()
end
function handler:error(message)
    local threads = self.threads
    if threads then
        for _, v in ipairs(self.threads) do
            kill(v)
        end
    end
    self.threads = {}
    if not self.websocket.fatal then
        local d, e = self.websocket:send_close()
        if not d and self.websocket.fatal then
            return self:fail(message or e)
        else
            return self.websocket.fatal and self:fail(message or e) or self:exit()
        end
    end
end
function handler.abort(self)
    return function() self:close() end
end
function handler:ping()
    local b, e = self.websocket:send_pong()
    if not b and self.websocket.fatal then
        if not b then return self:error(e) end
    end
end
function handler:pong() end
function handler:unknown() end
function handler:send(text)
    local b, e = self.websocket:send_text(text)
    if not b and self.websocket.fatal then
        return self:error(e)
    end
end
function handler:spawn(...)
    if not self.threads then self.threads = {} end
    self.threads[#self.threads+1] = spawn(...)
end
]]