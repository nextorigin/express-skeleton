require "source-map-support/register"
http          = require "http"
path          = require "path"
express       = require "express"
favicon       = require "serve-favicon"
Flannel       = require "flannel"
compression   = require "compression"
bodyParser    = require "body-parser"
render        = require "express-rendertype"
GracefulExit  = require "express-graceful-exit"


class Skeleton
  logPrefix: "(Skeleton)"
  port: 3000
  shutdownTimeout: 2*60 + 10

  constructor: (@options) ->
    unless @Flannel?.winston
      @Flannel = Flannel.init Console: level: "debug"
      @Flannel.shirt this
      @debug "initializing"

    @address = @options.address
    @port    = process.env.PORT or @port
    @app     = express()

    # view engine setup
    @app.set "views", @options.views if @options.views
    @app.set "view engine", "jade"
    @app.use express.static @options.static if @options.static
    @app.use favicon path.join __dirname, "public", "favicon.ico" if @options.favicon
    @app.use GracefulExit.middleware @app

    @app.use @Flannel.morgan " info"
    @app.use compression()
    @app.use bodyParser.json()
    @app.use bodyParser.urlencoded extended: false
    @app.use render.auto "text"

    @bindRoutes()
    @handleRouteErrors()
    process.on "SIGTERM", @gracefulShutdown
    process.on "uncaughtException", @errThenGracefulShutdown

  listen: (port = @port) =>
    @server = http.createServer @app
    @server.listen port
    @server.on "error", @handleListeningError
    @server.on "listening", @listening

  handleListeningError: (error) =>
    throw error if error.syscall isnt "listen"

    bind = if typeof @port is "string" then "Pipe #{@port}" else "Port #{@port}"
    switch error.code
      when "EACCES"
        console.error "#{bind} requires elevated privileges"
        process.exit 1
      when "EADDRINUSE"
        console.error "#{bind} is already in use"
        process.exit 1
      else
        throw error

  listening: => @info "listening on #{@server.address().address}:#{@server.address().port}"

  bindRoutes: => @debug "stub for loading routes"

  handleRouteErrors: =>
    @app.use render.Errors.Error404
    @app.use render.FancyErrors.auto "text", null, @log if (@app.get "env") is "development"
    @app.use render.Errors.auto "text", null, @log

  close: (callback) =>
    @server.close callback

  errThenGracefulShutdown: (err) =>
    @err err.stack
    @gracefulShutdown()

  gracefulShutdown: =>
    GracefulExit.gracefulExitHandler @app, this,
      log: true,
      logger: (@Flannel.shirt().info.bind this),
      suicideTimeout: @shutdownTimeout * 1000

  delay: (timeout, fn) -> setTimeout (fn.bind this), timeout



module.exports = Skeleton
