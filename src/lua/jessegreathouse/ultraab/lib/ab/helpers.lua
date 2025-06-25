local _M = {}

-- Generates a simplified RFC4122 v4 UUID (not cryptographically secure)
function _M.generate_uuid()
  local random = math.random
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and random(0, 15) or random(8, 11)
    return string.format("%x", v)
  end)
end

return _M
