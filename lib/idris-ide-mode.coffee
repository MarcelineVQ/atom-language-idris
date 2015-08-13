Logger = require './Logger'
sexpFormatter = require './utils/sexp-formatter'
parse = require './parse'
{EventEmitter} = require 'events'
{spawn} = require 'child_process'

class IdrisIdeMode extends EventEmitter
  process: null
  buffer: ''
  idrisBuffers: 0
  compilerOptions: {}

  start: (compilerOptions) ->
    pathToIdris = atom.config.get("language-idris.pathToIdris")
    parameters =
      if compilerOptions.options
        ['--ide-mode'].concat compilerOptions.options.split(' ')
      else
        ['--ide-mode']
    options =
      if compilerOptions.src
        cwd: compilerOptions.src
      else
        {}
    @process =
      spawn pathToIdris, parameters, options
    @process.on 'exit', @stopped
    @process.on 'error', @stopped
    @process.stdout.setEncoding('utf8').on 'data', @stdout

  setCompilerOptions: (options) ->
    @compilerOptions options

  send: (cmd) ->
    Logger.logOutgoingCommand cmd
    @process.stdin.write sexpFormatter.serialize(cmd)

  stop: ->
    @process?.kill()
    @stopped()

  stopped: =>
    Logger.logText 'Exited'
    @process = null

  running: ->
    !!@process

  stdout: (data) =>
    @buffer += data
    while @buffer.length > 6
      @buffer = @buffer.trimLeft().replace /\r\n/g, "\n"
      # We have 6 chars, which is the length of the command
      len = parseInt(@buffer.substr(0, 6), 16)
      if @buffer.length >= 6 + len
        # We also have the length of the command in the buffer, so
        # let's read in the command
        cmd = @buffer.substr(6, len).trim()
        Logger.logIncomingCommand cmd
        # Remove the length + command from the buffer
        @buffer = @buffer.substr(6 + len)
        # And then we can try to parse to command..
        obj = parse.parse(cmd.trim())
        @emit 'message', obj
      else
        # We didn't have the entire command, so let's break the
        # while-loop and wait for the next data-event
        break

module.exports = IdrisIdeMode
