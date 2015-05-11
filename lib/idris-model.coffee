spawn = require('child_process').spawn
parser = require('./parser')
utils = require('./utils')
EventEmitter = require('events').EventEmitter

class IdrisModel extends EventEmitter
  constructor: ->
    @buffer = ''
    @process = undefined
    @callbacks = {}
    @warnings = {}
    super this

  process: undefined
  requestId: 0

  start: ->
    pathToIdris = atom.config.get("atom-language-idris.pathToIdris")
    @process = spawn pathToIdris, ['--ideslave']
    @process.on 'exit', @exited.bind(this)
    @process.on 'error', @exited.bind(this)
    @process.stdout.setEncoding('utf8').on 'data', @stdout

  stop: ->
    if @process?
      @process.kill()

  stdout: (data) =>
    console.log "Data", data
    @buffer += data
    while @buffer.length > 6
      @buffer = @buffer.trimLeft()
      # We have 6 chars, which is the length of the command
      len = parseInt(@buffer.substr(0, 6), 16)
      if @buffer.length >= 6 + len
        # We also have the length of the command in the buffer, so
        # let's read in the command
        cmd = @buffer.substr(6, len).trim()
        # Remove the length + command from the buffer
        @buffer = @buffer.substr(6 + len)
        # And then we can try to parse to command..
        try
          obj = parser.parse(cmd.trim())
          @handleCommand obj
        catch e
          console.log cmd.trim()
          console.log e.toString()
      else
        # We didn't have the entire command, so let's break the
        # while-loop and wait for the next data-event
        break
    return

  handleCommand: (cmd) ->
    switch cmd.op
      when 'return'
        id = cmd.params[cmd.params.length - 1]
        ret = cmd.params[0]
        if !@callbacks[id]
          break
        if ret.op == 'ok'
          @callbacks[id] undefined, ret.params[0]
        else
          @callbacks[id]
            message: ret.params[0]
            warnings: @warnings[id]
        delete @callbacks[id]
        delete @warnings[id]
      when 'write-string'
        id = cmd.params[cmd.params.length - 1]
        msg = cmd.params[0]
        if !@callbacks[id]
          break
        @callbacks[id] undefined, undefined, msg
      when 'warning'
        id = cmd.params[cmd.params.length - 1]
        warning = cmd.params[0]
        @warnings[id].push warning
      when 'set-prompt'
        # Ignore
      else
        console.log cmd
        break
    return

  exited: ->
    console.log 'Exited'
    @process = undefined
    return

  running: ->
    ! !@process

  load: (uri, callback) ->
    id = ++@requestId
    cmd = [
      {
        op: 'load-file'
        params: [ uri ]
      }
      id
    ]
    @callbacks[id] = callback
    @warnings[id] = []
    command = utils.formatObj(cmd)

    @process.stdin.write command, 'UTF-8'
    return

cmds = [
  [
    'docs-for'
    'docsFor'
  ]
  [
    'type-of'
    'getType'
  ]
]
cmds.forEach (info) ->
  IdrisModel.prototype[info[1]] = (word, callback) ->
    id = ++@requestId
    cmd = [
      {
        op: info[0]
        params: [ word ]
      }
      id
    ]
    @callbacks[id] = callback
    @warnings[id] = []
    debugger
    @process.stdin.write utils.formatObj(cmd)
    return

  return
cmds = [
  [
    'case-split'
    'caseSplit'
  ]
  [
    'add-clause'
    'addClause'
  ]
]
cmds.forEach (info) ->

  IdrisModel.prototype[info[1]] = (line, word, callback) ->
    id = ++@requestId
    cmd = [
      {
        op: info[0]
        params: [
          line
          word
        ]
      }
      id
    ]
    @callbacks[id] = callback
    @warnings[id] = []
    debugger
    @process.stdin.write utils.formatObj(cmd)
    return

  return

IdrisModel::proofSearch = (line, word, callback) ->
  id = ++@requestId
  cmd = [
    {
      op: 'proof-search'
      params: [
        line
        word
        []
      ]
    }
    id
  ]
  @callbacks[id] = callback
  @warnings[id] = []
  debugger
  @process.stdin.write utils.formatObj(cmd)
  return

module.exports = IdrisModel

# ---
# generated by js2coffee 2.0.4
