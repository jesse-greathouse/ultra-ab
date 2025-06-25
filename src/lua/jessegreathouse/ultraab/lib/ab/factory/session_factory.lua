local Session = require("ab.model.session")

local _M = {}

function _M.build_from_request()
  local sid = ngx.var.cookie_ab_sid
  ngx.log(ngx.INFO, "[session_factory] Incoming ab_sid cookie: " .. tostring(sid))
  return Session.new(sid, nil)
end

function _M.build(session_id, bucket)
  return Session.new(session_id, bucket)
end

return _M
