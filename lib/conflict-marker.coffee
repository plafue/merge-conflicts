{$} = require 'atom'
_ = require 'underscore-plus'
Conflict = require './conflict'
SideView = require './side-view'
NavigationView = require './navigation-view'

CONFLICT_CLASSES = "conflict-line resolved ours theirs parent dirty"
OUR_CLASSES = "conflict-line ours"
THEIR_CLASSES = "conflict-line theirs"
RESOLVED_CLASSES = "conflict-line resolved"
DIRTY_CLASSES = "conflict-line dirty"

module.exports =
class ConflictMarker

  constructor: (@editorView) ->
    @conflicts = Conflict.all(@editorView.getEditor())

    @coveringViews = []
    for c in @conflicts
      @coveringViews.push new SideView(c.ours, @editorView)
      @coveringViews.push new NavigationView(c.navigator, @editorView)
      @coveringViews.push new SideView(c.theirs, @editorView)

      c.on 'conflict:resolved', =>
        unresolved = (v for v in @coveringViews when not v.conflict().isResolved())
        v.reposition() for v in unresolved
        resolvedCount = @conflicts.length - Math.floor(unresolved.length / 3)
        atom.emit 'merge-conflicts:resolved',
          file: @editor().getPath(), total: @conflicts.length,
          resolved: resolvedCount

    if @conflicts
      @editorView.addClass 'conflicted'
      @remark()
      @installEvents()

  installEvents: ->
    @editorView.on 'editor:display-updated', => @remark()

    @editorView.command 'merge-conflicts:resolve-current', => @resolveCurrent()
    @editorView.command 'merge-conflicts:accept-ours', => @acceptOurs()
    @editorView.command 'merge-conflicts:accept-theirs', => @acceptTheirs()
    @editorView.command 'merge-conflicts:next-unresolved', => @nextUnresolved()
    @editorView.command 'merge-conflicts:previous-unresolved', => @previousUnresolved()

  remark: ->
    @editorView.renderedLines.children().removeClass(CONFLICT_CLASSES)
    @withConflictSideLines (lines, classes) -> lines.addClass classes

  resolveCurrent: ->
    sides = @active()

    # Do nothing if you have cursors in *both* sides of a single conflict.
    duplicates = []
    seen = {}
    for side in sides
      if side.conflict of seen
        duplicates.push side
        duplicates.push seen[side.conflict]
      seen[side.conflict] = side
    sides = _.difference sides, duplicates

    side.resolve() for side in sides

  acceptOurs: -> side.conflict.ours.resolve() for side in @active()

  acceptTheirs: -> side.conflict.theirs.resolve() for side in @active()

  nextUnresolved: ->
    final = _.last @active()
    if final?
      n = final.conflict.navigator.nextUnresolved()
      if n?
        r = n.ours.marker.getBufferRange().start
        @editor().setCursorBufferPosition r

  previousUnresolved: ->
    initial = _.first @active()
    if initial?
      p = initial.conflict.navigator.previousUnresolved()
      if p?
        r = p.ours.marker.getBufferRange().start
        @editor().setCursorBufferPosition r

  active: ->
    positions = (c.getBufferPosition() for c in @editor().getCursors())
    matching = []
    for c in @conflicts
      for p in positions
        if c.ours.marker.getBufferRange().containsPoint p
          matching.push c.ours
        if c.theirs.marker.getBufferRange().containsPoint p
          matching.push c.theirs
    matching

  editor: -> @editorView.getEditor()

  linesForMarker: (marker) ->
    fromBuffer = marker.getTailBufferPosition()
    fromScreen = @editor().screenPositionForBufferPosition fromBuffer
    toBuffer = marker.getHeadBufferPosition()
    toScreen = @editor().screenPositionForBufferPosition toBuffer

    low = @editorView.getFirstVisibleScreenRow()
    high = @editorView.getLastVisibleScreenRow()

    result = $()
    for row in _.range(fromScreen.row, toScreen.row)
      if low <= row and row <= high
        result = result.add @editorView.lineElementForScreenRow row
    result

  withConflictSideLines: (callback) ->
    for c in @conflicts
      if c.isResolved()
        callback(@linesForMarker(c.resolution.marker), RESOLVED_CLASSES)
        continue

      if c.ours.isDirty
        callback(@linesForMarker(c.ours.marker), DIRTY_CLASSES)
      else
        callback(@linesForMarker(c.ours.marker), OUR_CLASSES)

      if c.theirs.isDirty
        callback(@linesForMarker(c.theirs.marker), DIRTY_CLASSES)
      else
        callback(@linesForMarker(c.theirs.marker), THEIR_CLASSES)
