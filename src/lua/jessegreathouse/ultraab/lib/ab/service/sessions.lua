local redis = require("resty.redis")
local cjson = require("cjson.safe")
local env = require("ab.env")
local session_factory = require("ab.factory.session_factory")

local _M = {}
_M.__index = _M

local SESSION_KEY_PREFIX = "ab:sessions:"

local function get_redis()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect(env.REDIS_HOST or "127.0.0.1", tonumber(env.REDIS_PORT) or 6379)
  if not ok then
    ngx.log(ngx.ERR, "[ab.service.sessions] Redis connection failed: ", err)
    return nil, err
  end
  if env.REDIS_PASSWORD and env.REDIS_PASSWORD ~= "" then
    local ok_auth, err_auth = red:auth(env.REDIS_PASSWORD)
    if not ok_auth then
      ngx.log(ngx.ERR, "[ab.service.sessions] Redis AUTH failed: ", err_auth)
      return nil, err_auth
    end
  end
  if env.REDIS_DB and env.REDIS_DB ~= "" then
    local ok_db, err_db = red:select(tonumber(env.REDIS_DB))
    if not ok_db then
      ngx.log(ngx.ERR, "[ab.service.sessions] Redis SELECT DB failed: ", err_db)
      return nil, err_db
    end
  end
  return red
end

-- serialize session to JSON string
local function serialize_session(session)
  local ok, json = pcall(cjson.encode, {
    id = session:get_id(),
    bucket = session:get_bucket(),
  })
  if ok then
    return json
  else
    ngx.log(ngx.ERR, "[ab.service.sessions] Failed to serialize session: ", tostring(json))
    return nil, "Failed to serialize session"
  end
end

-- convert a serialized JSON string to a Session instance
local function deserialize_session(json_str)
  local data, err = cjson.decode(json_str)
  if not data then
    ngx.log(ngx.ERR, "[ab.service.sessions] Failed to decode session JSON: ", err)
    return nil, "Failed to decode session JSON"
  end
  -- Use factory for construction
  return session_factory.build(data.id, data.bucket), nil
end

-- Retrieve a session by session_id, return ngx.null if not found
function _M.get(session_id)
  ngx.log(ngx.INFO, "[sessions_service] Fetching session ID: " .. tostring(session_id))
  if not session_id then
    return nil, "session_id required"
  end
  local red, err = get_redis()
  if not red then return nil, err end

  local key = SESSION_KEY_PREFIX .. session_id
  local val, err = red:get(key)
  if not val or val == ngx.null then
    return ngx.null, nil
  end

  local session, decode_err = deserialize_session(val)
  if not session then
    return nil, decode_err or "Failed to deserialize session"
  end
  return session, nil
end

-- Save a session instance to Redis (serialize as JSON)
function _M.save(session)
  ngx.log(ngx.INFO, "[sessions_service] Saving session ID: " .. tostring(session:get_id()))
  if not session or not session.get_id or not session:get_id() then
    return nil, "Valid session instance with id required"
  end
  local red, err = get_redis()
  if not red then return nil, err end

  local key = SESSION_KEY_PREFIX .. session:get_id()
  local json, ser_err = serialize_session(session)
  if not json then
    return nil, ser_err or "Failed to serialize session"
  end

  local ok, set_err = red:set(key, json)
  if not ok then
    ngx.log(ngx.ERR, "[ab.service.sessions] Failed to save session: ", set_err)
    return nil, set_err
  end

  return true, nil
end

return _M
