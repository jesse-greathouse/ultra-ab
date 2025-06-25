local os_getenv = os.getenv

local _M = {
  USER                = os_getenv("USER"),
  DIR                 = os_getenv("DIR"),
  BIN                 = os_getenv("BIN"),
  ETC                 = os_getenv("ETC"),
  OPT                 = os_getenv("OPT"),
  SRC                 = os_getenv("SRC"),
  TMP                 = os_getenv("TMP"),
  VAR                 = os_getenv("VAR"),
  WEB                 = os_getenv("WEB"),
  CACHE_DIR           = os_getenv("CACHE_DIR"),
  LOG_DIR             = os_getenv("LOG_DIR"),
  LOG                 = os_getenv("LOG"),
  PORT                = os_getenv("PORT"),
  REDIS_HOST          = os_getenv("REDIS_HOST"),
  REDIS_PORT          = os_getenv("REDIS_PORT"),
  REDIS_DB            = os_getenv("REDIS_DB"),
  REDIS_PASSWORD      = os_getenv("REDIS_PASSWORD"),
  APPLICATION_SECRET  = os_getenv("APPLICATION_SECRET"),
  SESSION_SECRET      = os_getenv("SESSION_SECRET"),
  IS_SSL              = os_getenv("IS_SSL"),
  SSL                 = os_getenv("SSL"),
  SSL_CERT            = os_getenv("SSL_CERT"),
  SSL_KEY             = os_getenv("SSL_KEY"),
  HOST_NAMES          = os_getenv("HOST_NAMES"),
  DB_NAME             = os_getenv("DB_NAME"),
  DB_USER             = os_getenv("DB_USER"),
  DB_PASSWORD         = os_getenv("DB_PASSWORD"),
  DB_HOST             = os_getenv("DB_HOST"),
  DB_PORT             = os_getenv("DB_PORT")
}

return _M
