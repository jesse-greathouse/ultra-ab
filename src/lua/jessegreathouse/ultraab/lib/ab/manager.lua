local env = require("ab.env")
local session_factory = require("ab.factory.session_factory")
local helpers = require("ab.helpers")
local stats_service = require("ab.service.stats")
local sessions_service = require("ab.service.sessions")

local _M = {}
_M.__index = _M

function _M.new()
  local self = setmetatable({}, _M)
  self.session = session_factory.build_from_request()
  self.stats = stats_service
  return self
end

--[[
Testing Distribution:

  This algorithm assigns each new session to one of three buckets (A, B, or C) in a way that keeps the real-world distribution of users as close as possible to your target percentages:

    - 20% of sessions should be in bucket A
    - 30% of sessions should be in bucket B
    - 50% of sessions should be in bucket C

  Here’s how it works:

    1. We check how many sessions have already been assigned to A, B, and C.
    2. We calculate the current percentages for each bucket (A, B, C).
    3. We compare the actual percentage for each bucket to its target percentage.
    4. The bucket that is furthest *below* its target gets the next user.
      - If there’s a tie (two or more buckets equally under target), we pick C first, then A, then B.
    5. If all buckets are already at or above their targets, we still pick C by default.

  This way, as more sessions come in, the system keeps the overall distribution tracking your target split, and naturally “catches up” any bucket that falls behind.
]]
function _M:select_bucket_based_on_distribution()
  -- Query current stats
  local total_sessions = self.stats.get_session_count() or 0
  local total_a = self.stats.get_bucket_a_count() or 0
  local total_b = self.stats.get_bucket_b_count() or 0
  local total_c = total_sessions - (total_a + total_b)
  if total_c < 0 then total_c = 0 end -- Defensive

  -- Calculate distributions, guarding division by zero
  local d_a, d_b, d_c = 0, 0, 0
  if total_sessions > 0 then
    d_a = total_a / total_sessions
    d_b = total_b / total_sessions
    d_c = total_c / total_sessions
  end

  -- Define targets
  local targets = { A = 0.20, B = 0.30, C = 0.50 }
  local current = { A = d_a,   B = d_b,   C = d_c  }
  local gaps = {}
  for k, target in pairs(targets) do
    gaps[k] = target - (current[k] or 0)
  end

  -- Candidates: only buckets under their target
  -- Preference order: C, A, B (so sort order matters on ties)
  local order = { "C", "A", "B" }
  local best, best_gap = "C", gaps["C"]
  for _, k in ipairs(order) do
    if gaps[k] > 0 and (best == nil or gaps[k] > best_gap or (gaps[k] == best_gap and k == order[1])) then
      best = k
      best_gap = gaps[k]
    end
  end

  -- If all buckets at/above target (gaps <= 0), still prefer "C" by default
  return best
end

-- If session ID is nil, assign new UUID and issue Set-Cookie
function _M:init_session()
  if self.session:get_id() == nil then
    local sid = helpers.generate_uuid()
    self.session:set_id(sid)

    -- Sets a cookie with the new uuid
    ngx.header["Set-Cookie"] = {
      "ab_sid=" .. sid .. "; Path=/; Max-Age=2592000; SameSite=Lax"
    }

    ngx.log(ngx.INFO, "[ab.manager] Created new session: " .. sid)
  else
    ngx.log(ngx.INFO, "[ab.manager] Existing session: " .. self.session:get_id())
  end
end

-- Handles assigning the bucket to a session that has not yet been assigned.
function _M:assign_bucket()
  -- Pick the right bucket based on current distribution
  local bucket = self:select_bucket_based_on_distribution()
  self.session:set_bucket(bucket)
  sessions_service.save(self.session)

  -- Increment stats for the assigned bucket
  if bucket == "A" then
    self.stats:incr_bucket_a_count()
  elseif bucket == "B" then
    self.stats:incr_bucket_b_count()
  end
  -- Note: Bucket "C" does not have a counter (by design)

  -- Increment overall session count
  self.stats:incr_session_count()

  return bucket
end

function _M:get_bucket()
  -- Ensure session is initialized and cookie is set if needed
  self:init_session()

  -- Try to fetch existing session from Redis
  local res, err = sessions_service.get(self.session:get_id())
  if err then
    ngx.log(ngx.ERR, "[ab.manager] Error fetching session from Redis: ", err)
    -- Optional: fail open, assign a bucket if Redis is unavailable, or fail closed depending on your risk tolerance
    return self:assign_bucket()
  end

  if res ~= ngx.null then
    -- Existing session found in Redis; return its bucket
    local bucket = res:get_bucket()
    ngx.log(ngx.INFO, "[ab.manager] Session found in Redis. Bucket: " .. tostring(bucket))
    return bucket
  end

  -- No session found, assign bucket
  ngx.log(ngx.INFO, "[ab.manager] Session not found in Redis, assigning bucket.")
  return self:assign_bucket()
end

return _M
