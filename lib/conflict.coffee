{$} = require 'atom'
{Emitter} = require 'emissary'

class Side
  constructor: (@ref, @marker, @refBannerMarker) ->
    @conflict = null

  resolve: -> @conflict.resolveAs @

  wasChosen: -> @conflict.resolution is @

  editorView: -> @conflict.editorView

  editor: -> @editorView().getEditor()

  lines: ->
    fromBuffer = @marker.getTailBufferPosition()
    fromScreen = @editor().screenPositionForBufferPosition fromBuffer
    toBuffer = @marker.getHeadBufferPosition()
    toScreen = @editor().screenPositionForBufferPosition toBuffer

    lines = @editorView().renderedLines.children('.line')
    lines.slice(fromScreen.row, toScreen.row)

  refBannerLine: ->
    position = @refBannerMarker.getTailBufferPosition()
    screen = @editor().screenPositionForBufferPosition position
    @editorView().renderedLines.children('.line').eq screen.row

  refBannerOffset: ->
    position = @refBannerMarker.getTailBufferPosition()
    @editorView().pixelPositionForBufferPosition position

class OurSide extends Side

  site: -> 1

  klass: -> 'ours'

  description: -> 'our changes'

class TheirSide extends Side

  site: -> 2

  klass: -> 'theirs'

  description: -> 'their changes'

CONFLICT_REGEX = /^<{7} (\S+)\n([^]*?)={7}\n([^]*?)>{7} (\S+)\n?/mg

module.exports =
class Conflict

  Emitter.includeInto(this)

  constructor: (@ours, @theirs, @parent, @separatorMarker) ->
    ours.conflict = @
    theirs.conflict = @
    @resolution = null

  resolveAs: (side) ->
    @resolution = side
    @emit("conflict:resolved")

  @all: (editorView) ->
    results = []
    editor = editorView.getEditor()
    buffer = editor.getBuffer()
    buffer.scan CONFLICT_REGEX, (m) ->
      [x, ourRef, ourText, theirText, theirRef] = m.match
      [baseRow, baseCol] = m.range.start.toArray()

      ourLines = ourText.split /\n/
      ourRowStart = baseRow + 1
      ourRowEnd = ourRowStart + ourLines.length - 1

      ourBannerMarker = editor.markBufferRange(
        [[baseRow, 0], [ourRowStart, 0]])
      ourMarker = editor.markBufferRange(
        [[ourRowStart, 0], [ourRowEnd, 0]])

      ours = new OurSide(ourRef, ourMarker, ourBannerMarker)

      separatorMarker = editor.markBufferRange(
        [[ourRowEnd, 0], [ourRowEnd + 1, 0]])

      theirLines = theirText.split /\n/
      theirRowStart = ourRowEnd + 1
      theirRowEnd = theirRowStart + theirLines.length - 1

      theirMarker = editor.markBufferRange(
        [[theirRowStart, 0], [theirRowEnd, 0]])
      theirBannerMarker = editor.markBufferRange(
        [[theirRowEnd, 0], [m.range.end.row, 0]])

      theirs = new TheirSide(theirRef, theirMarker, theirBannerMarker)

      c = new Conflict(ours, theirs, null, separatorMarker)
      c.editorView = editorView
      results.push c
    results
