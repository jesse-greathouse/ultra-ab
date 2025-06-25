local _M = {}
_M.__index = _M

function _M.new(session_id, bucket)
  return setmetatable({
    id     = session_id,
    bucket = bucket,
  }, _M)
end

function _M:get_id()
  return self.id
end

function _M:set_id(id)
  self.id = id
end

function _M:get_bucket()
  return self.bucket
end

function _M:set_bucket(bucket)
  self.bucket = bucket
end

return _M
