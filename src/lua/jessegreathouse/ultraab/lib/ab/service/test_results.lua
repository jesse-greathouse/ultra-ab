local mysql = require("resty.mysql")
local cjson = require "cjson.safe"
local env = require("ab.env")

local _M = {}
_M.__index = _M

local function coerce_did_convert(val)
  -- Accepts: 1, "1", true, "true", 0, "0", false, "false", nil
  if val == 1 or val == "1" or val == true or val == "true" then
    return 1
  end
  return 0
end

local function get_db()
  local db, err = mysql:new()
  if not db then
    ngx.log(ngx.ERR, "[ab.service.test_results] Failed to instantiate mysql: ", err)
    return nil, err
  end
  db:set_timeout(1000)

  local ok, err, errcode, sqlstate = db:connect{
    host     = env.DB_HOST or "127.0.0.1",
    port     = tonumber(env.DB_PORT) or 3306,
    database = env.DB_NAME or "ultraab",
    user     = env.DB_USER,
    password = env.DB_PASSWORD,
    charset  = "utf8mb4",
    max_packet_size = 1024 * 1024
  }
  if not ok then
    ngx.log(ngx.ERR, "[ab.service.test_results] Failed to connect to db: ", err, ": ", errcode, " ", sqlstate)
    return nil, err
  end
  return db
end

local function quote(val)
  -- Uses ngx.quote_sql_str for proper escaping
  return ngx.quote_sql_str(val)
end

-- sid (string, required)
-- bucket (string, required, should be "A", "B", or "C")
-- url (string, required)
-- did_convert (boolean, optional, default false)
function _M.create(sid, bucket, url, did_convert)
  if not sid or not bucket or not url then
    ngx.log(ngx.ERR, "[ab.service.test_results] Missing required param(s): sid=" .. tostring(sid) .. " bucket=" .. tostring(bucket) .. " url=" .. tostring(url))
    return nil, "sid, bucket, and url are required"
  end

  local did_convert_num = coerce_did_convert(did_convert)

  local db, err = get_db()
  if not db then
    ngx.log(ngx.ERR, "[ab.service.test_results] get_db() failed: " .. tostring(err))
    return nil, err
  end

  -- Use literal quoting for all values except did_convert
  local sql = string.format([[
    INSERT INTO ab_test_results (sid, bucket, did_convert, url)
    VALUES (%s, %s, %d, %s)
  ]],
    quote(sid),
    quote(bucket),
    did_convert_num,
    quote(url)
  )

  local res, err, errcode, sqlstate = db:query(sql)
  if not res then
    ngx.log(ngx.ERR, "[ab.service.test_results] Failed to insert test result: " .. tostring(err) .. " " .. tostring(errcode) .. " " .. tostring(sqlstate))
    db:set_keepalive(10000, 10)
    return nil, err
  end

  db:set_keepalive(10000, 10)
  return res.insert_id or true, nil
end


-- id (number, required)
function _M.fetch_by_id(id)
  if not id then
    return nil, "id required"
  end

  local db, err = mysql:new()
  if not db then
    ngx.log(ngx.ERR, "[test_results] failed to instantiate mysql: ", err)
    return nil, err
  end

  db:set_timeout(1000)
  local ok, err, errcode, sqlstate = db:connect{
    host     = env.DB_HOST or "127.0.0.1",
    port     = tonumber(env.DB_PORT) or 3306,
    database = env.DB_NAME,
    user     = env.DB_USER,
    password = env.DB_PASSWORD,
    charset  = "utf8mb4",
    max_packet_size = 1024 * 1024,
  }

  if not ok then
    ngx.log(ngx.ERR, "[test_results] failed to connect: ", err, ": ", errcode, " ", sqlstate)
    return nil, err
  end

  -- Use tonumber to defend against SQLi even though this field is INT/AUTO_INCREMENT
  local id_num = tonumber(id)
  if not id_num then
    return nil, "invalid id"
  end

  local sql = string.format(
    "SELECT id, sid, bucket, did_convert, url, created_at " ..
    "FROM ab_test_results " ..
    "WHERE id = %d " ..
    "LIMIT 1",
    id_num
  )

  local res, err, errcode, sqlstate = db:query(sql)
  if not res then
    ngx.log(ngx.ERR, "[test_results] fetch_by_id query failed: ", err, ": ", errcode, " ", sqlstate)
    db:set_keepalive(10000, 50)
    return nil, err
  end

  db:set_keepalive(10000, 50)

  if #res == 0 then
    return nil, "not found"
  end

  return res[1], nil
