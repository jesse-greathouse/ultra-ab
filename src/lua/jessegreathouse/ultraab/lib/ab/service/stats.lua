local redis = require("resty.redis")
local env = require("ab.env")

local _M = {}
_M.__index = _M

local KEYS = {
  session_count = "ab:stats:session_count",
  bucket_a_count = "ab:stats:bucket_a_count",
  bucket_b_count = "ab:stats:bucket_b_count",
}

local function get_redis()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect(env.REDIS_HOST or "127.0.0.1", tonumber(env.REDIS_PORT) or 6379)
  if not ok then
    ngx.log(ngx.ERR, "[ab.service.stats] Redis connection failed: ", err)
    return nil, err
  end
  if env.REDIS_PASSWORD and env.REDIS_PASSWORD ~= "" then
    local ok_auth, err_auth = red:auth(env.REDIS_PASSWORD)
    if not ok_auth then
      ngx.log(ngx.ERR, "[ab.service.stats] Redis AUTH failed: ", err_auth)
      return nil, err_auth
    end
  end
  if env.REDIS_DB and env.REDIS_DB ~= "" then
    local ok_db, err_db = red:select(tonumber(env.REDIS_DB))
    if not ok_db then
      ngx.log(ngx.ERR, "[ab.service.stats] Redis SELECT DB failed: ", err_db)
      return nil, err_db
    end
  end
  return red
end

function _M.get_count(key)
  local red, err = get_redis()
  if not red then return nil, err end
  local redis_key = KEYS[key]
  if not redis_key then
    return nil, "Unknown stats key: " .. tostring(key)
  end
  local val, err = red:get(redis_key)
  if not val or val == ngx.null then
    return 0, nil -- Treat missing key as 0
  end
  return tonumber(val) or 0, nil
end

function _M.incr_count(key)
  local red, err = get_redis()
  if not red then return nil, err end
  local redis_key = KEYS[key]
  if not redis_key then
    return nil, "Unknown stats key: " .. tostring(key)
  end
  local val, err = red:incr(redis_key)
  if not val then
    ngx.log(ngx.ERR, "[ab.service.stats] Failed to increment: ", err)
    return nil, err
  end
  return tonumber(val) or 0, nil
end

-- Convenience methods
function _M.get_session_count()   return _M.get_count("session_count") end
function _M.get_bucket_a_count()  return _M.get_count("bucket_a_count") end
function _M.get_bucket_b_count()  return _M.get_count("bucket_b_count") end

function _M.incr_session_count()  return _M.incr_count("session_count") end
function _M.incr_bucket_a_count() return _M.incr_count("bucket_a_count") end
function _M.incr_bucket_b_count() return _M.incr_count("bucket_b_count") end

return _M
