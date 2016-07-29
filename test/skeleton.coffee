Skeleton = require "../src/skeleton"

util       = require "util"
{expect}   = require "chai"
{spy}      = require "sinon"
spy.on     = spy
extend     = util._extend


cleanup = (skeleton) ->
  process.removeListener "SIGTERM", skeleton.gracefulShutdown
  process.removeListener "uncaughtException", skeleton.errThenGracefulShutdown

describe "Skeleton", ->
  address  = "0.0.0.0"
  views    = "/src/views"
  options  = {address, views}
  skeleton = null

  beforeEach ->
    skeleton = new Skeleton options

  afterEach ->
    cleanup skeleton
    skeleton = null

  describe "instance properties", ->
    it "should have logprefix", ->
      expect(skeleton.logPrefix).to.be.a.string

    it "should have default port", ->
      expect(skeleton.port).to.be.a.number

    it "should have default shutdown timeout", ->
      expect(skeleton.shutdownTimeout).to.be.a.number

  describe "##constructor", ->
    it "should initalize Flannel", ->
      expect(skeleton.Flannel).to.exist

    it "should use an existing Flannel", ->
      winston = true
      morgan  = -> ->
      class Hipster extends Skeleton
        Flannel: {winston, morgan}
        debug: ->

      hipster = new Hipster {}
      expect(hipster.Flannel.winston).to.equal winston
      cleanup hipster

    it "should set @address", ->
      expect(skeleton.address).to.be.a "string"

    it "should set @port from env", ->
      port   = process.env.PORT = 2
      skelly = new Skeleton options
      expect(Number skelly.port).to.equal port
      delete process.env.PORT
      cleanup skelly

    it "should set @port from options", ->
      port   = 4
      skelly = new Skeleton {address, port}
      expect(skelly.port).to.equal port
      cleanup skelly

    it "should set @port from class default", ->
      expect(skeleton.port).to.equal Skeleton::port

    it "should set @app", ->
      expect(skeleton.app).to.be.a "function"

    it.skip "should use an existing @app", (done) ->

    it "should create an http server", ->
      expect(skeleton.server).to.exist

    it.skip "should use an existing http server", (done) ->
    it.skip "should use morgan logging to Flannel", (done) ->

    it "should loadMiddleware", ->
      doubleoh = spy.on Skeleton::, "loadMiddleware"
      skelly   = new Skeleton options
      expect(doubleoh.called).to.be.true
      Skeleton::loadMiddleware.restore()
      cleanup skelly

    it "should bindRoutes", ->
      doubleoh = spy.on Skeleton::, "bindRoutes"
      skelly   = new Skeleton options
      expect(doubleoh.called).to.be.true
      Skeleton::bindRoutes.restore()
      cleanup skelly

    it "should handleRouteErrors", ->
      doubleoh = spy.on Skeleton::, "handleRouteErrors"
      skelly   = new Skeleton options
      expect(doubleoh.called).to.be.true
      Skeleton::handleRouteErrors.restore()
      cleanup skelly

    it "should bind SIGTERM to gracefulShutdown", ->
      expect(process.listeners "SIGTERM").to.include skeleton.gracefulShutdown

    it "should bind uncaughtException to errThenGracefulShutdown", ->
      expect(process.listeners "uncaughtException").to.include skeleton.errThenGracefulShutdown

  describe "##loadMiddleware", ->
    it "should set views", ->
      appviews = skeleton.app.get "views"
      expect(appviews).to.equal views

    it "should set view engine to jade", ->
      viewengine = skeleton.app.get "view engine"
      expect(viewengine).to.equal "pug"

    it "should use GracefulExit.middleware", ->
      GracefulExit  = require "express-graceful-exit"
      doubleoh = spy.on GracefulExit, "middleware"
      skelly = new Skeleton options
      expect(doubleoh.called).to.be.true
      GracefulExit.middleware.restore()

    it "should use compression", ->
      found = do -> return true for fn in skeleton.app._router.stack when (String fn.handle).match /function compression/
      expect(found).to.be.true

    it "should use static file serving", ->
      o      = static: root: "/"
      o      = extend o, options
      skelly = new Skeleton o
      found = do -> return true for fn in skelly.app._router.stack when (String fn.handle).match /function serveStatic/
      expect(found).to.be.true
      cleanup skelly

    it "should use favicon set from options", ->
      o      = favicon: "./test/favicon.ico"
      o      = extend o, options
      skelly = new Skeleton o
      found = do -> return true for fn in skelly.app._router.stack when (String fn.handle).match /function favicon/
      expect(found).to.be.true
      cleanup skelly

    it "should parse JSON bodies", ->
      found = do -> return true for fn in skeleton.app._router.stack when (String fn.handle).match /function jsonParser/
      expect(found).to.be.true

    it "should parse urlencoded", ->
      found = do -> return true for fn in skeleton.app._router.stack when (String fn.handle).match /function urlencodedParser/
      expect(found).to.be.true


    it.skip "should parse urlencoded extended", ->


    it "should use a custom renderer", ->
      o      = render: `function customRender() {}`
      o      = extend o, options
      skelly = new Skeleton o
      found = do -> return true for fn in skelly.app._router.stack when (String fn.handle).match /function customRender/
      expect(found).to.be.true
      cleanup skelly

    it "should use express-rendertype renderer", ->
      found = do -> return true for fn in skeleton.app._router.stack when (String fn.handle).match /res.rendr/
      expect(found).to.be.true

  describe "##redirectToHttps", ->
    it "should not redirect if forwarded headers set to https", (done) ->
      req = headers: {"x-forwarded-proto": "https"}
      res = {}
      await skeleton.redirectToHttps req, res, defer()

      req = headers: {"forwarded": "proto=https"}
      skeleton.redirectToHttps req, res, done

    it "should redirect if not https (forwarded)", (done) ->
      req = headers: {"forwarded": "proto=http"}
      fail = -> done new Error "fail"

      await
        res = redirect: defer()
        skeleton.redirectToHttps req, res, fail

      done()

    it.skip "should not redirect if not forwarded headers if not set", (done) ->
      req = headers: {}
      res = {}

  describe "##listen", ->
    it "should bind listening error", (done) ->
      skeleton.listen()
      expect(skeleton.server.listeners "error").to.include skeleton.handleListeningError
      skeleton.close done

    it "should bind listening", (done) ->
      skeleton.listen()
      expect(skeleton.server.listeners "listening").to.include skeleton.listening
      skeleton.close done

    it "should listen", (done) ->
      doubleoh = spy.on skeleton.server, "listen"
      skeleton.listen()
      expect(doubleoh.called).to.be.true
      skeleton.server.listen.restore()
      skeleton.close done

  describe "##handleListeningError", ->
    it "should throw non-listening errors", ->
      err = new Error "non-listening"
      thrower = -> skeleton.handleListeningError err
      expect(thrower).to.throw err

    it "should decode EACCES", (done) ->
      err          = new Error "listening"
      err.syscall  = "listen"
      err.code     = "EACCES"

      {exit}       = process
      {error}      = console
      process.exit = ->

      await
        console.error = defer message
        skeleton.handleListeningError err

      expect(message).to.match /requires elevated privileges/
      process.exit  = exit
      console.error = error
      done()

    it "should decode EADDRINUSE", (done) ->
      err          = new Error "listening"
      err.syscall  = "listen"
      err.code     = "EADDRINUSE"

      {exit}       = process
      {error}      = console
      process.exit = ->

      await
        console.error = defer message
        skeleton.handleListeningError err

      expect(message).to.match /already in use/
      process.exit  = exit
      console.error = error
      done()

    it "should pass port in error message", (done) ->
      err          = new Error "listening"
      err.syscall  = "listen"
      err.code     = "EADDRINUSE"

      {exit}       = process
      {error}      = console
      process.exit = ->

      await
        console.error = defer message
        skeleton.handleListeningError err

      expect(message).to.match new RegExp skeleton.port
      process.exit  = exit
      console.error = error
      done()

    it "should throw other listening errors", ->
      err = new Error "listening"
      err.syscall  = "listen"
      thrower = -> skeleton.handleListeningError err
      expect(thrower).to.throw err


  describe "##listening", ->
    it "should log listening", (done) ->
      skeleton.server.address = -> {}

      await
        skeleton.info = defer message
        skeleton.listening()

      expect(message).to.match /listening/
      done()

  describe.skip "##bindRoutes", ->

  describe "##handleRouteErrors", ->
    it "should add express-rendertype error middleware", ->
      found = do -> return true for fn in skeleton.app._router.stack when (String fn.handle).match /Errors.makeErrFromCode/
      expect(found).to.be.true

    it.skip "should add express-rendertype fancy error middleware in dev environments", (done) ->

  describe "##close", ->
    it "should close the server", (done) ->
      doubleoh = spy.on skeleton.server, "close"
      await skeleton.close defer()
      expect(doubleoh.called).to.be.true
      done()

  describe "##errThenGracefulShutdown", ->

    it "should log an error", (done) ->
      cleanup skeleton
      skeleton.gracefulShutdown = ->

      error = new Error "shutdown"
      await
        skeleton.err = defer stack
        skeleton.errThenGracefulShutdown error

      expect(stack).to.equal error.stack
      done()

    it "should call gracefulShutdown", (done) ->
      cleanup skeleton
      skeleton.err = ->

      error = new Error "shutdown"
      await
        skeleton.gracefulShutdown = done
        skeleton.errThenGracefulShutdown error

  describe.skip "##gracefulShutdown", ->
    it "should die gracefully and log to flannel", (done) ->

  describe "##delay", ->
    it "should settimeout for timeout, fn with local context", (done) ->
      skeleton.delay 2, ->
        expect(this).to.be.instanceof Skeleton
        done()