end

-- sid (string, required)
-- rows (number, optional, defaults to 20)
-- offset (number, optional, defaults to 0)
function _M.fetch_by_sid(sid, rows, offset)
  rows = tonumber(rows) or 20
  offset = tonumber(offset) or 0

  -- Defensive: if sid is nil/empty, bail out
  if not sid or sid == "" then
    return nil, "sid required"
  end

  local db, err = mysql:new()
  if not db then
    ngx.log(ngx.ERR, "[test_results] failed to instantiate mysql: ", err)
    return nil, err
  end

  db:set_timeout(1000)
  local ok, err, errcode, sqlstate = db:connect{
    host     = env.DB_HOST or "127.0.0.1",
    port     = tonumber(env.DB_PORT) or 3306,
    database = env.DB_NAME,
    user     = env.DB_USER,
    password = env.DB_PASSWORD,
    charset  = "utf8mb4",
    max_packet_size = 1024 * 1024,
  }

  if not ok then
    ngx.log(ngx.ERR, "[test_results] failed to connect: ", err, ": ", errcode, " ", sqlstate)
    return nil, err
  end

  -- Use ngx.quote_sql_str for sid (safe quoting)
  local sid_quoted = ngx.quote_sql_str(sid)
  local sql = string.format(
    "SELECT id, sid, bucket, did_convert, url, created_at " ..
    "FROM ab_test_results " ..
    "WHERE sid = %s " ..
    "ORDER BY created_at DESC " ..
    "LIMIT %d OFFSET %d",
    sid_quoted, rows, offset
  )

  local res, err, errcode, sqlstate = db:query(sql)
  if not res then
    ngx.log(ngx.ERR, "[test_results] query failed: ", err, ": ", errcode, " ", sqlstate)
    db:set_keepalive(10000, 50)
    return nil, err
  end

  db:set_keepalive(10000, 50)
  return res, nil
end

function _M.report()
  local mysql = require("resty.mysql")
  local env = require("ab.env")

  local db, err = mysql:new()
  if not db then
    ngx.log(ngx.ERR, "[test_results] failed to instantiate mysql: ", err)
    return nil, err
  end

  db:set_timeout(1000)
  local ok, err, errcode, sqlstate = db:connect{
    host     = env.DB_HOST or "127.0.0.1",
    port     = tonumber(env.DB_PORT) or 3306,
    database = env.DB_NAME,
    user     = env.DB_USER,
    password = env.DB_PASSWORD,
    charset  = "utf8mb4",
    max_packet_size = 1024 * 1024,
  }

  if not ok then
    ngx.log(ngx.ERR, "[test_results] failed to connect: ", err, ": ", errcode, " ", sqlstate)
    return nil, err
  end

  local sql = [[
    SELECT
      bucket,
      COUNT(*) AS total_sessions,
      SUM(did_convert = 1) AS total_conversions
    FROM ab_test_results
    GROUP BY bucket
    ORDER BY bucket ASC
  ]]

  local res, err, errcode, sqlstate = db:query(sql)
  if not res then
    ngx.log(ngx.ERR, "[test_results] report query failed: ", err, ": ", errcode, " ", sqlstate)
    db:set_keepalive(10000, 50)
    return nil, err
  end

  db:set_keepalive(10000, 50)
  return res, nil
end

function _M.update_by_id(id, sid, bucket, url, did_convert)
  if not id then
    return nil, "id is required"
  end
  if not sid or not bucket or not url then
    return nil, "sid, bucket, and url are required"
  end

  local did_convert_num = coerce_did_convert(did_convert)

  local db, err = get_db()
  if not db then return nil, err end

  local sql = string.format([[
    UPDATE ab_test_results
    SET sid = %s,
        bucket = %s,
        did_convert = %d,
        url = %s
    WHERE id = %d
    LIMIT 1
  ]],
    quote(sid),
    quote(bucket),
    did_convert_num,
    quote(url),
    tonumber(id)
  )

  local res, err, errcode, sqlstate = db:query(sql)
  if not res then
    ngx.log(ngx.ERR, "[ab.service.test_results] Failed to update test result: ", err, " ", errcode, " ", sqlstate)
    db:set_keepalive(10000, 10)
    return nil, err
  end

  db:set_keepalive(10000, 10)
  -- MySQL returns affected_rows, check if any row was updated
  if res.affected_rows and res.affected_rows > 0 then
    return true, nil
  else
    return nil, "not found"
  end
end

return _M
