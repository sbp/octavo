## Editor Stuff

octavo = @octavo ?=
  categories: {}
  commands: {}
  editing: false
  options:
    markdownShortcuts: false
    visibleBoundaries: false
  shortcuts: {}

body = null



## Events

$ ->
  body = $ "body"
  body.keydown on_keydown
  body.keyup on_keyup
  body.mouseup on_mouseup
  body.focusin on_focusin
  body.on "paste", on_paste

keycodes =
  186: ";"
  187: "="
  188: ","
  189: "-"
  190: "."
  191: "/"
  219: "["
  220: "\\"
  221: "]"
  222: "'"

key = (e) ->
  if not e.ctrlKey
    return "Esc" if e.which is 27
    return

  if (e.which > 47) and (e.which < 58)
    "Ctrl+" + (e.which - 48)

  else if (e.which > 64) and (e.which < 91)
    "Ctrl+" + String.fromCharCode e.which

  else if e.keyCode of keycodes
    "Ctrl+" + keycodes[e.keyCode]

  else
    "Ctrl " + e.keyCode

on_keydown = (e) ->
  pressed = key e

  if "Ctrl+E" is pressed
    octavo.toggle()
    e.preventDefault()
    return false

  if octavo.editing
    position = get_position()
    if position.selected and (pressed of octavo.shortcuts)
      octavo.shortcuts[pressed] position # run in try/catch?
      e.preventDefault()
      return false

    else if e.which is 13 # Return
      if position.block
        if (node_name position.block) is "pre"
          return preformatted_br_return position, e
        else if position.block.octavoBrMode
          return regular_br_return position, e
          # TODO: why return above?

    # @@ can't move this to keyup
    unless e.which in [16, 17, 18, 91]
      update_status position

markdown_to_html = (position, pattern, tag, guard) ->
  node = position.range?.startContainer
  if node and (node.nodeType is 3) and node.textContent
    string = node.textContent.slice 0, position.range.startOffset
    return if guard?.exec string
    text = pattern.exec string
    if text
      range = rangy.createRange()
      range.setStart node, position.range.startOffset - text[0].length
      range.setEnd node, position.range.startOffset

      contents = range.extractContents()
      code = $("<#{tag}/>").text text[1]
      # code.attr "href", text[2] if text[2]
      range.insertNode document.createTextNode ""
      range.insertNode code[0]

      if position.block
        pad_block position.block

      if code[0].nextSibling?.nextSibling
        octavo.selectStart code[0].nextSibling?.nextSibling
      else
        octavo.selectEnd code[0]
      true
    else
      false

markdown_shortcuts = (position, e) ->
  if (e.which is 56) and e.shiftKey # *
    strong = markdown_to_html position, /\*\*([^*]+)\*\*$/, "strong"
    markdown_to_html position, /\*([^*]+)\*$/, "em", /\*\*([^*]+)\*$/ if not strong
  else if (e.which is 220) and e.shiftKey # |
    markdown_to_html position, /\|([^|]+)\|$/, "code"

on_keyup = (e) ->
  pressed = key e

  if octavo.editing
    # Ignore raw Ctrl
    # Should ignore raw Shift and Alt and Command too
    return if e.which is 17

    position = get_position()
    if e.which is 13
      changed = weird_to_paragraph position
      position = get_position() if changed

    else if octavo.options.markdownShortcuts
      markdown_shortcuts position, e

    unless e.which in [16, 17, 18, 91]
      update_status position # <<<

    if position.selected and (pressed of cleanups)
      cleanups[pressed] position
      e.preventDefault()
      return false

on_mouseup = (e) ->
  position = get_position()
  if octavo.editing
    update_status position # <<<
  else if e.shiftKey
    return if not position.point
    octavo.toggle()
  else if e.altKey
    octavo.on()
    e.preventDefault()
    return false

on_focusin = (e) ->
  if octavo.editing
    position = get_position()
    update_status position # <<<

on_paste = (e) ->
  if octavo.editing
    position = get_position()

    if position.balanced
      image = paste_image position, e
      if image
        e.preventDefault()
        return false
    # @@ update_status position?


## Metadata

cleanups = {}

octavo.blocks =
  div: true
  dd: true
  dt: true
  figcaption: true
  h1: true
  h2: true
  h3: true
  h4: true
  h5: true
  h6: true
  li: true
  p: true
  pre: true
  td: true
  th: true

octavo.phrases =
  a: true
  abbr: true
  b: true
  bdi: true
  bdo: true
  cite: true
  code: true
  data: true
  dfn: true
  em: true
  i: true
  kbd: true
  mark: true
  q: true
  rp: true
  rt: true
  ruby: true
  s: true
  samp: true
  small: true
  span: true
  strong: true
  sub: true
  sup: true
  time: true
  u: true
  var: true

node_name = (node) ->
  node.nodeName.toLowerCase()

get_tree = (node) ->
  tree = []
  tags = []
  element = phrase = block = null

  while node.parentElement
    if node.nodeType is 1
      tag = node_name node
      tree.push node
      tags.push tag

      if (not element)
        element = node
      if (not phrase) and (tag of octavo.phrases)
        phrase = node
      if (not block) and (tag of octavo.blocks)
        block = node
    node = node.parentElement

  [element, phrase, block, tree, tags]

get_position = () ->
  position = {}

  selection = rangy.getSelection()
  position.selection = selection
  return position if not selection.rangeCount
  position.selected = true

  range = selection.getRangeAt 0
  position.range = range

  if range
    position.balanced = range.startContainer is range.endContainer
    position.point = position.balanced and (range.startOffset is range.endOffset)

    [element, phrase, block, tree, tags] = get_tree range.startContainer

    # position.node = range.startContainer
    position.element = element
    position.phrase = phrase
    position.block = block
    position.tree = tree
    position.tags = tags

  position



## Modes

octavo.on = ->
  octavo.editing = true
  body.attr "contenteditable", "true"
  position = get_position()

  reset = $ "meta[data-octavo-reset]"
  if reset.size()
    # @@ reset code is dupliacted! search for select_first_element
    reset.remove()

    body.empty()
    document.title = "Title"
    body.append "<h1>Heading</h1>"

    set_title = (value) ->
      document.title = value
      select_first_element "h1"
      select_current_element get_position()
    octavo.input set_title, "Title"
    $("form.OctavoForm input").select()

  else if (not position.selected) or ("body" is node_name position.element)
    select_first_element "p"
    position = get_position()

  create_status()
  update_status position
  window.onbeforeunload = () ->
    "You have been editing this page."
  @

octavo.off = ->
  octavo.editing = false
  body.removeAttr "contenteditable"
  clean_interface_elements()
  window.onbeforeunload = null
  octavo._saved = null
  @

octavo.toggle = ->
  console.log ":toggle_editing"
  if not octavo.editing
    octavo.on()
  else
    octavo.off()
  @



## Caret / Selection Shortcuts

# octavo.element(node).end()
# octavo.select(node).end()
# .all() .start()
#
# octavo.selectStart(node)
# octavo.selectAll(node)
# octavo.selectEnd(node)
#
# octavo.start(node)
# octavo.end(node)
# octavo.all(node)
# node, element, range
#
# octavo.saveCaret()
# octavo.loadCaret([position])

to_node = (elem) ->
  if elem instanceof jQuery
    elem[0]
  else
    elem

to_jquery = (elem) ->
  if elem instanceof jQuery
    elem
  else
    $ elem

set_position = (elem, place) ->
  console.log ":set_position"
  node = to_node elem
  return if not node

  range = rangy.createRange()
  range.selectNodeContents node

  range.collapse true if place is "start"
  range.collapse false if place is "end"

  selection = rangy.getSelection()
  selection.setSingleRange range
  update_status get_position() # @@ not needed? events make statuses go!

# selectStartFirst
# selectFirstStart

select_first_element = (tag) ->
  elements = $ "#{tag}:first"
  if not elements.size()
    element = $("<#{tag}/>").appendTo body
    elements = elements.add element
  set_position elements[0], "start"
  update_status get_position()

octavo.selectStart = (elem) ->
  set_position elem, "start"
  @

octavo.selectEnd = (elem) ->
  set_position elem, "end"
  @

octavo.selectAll = (elem) ->
  set_position elem, "all"
  @

octavo.saveCaret = ->
  octavo._saved = rangy.saveSelection()
  @

octavo.restoreCaret = ->
  if octavo._saved
    if not octavo._saved.restored
      rangy.restoreSelection octavo._saved 
  @



## Interface

create_status = () ->
  status = $ "<div>\u2014</div>"
  status.attr
    "class": "OctavoStatus"
    "contenteditable": "false"
  status.css
    "position": "fixed"
    "top": "0"
    "left": "0"
    "width": "20%"
    "box-shadow": "0 0 32px rgba(192, 192, 192, 0.5)"
    "text-align": "right"
    "font-size": "22px"
    "height": "24px"
    "border-right": "1px solid #ccc"
    "border-bottom": "1px solid #ccc"
    "padding": "6px 24px"
    "vertical-align": "middle"
    "border-bottom-right-radius": "6px"
    "background": "#fff"

  body.append status.slideDown 100

pad = ->
  span = $("<span>\u200B</span>").attr
    "class": "OctavoPad"
    "contenteditable": "false"
  if octavo.options.visibleBoundaries
    span.css "style": "font-weight: 300; color: #ccc"
    span.text "|"
  span

# octavo.reservedBlocks
forbidden =
  "OctavoStatus": true
  "OctavoForm": true
  "OctavoMessage": true
  "OctavoCheatSheet": true
  "OctavoCommandMenu": true

# octavo.reservedPhrases
forpidden =
  "OctavoPad": true
  "rangySelectionBoundary": true

pad_block = (node) ->
  return if $(node).attr("class") of forbidden

  $("span.OctavoPad").remove()
  selector = (phrase for phrase of octavo.phrases).join(", ")
  $(selector, node).each (index, node) ->
    phrase = $ node
    return if (phrase.attr "class") of forpidden

    phrase.prepend pad()
    if (node_name node) isnt "a"
      phrase.after pad()
    else
      phrase.append pad()

update_status = (position) ->
  return if not position
  return if not position.tags

  status = $ "div.OctavoStatus"
  status.empty()

  menu = $ "div.OctavoCommandMenu"
  if menu.size()
    tag = menu.attr "data-octavo-element"
    q = $("<span>?</span>").css
      "padding": "0 3px"
      "color": "#aaa"
      "font-size": "18px"
    status.append q, " #{tag}"
    return

  if octavo.options.visibleBoundaries
    $("<span>b</span>").appendTo(status).css
      "float": "left"
      "color": "#999"
      "font-size": "90%"

  if octavo.options.markdownShortcuts
    $("<span>m</span>").appendTo(status).css
      "float": "left"
      "color": "#999"
      "font-size": "90%"

  # Annoying <a> shim
  if position.range
    if position.range.startContainer
      start = position.range.startContainer
      if (node_name start) is "a"
        length = position.range.startContainer.childNodes.length
        offset = position.range.startOffset
        if length is offset
          position.tags.shift()
          position.tree.shift()

  # This is broken if it actually reaches 8
  for i in [1...8]
    tag = position.tags.shift()
    node = position.tree.shift()

    break if not tag
    break if not node

    if tag is "body"
      if i is 1
        status.prepend "body"
      break

    a = $ "<a/>"
    a.attr "href", "#"
    a.css
      "color": "#555"
      "text-decoration": "none"
      "border": "none"
    a.css "font-weight": "400" if i is 1
    build = (a, node) ->
      a.mousedown (e) ->
        create_command_menu null, node
        e.preventDefault()
        false
    build a, node
    a.text tag

    status.prepend a
    if i < 8
      arrow = $("<span>\u279E</span>").css
        "padding": "0 3px"
        "color": "#aaa"
        "font-size": "18px"
      status.prepend " ", arrow, " "

  # .children().size() doesn't work
  if not status[0]?.childNodes?.length
    status.append("Octavo")

  # deal with phrases here
  if position.block
    pad_block position.block

clean_interface_elements = ->
  $("div.OctavoStatus").remove()
  $("form.OctavoForm").remove()
  $("div.OctavoMessage").remove()
  $("div.OctavoCheatSheet").remove()
  $("div.OctavoCommandMenu").remove()
  $("span.OctavoPad").remove()
  $("span.rangySelectionBoundary").remove()
  ###
  each (index, node) ->
    # TODO: octavo.take @
    boundary = $ node
    span = $("<span/>").appendTo boundary
    span.unwrap()
    span.remove()
  ###

octavo.input = (callback, initial = "") ->
  console.log ":octavo.input"

  # @@ cancel using Esc
  form = $ "<form/>"
  form.attr
    "class": "OctavoForm"
    "contenteditable": "false"
  form.css
    "position": "fixed"
    "margin": "0"
    "padding": "0"
    "top": "48px"
    "left": "12px"

  input = $ "<input/>"
  input.css
    "border": "1px solid #ccc"
    "font-size": "1em"
    "width": "310px"
    "padding": "3px"
    "font-size": "16px"
    "font-family": "'Helvetica Neue', Helvetica, Arial"
    "border-radius": "3px"

  if initial
    input.val initial

  form.submit (e) ->
    callback input.val()
    form.remove()
    e.preventDefault()
    false

  form.append input
  body.append form

  input.focus()

create_command_menu = (position, node) ->
  console.log ":create_command_menu"

  # This is effectively a toggle
  menus = $("div.OctavoCommandMenu")
  if menus.size()
    menus.remove()
    if octavo._saved
      rangy.restoreSelection octavo._saved
    return

  # TODO: save caret position
  octavo.saveCaret()
  pristine = get_position()

  div = $ "<div/>"
  div.attr
    "class": "OctavoCommandMenu"
    "contenteditable": "false"
  div.css
    "position": "fixed"
    "top": "48px"
    "left": "12px"
    "font-size": "14px"
    "font-weight": "300"
    "width": "318px"
    "box-shadow": "0 0 32px rgba(192, 192, 192, 0.75)"
    "padding": "0"
    "margin": "0"
    "background": "transparent"
    "font-family": "'Helvetica Neue', Helvetica, Arial, sans-serif"

  # TODO: tidy this
  if position
    if not position.point
      tag = null
      selection = true
    else
      tag = node_name node
      selection = false
  else
    tag = node_name node
    selection = false

  div.attr "data-octavo-element", tag or "Text"

  input = $("<input/>").appendTo div
  input.css
    "width": "310px"
    "padding": "3px"
    "font-size": "16px"
    "font-family": "'Helvetica Neue', Helvetica, Arial"
    "border-radius": "3px"
  results = $("<div/>").css("width", "312px").appendTo div
  results.css
    "margin-bottom": "0"
    "border-bottom": "1px solid #ccc"

  selected = 1
  octavo._current = null

  do_command = ->
    if octavo._current
      command = octavo.commands[octavo._current[0]][octavo._current[1]]
      if octavo._current[0] in ["Insert", "Selection"]
        status = command pristine
      else if octavo._current[0] is "Global"
        status = command()
      else
        status = command node
      if status isnt "selected"
        octavo.restoreCaret()

      div.remove()
      update_status get_position() # this doesn't work!
      # probably gets clobbered by another saved "get_position" in the main keyup event

  input.keydown (e) ->
    if e.which is 38 # up-arrow
      selected-- if selected > 1
      $("div", results).each (index, result) ->
        result = $ result
        index = index + 1
        if index is selected
          result.css "background": "#f0f6ff"
          category = result.attr "data-octavo-category"
          name = result.attr "data-octavo-name"
          octavo._current = [category, name]
        else
          result.css "background": "#fff"
      e.preventDefault()
      return false

    else if e.which is 40 # down-arrow
      result_items = $("div", results)
      if result_items.size() is selected
        e.preventDefault()
        return false

      selected++ if selected < 8
      $("div", results).each (index, result) ->
        result = $ result
        index = index + 1
        if index is selected
          result.css "background": "#f0f6ff"
          category = result.attr "data-octavo-category"
          name = result.attr "data-octavo-name"
          octavo._current = [category, name]
        else
          result.css "background": "#fff"
      e.preventDefault()
      return false

    else if e.which is 13 # return
      if octavo._current
        console.log "octavo._current", octavo._current
        do_command()
        e.preventDefault()
        return false

  keyup = ->
    search = input.val()
    results.empty()
    todo = 8
    for category of octavo.categories
      if selection
        continue if category isnt "Selection"
      else
        continue if category is "Selection"

      for name of octavo.categories[category]
        if name.indexOf(search) > -1
          description = octavo.categories[category][name]
          result = $ "<div/>"
          result.attr "data-octavo-category", category
          result.attr "data-octavo-name", name
          result.css
            "line-height": "12px"
            "border-top": "1px solid #ccc"
            "border-left": "1px solid #ccc"
            "border-right": "1px solid #ccc"
            "background": "#fff"
            "padding": "3px"
            "width": "100%"
            "cursor": "pointer"

          result.hover ->
            result = $(@)
            background = result.css "background"
            result.attr "data-octavo-background", background
            result.css "background": "#f0f6ff"
          , ->
            result = $(@)
            background = result.attr "data-octavo-background"
            result.css "background": background

          if (9 - todo) is selected
            result.css "background": "#f0f6ff"
            octavo._current = [category, name]

          guard = (category, name) ->
            result.click ->
              octavo._current = [category, name]
              do_command()
          guard category, name

          result.append $ "<strong>#{category}: #{name}</strong>"
          result.append $ "<br/>"
          result.append $("<span>#{description}</span>").css
            "font-size": "10px"
            "color": "#999"
          results.append result
          todo--
          # TODO: snap selected to last on list shrink/truncation
          return if not todo

    # Otherwise, we're out of the for loop
    result_items = $("div", results)
    size = result_items.size()
    if 0 < size < selected
      selected = size
      new_item = result_items.parent().find("div:last")
      new_item.css "background": "#f0f6ff"
    else if not size
      octavo._current = null

  input.keyup (e) ->
    return if e.which is 13
    return if e.which is 38
    return if e.which is 40
    keyup()

  body.append div
  input.focus()
  keyup()

message = (text, status) ->
  console.log ":message"

  # Remove any existing messages
  $("div.OctavoMessage").remove()

  div = $ "<div>\u2014</div>"
  div.attr
    "class": "OctavoMessage"
    "contenteditable": "false"
  div.css
    "position": "fixed"
    "bottom": "24px"
    "left": "24px"
    "padding": "3px 12px"
    "font-size": "18px"
    "font-weight": "300"
    "background-color": "rgb(242, 242, 242)"
    "border": "2px solid #ccc"
    "border-radius": "6px"
    "box-shadow": "3px 3px 24px rgba(242, 242, 242, 0.8)"
    "min-width": "180px"
    "text-align": "center"

  if status is "success"
    div.css
      "color": "#468847"
      "background-color": "#dff0d8"
      "border-color": "#d6e9c6"

  else if status is "failure"
    div.css
      "color": "#b94a48"
      "background-color": "#f2dede"
      "border-color": "#eed3d7"

  div.text text

  body.append div

  timeout = 3000
  if status is "failure"
    timeout = 7000

  setTimeout () ->
    div.fadeOut 1000, "swing", ->
      div.remove()
  , timeout



## Tools

octavo.change = (element, tag) ->
  element = to_jquery element
  span = $ "<span/>"
  element.append span
  element.wrap "<#{tag}/>"
  span.unwrap()
  wrapper = span.parent()
  span.remove()
  wrapper

octavo.silently = (func, args...) ->
  # TODO: use octavo.saveCaret and octavo.restoreCaret here?
  saved = rangy.saveSelection()
  result = func args...
  rangy.restoreSelection saved
  result



## Event Shortcuts

toggle_pad_visibility = (position) ->
  console.log ":toggle_pad_visibility"
  octavo.options.visibleBoundaries = not octavo.options.visibleBoundaries
  if octavo.options.visibleBoundaries
    octavo.options.markdownShortcuts = false

octavo.shortcuts["Ctrl+B"] = toggle_pad_visibility

toggle_markdown_shortcuts = (position) ->
  console.log ":toggle_markdown_shortcuts"
  octavo.options.markdownShortcuts = not octavo.options.markdownShortcuts
  if octavo.options.markdownShortcuts
    octavo.options.visibleBoundaries = false

octavo.shortcuts["Ctrl+M"] = toggle_markdown_shortcuts

# refactor?
select_current_element = (position) ->
  console.log ":select_current_element"
  if position.element
    octavo.selectAll position.element

octavo.shortcuts["Ctrl+\\"] = select_current_element

# These can be transformed *to* one of the types below
transformable_blocks =
  div: true
  figcaption: true
  h1: true
  h2: true
  h3: true
  h4: true
  h5: true
  h6: true
  p: true
  pre: true

transformable = (position, change) ->
  if position.balanced and position.block
    tag = node_name position.block
    if tag of transformable_blocks
      if tag isnt change
        return true
  false

block_to_h1 = (position) ->
  console.log ":transform_to_h1"

  if transformable position, "h1"
    octavo.silently -> octavo.change position.block, "h1"

octavo.shortcuts["Ctrl+1"] = block_to_h1

block_to_h2 = (position) ->
  console.log ":transform_to_h2"

  if transformable position, "h2"
    octavo.silently -> octavo.change position.block, "h2"

octavo.shortcuts["Ctrl+2"] = block_to_h2

block_to_h3 = (position) ->
  console.log ":transform_to_h3"

  if transformable position, "h3"
    octavo.silently -> octavo.change position.block, "h3"

octavo.shortcuts["Ctrl+3"] = block_to_h3

block_to_h4 = (position) ->
  console.log ":transform_to_h4"

  if transformable position, "h4"
    octavo.silently -> octavo.change position.block, "h4"

octavo.shortcuts["Ctrl+4"] = block_to_h4

block_to_h5 = (position) ->
  console.log ":transform_to_h5"

  if transformable position, "h5"
    octavo.silently -> octavo.change position.block, "h5"

octavo.shortcuts["Ctrl+5"] = block_to_h5

block_to_h6 = (position) ->
  console.log ":transform_to_h6"

  if transformable position, "h6"
    octavo.silently -> octavo.change position.block, "h6"

octavo.shortcuts["Ctrl+6"] = block_to_h6

block_to_list = (position) ->
  console.log ":transform_to_list"

  if transformable position, "li"
    octavo.silently ->
      block = octavo.change position.block, "li"
      block.wrap "<ul/>"

octavo.shortcuts["Ctrl+U"] = block_to_list

block_to_paragraph = (position) ->
  console.log ":transform_to_paragraph"

  if transformable position, "p"
    octavo.silently -> octavo.change position.block, "p"

octavo.shortcuts["Ctrl+P"] = block_to_paragraph

block_to_preformatted = (position) ->
  console.log ":transform_to_preformatted"

  if position.balanced and position.block
    tag = node_name position.block
    if tag isnt "pre"
      if tag of transformable_blocks
        octavo.silently -> octavo.change position.block, "pre"
    else
      p = $("<p/>").insertAfter position.block
      # Don't look at me, this is what the browser does
      # The <br> is magically removed when you type in the <p>
      p.append $ "<br>"
      octavo.selectStart p[0]

octavo.shortcuts["Ctrl+O"] = block_to_preformatted

toggle_cheat_sheet = (position) ->
  console.log ":toggle_cheat_sheet"

  sheets = $("div.OctavoCheatSheet")
  if sheets.size()
    sheets.remove()
    return

  div = $ "<div/>"
  ul = $("<ul/>").appendTo div
  ul.append "<li>Ctrl+H — Show cheat sheet</li>"
  ul.append "<li>Ctrl+\\ — Select all of the current element content</li>"
  ul.append "<li>Ctrl+U — Block to list</li>"
  ul.append "<li>Ctrl+P — Block to paragraph</li>"
  ul.append "<li>Ctrl+O — Block to preformatted</li>"
  ul.append "<li>Ctrl+A — Create anchor</li>"
  ul.append "<li>Ctrl+Y — Toggle code</li>"
  ul.append "<li>Ctrl+I — Toggle emphasis</li>"
  ul.append "<li>Ctrl+T — Toggle strong emphasis</li>"
  ul.append "<li>Ctrl+K — Insert image</li>"
  ul.append "<li>Ctrl+. — Highlight current element</li>"
  ul.append "<li>Ctrl+- — Move block up</li>"
  ul.append "<li>Ctrl+= — Move block down</li>"
  ul.append "<li>Ctrl+R — Remove enclosing element</li>"
  ul.append "<li>Ctrl+0 — Change page title</li>"
  ul.append "<li>Ctrl+] — Indent block</li>"
  ul.append "<li>Ctrl+[ — Unindent block</li>"
  ul.append "<li>Ctrl+B — Toggle edit warning, and save</li>"
  ul.append "<li>Ctrl+S — Save using HTTP PUT</li>"
  ul.append "<li>Ctrl+1 to 6 — Block to heading</li>"
  ul.append "<li>Ctrl+7 — Toggle superscript and subscript</li>"
  ul.append "<li>Ctrl+8 — Reset phrasal padding</li>"
  ul.append "<li>Ctrl+9 — Toggle BR mode</li>"

  div.attr
    "class": "OctavoCheatSheet"
    "contenteditable": "false"
  div.css
    "position": "fixed"
    "top": "24px"
    "left": "24px"
    "padding": "12px 24px"
    "font-size": "15px"
    "font-weight": "300"
    "background-color": "rgb(242, 242, 242)"
    "border": "2px solid #ccc"
    "border-radius": "6px"
    "box-shadow": "24px 24px 64px rgba(96, 96, 96, 0.25)"
    "max-width": "720px"

  body.append div

octavo.shortcuts["Ctrl+H"] = toggle_cheat_sheet

create_anchor = (position) ->
  console.log ":create_anchor"

  if position.balanced
    if position.phrase and ((node_name position.phrase) is "a")
      # Should really be for any anchor parent
      anchor = $ position.phrase
      set_anchor_href = (value) ->
        anchor.attr "href", value
        octavo.selectEnd anchor[0]
      octavo.input set_anchor_href, anchor.attr "href"

    else if not position.point
      anchor = create_phrase position, "a"
      octavo.input (value) ->
        anchor.attr "href", value
        octavo.selectEnd anchor[0]

octavo.shortcuts["Ctrl+A"] = create_anchor

toggle_code = (position) ->
  console.log ":toggle_code"
  toggle_phrase position, "code"

octavo.shortcuts["Ctrl+Y"] = toggle_code

toggle_em = (position) ->
  console.log ":toggle_em"
  toggle_phrase position, "em"

octavo.shortcuts["Ctrl+I"] = toggle_em

toggle_strong = (position) ->
  console.log ":toggle_strong"
  toggle_phrase position, "strong"

octavo.shortcuts["Ctrl+T"] = toggle_strong

insert_image = (position) ->
  console.log ":insert_image"

  if position.balanced
    contents = position.range.extractContents()
    text = $(contents).text()

    img = $ "<img/>"
    if text.length
      img.attr "alt", text

    position.range.insertNode img[0]
    octavo.input (value) ->
      img.attr "src", value
      octavo.selectEnd img[0]

octavo.shortcuts["Ctrl+K"] = insert_image

highlight_element_style = (element) ->
  return if element.attr "data-highlighted"
  element.attr "data-highlighted", "true"

  style = element.attr "style"
  if style
    element.attr "data-style-backup", style

  element.css
    "background-color": "rgba(128, 192, 0, 0.25)"
    "outline": "1px solid #9c0"
    "outline-offset": "0"

highlight_element = (position) ->
  console.log ":highlight_element"

  element = $ position.element
  highlight_element_style element

  if (node_name position.element) is "a"
    $("div.OctavoStatus").text element.attr "href"

octavo.shortcuts["Ctrl+."] = highlight_element

unhighlight_element_style = (element) ->
  element.removeAttr "data-highlighted"

  if element.attr "data-style-backup"
    element.attr "style", element.attr "data-style-backup"
    element.removeAttr "data-style-backup"
  else
    element.removeAttr "style"

unhighlight_element = (position) ->
  console.log ":unhighlight_element"

  element = $ position.element
  unhighlight_element_style element

cleanups["Ctrl+."] = unhighlight_element

move_block_up = (position) ->
  console.log ":move_block_up"

  if position.balanced
    if position.block
      current = position.block

    else if position.element
      current = position.element

    else
      return

    previous = previous_element current
    if previous
      octavo.silently -> $(current).insertBefore previous

octavo.shortcuts["Ctrl+-"] = move_block_up

move_block_down = (position) ->
  console.log ":move_block_down"

  if position.balanced
    if position.block
      current = position.block
    else if position.element
      current = position.element
    else
      return

    next = next_element current
    if next
      octavo.silently -> $(current).insertAfter next

octavo.shortcuts["Ctrl+="] = move_block_down

remove_enclosing = (position) ->
  console.log ":remove_enclosing"

  if position.balanced and position.element
    octavo.silently ->
      element = $ position.element
      span = $ "<span/>"
      element.append span

      span.unwrap()
      span.remove()

octavo.shortcuts["Ctrl+R"] = remove_enclosing

create_new_link = (position) ->
  console.log ":create_new_link"
  octavo.commands["Global"]["create new document"]()


cleanups["Ctrl+N"] = create_new_link

###
select_next_element = (position) ->
  console.log ":select_next_element"
  false

octavo.shortcuts["Ctrl+]"] = select_next_element

select_previous_element = (position) ->
  console.log ":select_previous_element"
  false

octavo.shortcuts["Ctrl+["] = select_previous_element
###

set_title = (position) ->
  console.log ":set_title"
  octavo.saveCaret()
  octavo.commands["Global"]["set title"]()

octavo.shortcuts["Ctrl+0"] = set_title

# NOTE: these could indent using margin instead
indent_block = (position) ->
  console.log ":indent_block"
  if position.block
    block = $ position.block
    left_padding = block.css "padding-left"
    if left_padding
      return if left_padding.slice(-2) isnt "px"

      px = parseFloat(left_padding) + 12
      block.css "padding-left", px
    else
      block.css "padding-left", 12

octavo.shortcuts["Ctrl+]"] = indent_block

unindent_block = (position) ->
  console.log ":unindent_block"
  if position.block
    block = $ position.block
    left_padding = block.css "padding-left"
    if left_padding
      return if left_padding.slice(-2) isnt "px"

      px = parseFloat(left_padding) - 12
      if px > 0
        block.css "padding-left", px
      else if px is 0
        block.css "padding-left", ""
    else
      block.css "padding-left", 12

octavo.shortcuts["Ctrl+["] = unindent_block

save = (edit) ->
  console.log ":save"

  # @@ add width/height to images without them
  octavo.off()
  clean_up()

  if document.location.protocol is "http:"
    console.log "Making AJAX call now"
    $.ajax
      type: "PUT"
      url: document.location.href
      data: document.documentElement.innerHTML
      dataType: "text"
      success: (msg) ->
        console.log "Success!", msg
        message "Success! Saved: " + msg.substring(0, 96), "success"
      error: (err) ->
        msg = "ERROR! Not saved. #{err.statusText}: #{err.responseText}"
        console.log "Error!", err.responseText
        message msg, "failure"
    console.log "AJAX call made"

  if edit isnt "off"
    octavo.on()

octavo.shortcuts["Ctrl+S"] = save

escape_interface = (position) ->
  menus = $("div.OctavoCommandMenu")
  if menus.size()
    # This is a toggle, and does some cleaning up
    create_command_menu()
    return

  forms = $("form.OctavoForm")
  if forms.size()
    forms.remove()
    octavo.restoreCaret()
    return

  # save_and_quit
  # "off" stops editing from being turned back on
  # This means that the message will definitely show up
  save "off"

octavo.shortcuts["Esc"] = escape_interface

toggle_br_mode = (position) ->
  console.log ":toggle_br_mode"
  if position.block
    position.block.octavoBrMode = not position.block.octavoBrMode
    if position.block.octavoBrMode
      message "Turned BR mode on", "success"
    else
      message "Turned BR mode off", "success"

octavo.shortcuts["Ctrl+9"] = toggle_br_mode

element_command_menu = (position) ->
  console.log ":element_command_menu"
  return if not position.element
  create_command_menu position, position.element

octavo.shortcuts["Ctrl+D"] = element_command_menu

block_command_menu = (position) ->
  console.log ":block_command_menu"
  return if not position.block
  create_command_menu position, position.element

octavo.shortcuts["Ctrl+G"] = block_command_menu

toggle_supersub = (position) ->
  console.log ":toggle_supersub"

  if not position.point
    contents = position.range.extractContents()
    sup = $("<sup/>").append contents
    position.range.insertNode sup[0]
    octavo.selectEnd sup[0]
  else if position.element
    tag = node_name position.element
    if tag is "sup"
      octavo.silently -> octavo.change position.element, "sub"
    else if tag is "sub"
      octavo.silently -> octavo.change position.element, "sup"

octavo.shortcuts["Ctrl+7"] = toggle_supersub



## Octavo Commands

octavo.command = (category, name, description, command) ->
  octavo.categories[category] = {} if not (category of octavo.categories)
  octavo.categories[category][name] = description
  wrapped = (obj) ->
    console.log "Command:", name
    unless category in ["Insert", "Selection"]
      obj = to_jquery obj
    # obj will be null for "Global"
    status = command obj
    return "selected" if status is "selected"
    @
  octavo.commands[category] = {} if not (category of octavo.commands)
  octavo.commands[category][name] = wrapped


# Modify Commands

# maybe select = true?
# octavo.commands["Modify"]["change"] element, select = false
# octavo.change element
# oh, it uses user-input anyway
# do need a generic "change" then

octavo.command "Modify", "change",
  "Change the tag name", (element) ->
    octavo.input (value) ->
      return if not /^[A-Za-z]+[0-9]*$/.test value
      octavo.change element, value
      octavo.restoreCaret()
    "selected"

# octavo.input (value) ->
#   ...

octavo.command "Modify", "wrap",
  "Wrap with a new element", (element) ->
    octavo.input (value) ->
      return if not /^[A-Za-z]+[0-9]*$/.test value
      element.wrap "<#{value}/>"
      octavo.restoreCaret()
    "selected"

# TODO: make remove_enclosing use this!
octavo.command "Modify", "take",
  "Remove the current element but not its children", (element) ->
    $("<span/>").appendTo(element).unwrap().remove()

octavo.command "Modify", "destroy",
  "Remove the element and its children", (element) ->
    element.remove()
    # @@ caret

octavo.command "Modify", "set id",
  "Set the id attribute", (element) ->
    set_id_attribute = (value) ->
      element.attr "id", value
      octavo.restoreCaret()

    octavo.input set_id_attribute, element.attr "id"
    "selected"

octavo.command "Modify", "add class",
  "Add a class to the element", (element) ->
    octavo.input (value) ->
      element.addClass value
      octavo.restoreCaret()
    "selected"

octavo.command "Modify", "remove class",
  "Remove a class to the element", (element) ->
    octavo.input (value) ->
      element.removeClass value
      octavo.restoreCaret()
    "selected"

octavo.command "Modify", "take descendants",
  "Remove all descendant elements, leaving text content", (element) ->
    # NOTE: Might have reference failures if there's lots of nesting
    element.find("*").each ->
      return if $(@).attr("class") of forpidden
      $("<span/>").appendTo(@).unwrap().remove()


# Style Commands

octavo.command "Style", "left align",
  "Align text to the left", (element) ->
    element.css "text-align", "left"

octavo.command "Style", "centre align",
  "Align text to centre", (element) ->
    element.css "text-align", "center"

octavo.command "Style", "right align",
  "Align text to the right", (element) ->
    element.css "text-align", "right"

octavo.command "Style", "float left",
  "Float element to the left", (element) ->
    element.css "float", "left"

octavo.command "Style", "no float",
  "Remove element float", (element) ->
    element.css "float", ""

octavo.command "Style", "float right",
  "Float element to the right", (element) ->
    element.css "float", "right"

octavo.command "Style", "small caps",
  "Use small caps font variant", (element) ->
    element.css "font-variant", "small-caps"

octavo.command "Style", "no small caps",
  "Remove small caps font variant", (element) ->
    element.css "font-variant", ""

octavo.command "Style", "box",
  "Apply box style", (element) ->
    element.css
      "border": "1px solid #ccc"
      "background-color": "#f6f6f6"

octavo.command "Style", "no box",
  "Remove box style", (element) ->
    element.css
      "border": ""
      "background-color": ""

octavo.command "Style", "no style",
  "Remove all local style", (element) ->
    element.removeAttr "style"

octavo.command "Style", "increase padding",
  "Increase padding in 12px steps", (element) ->
    padding = element.css "padding"
    if padding
      return if padding.slice(-2) isnt "px"

      px = parseFloat(padding) + 12
      element.css "padding", px
    else
      element.css "padding", 12

octavo.command "Style", "decrease padding",
  "Decrease padding in 12px steps", (element) ->
    padding = element.css "padding"
    if padding
      return if padding.slice(-2) isnt "px"

      px = parseFloat(padding) - 12
      if px > 0
        element.css "padding", px
      else if px is 0
        element.css "padding", ""
    else
      element.css "padding", 12

octavo.command "Style", "indent",
  "Increase left margin in 12px steps", (element) ->
    margin = element.css "margin-left"
    if margin
      return if margin.slice(-2) isnt "px"

      px = parseFloat(margin) + 12
      element.css "margin-left", px
    else
      element.css "margin-left", 12

octavo.command "Style", "unindent",
  "Decrease left margin in 12px steps", (element) ->
    margin = element.css "margin-left"
    if margin
      return if margin.slice(-2) isnt "px"

      px = parseFloat(margin) - 12
      if px > 0
        element.css "margin-left", px
      else if px is 0
        element.css "margin-left", ""
    else
      element.css "margin-left", 12

octavo.command "Style", "increase margin",
  "Increase margin in 12px steps", (element) ->
    margin = element.css "margin"
    if margin
      return if margin.slice(-2) isnt "px"

      px = parseFloat(margin) + 12
      element.css "margin", px
    else
      element.css "margin", 12

octavo.command "Style", "decrease margin",
  "Decrease margin in 12px steps", (element) ->
    margin = element.css "margin"
    if margin
      return if margin.slice(-2) isnt "px"

      px = parseFloat(margin) - 12
      if px > 0
        element.css "margin", px
      else if px is 0
        element.css "margin", ""
    else
      element.css "margin", 12

octavo.command "Style", "rounder borders",
  "Increase border radius in 6px steps", (element) ->
    radius = element.css "border-radius"
    if radius
      return if radius.slice(-2) isnt "px"

      px = parseFloat(radius) + 6
      element.css "border-radius", px
    else
      element.css "border-radius", 6

octavo.command "Style", "unrounder borders",
  "Decrease border radius in 6px steps", (element) ->
    radius = element.css "border-radius"
    if radius
      return if radius.slice(-2) isnt "px"

      px = parseFloat(radius) - 6
      if px > 0
        element.css "border-radius", px
      else if px is 0
        element.css "border-radius", ""
    else
      element.css "border-radius", 6


# Move Commands

octavo.command "Move", "before parent",
  "Move the current element to before its parent", (element) ->
    parent = element.parent()
    parent.before element

octavo.command "Move", "after parent",
  "Move the current element to after its parent", (element) ->
    parent = element.parent()
    parent.after element

octavo.command "Move", "into previous",
  "Move the current element into the previous element", (element) ->
    previous = previous_element element[0]
    if previous
      $(previous).append element

octavo.command "Move", "into next",
  "Move the current element into the next element", (element) ->
    next = next_element element[0]
    if next
      $(next).prepend element


# Text Commands

text_nodes = (node) ->
  nodes = []
  inner_text_nodes = (node) ->
    if node.nodeType is 3
      nodes.push node

    else if node.childNodes
      for child in node.childNodes
        inner_text_nodes child
  inner_text_nodes node
  nodes

octavo.command "Text", "show nbsp",
  "Show non-breaking spaces", (element) ->
    $(text_nodes element[0]).each ->
      @textContent = @textContent.replace "\u00A0", "\u2420"

octavo.command "Text", "hide nbsp",
  "Hide previously shown non-breaking spaces", (element) ->
    $(text_nodes element[0]).each ->
      @textContent = @textContent.replace "\u2420", "\u00A0"


# Global Commands

octavo.command "Global", "remove styles",
  "Remove all style attributes in the document", ->
    $("*[style]").each -> $(@).removeAttr "style"

octavo.command "Global", "presentational to logical",
  "Convert all presentational elements to local ones", ->
    logical =
      "i": "em"
      "b": "strong"

    presentational = (tag for tag of logical).join(", ")
    $(presentational).each ->
      $()

octavo.command "Global", "replace nbsps",
  "Replace all non-breaking spaces with spaces", ->
    $text_nodes(body[0]).each ->
      @textContent = @textContent.replace "\u00A0", " "

octavo.command "Global", "clean up",
  "Clean up extraneous DOM rubbish", ->
    clean_up()

octavo.command "Global", "set title",
  "Set the main document title", ->
    octavo.input (value) ->
      document.title = value
      octavo.restoreCaret()
    , document.title
    "selected"

octavo.command "Global", "create new document",
  "Create the document again from scratch", ->
    create_new_document = ->
      console.log ":create_new_document"
      octavo.off()

      body.empty()
      document.title = "Title"
      body.append "<h1>Heading</h1>"

      octavo.on()

      set_title = (value) ->
        document.title = value
        select_first_element "h1"
        select_current_element get_position()
      octavo.input set_title, "Document Title"
      $("form.OctavoForm input").select()

    octavo.input (value) ->
      if value is "yes"
        create_new_document()
    "selected"


# Insertion Commands

octavo.command "Insert", "table of contents",
  "Insert a table of contents at current selection", (position) ->
    ol = $("<ol/>")
    previous = false
    $("h2, h3, h4").each (index, node) ->
      header = $ node
      id = header.attr "id"
      if not id
        id = "o." + (index + 1)
        header.attr "id", id

      text = header.text()
      li = $("<li>").append "<a href=\"##{id}\">#{text}</a>"

      if not previous
        ol.append li
      else if node.tagName > previous
        $("li:last", ol).append $("<ul/>").append li
      else if node.tagName < previous
        $("ul:last", ol).parent().after li
      else
        $("li:last", ol).after li

      previous = node.tagName

    if ol.find("li").size()
      position.range.deleteContents()
      position.range.insertNode ol[0]

octavo.command "Insert", "timestamp",
  "Insert timestamp at current selection", (position) ->
    date = new Date()
    utcstring = date.toUTCString()
    utcstring = utcstring.slice 5, 22
    if utcstring[0] is "0"
      utcstring = utcstring.slice 1
    readable = document.createTextNode utcstring

    contents = position.range.extractContents()
    position.range.insertNode readable
    octavo.selectEnd readable
    "selected"


# Selection Commands

octavo.command "Selection", "wrap",
  "Wrap current selection in an element", (position) ->
    octavo.input (value) ->
      return if not /^[A-Za-z]+[0-9]*$/.test value

      contents = position.range.extractContents()
      wrapper = $ "<#{value}/>"
      position.range.insertNode wrapper[0]
      wrapper.append contents
      octavo.selectEnd wrapper[0]
    "selected"

octavo.command "Selection", "magic marker",
  "Magically transform text into HTML!", (position) ->
    range = position.range
    if range.startContainer is range.endContainer
      if range.startOffset isnt range.endOffset
        contents = range.extractContents()
        text = $(contents).text()
        div = $ "<div/>"
        div[0].innerHTML = text
        span = $("<span/>").appendTo div
        range.insertNode div[0]
        octavo.selectEnd div[0]
        span.unwrap()
        span.remove()



## Other

create_phrase = (position, tag) ->
  console.log ":create_phrase"

  contents = position.range.extractContents()
  phrase = $("<#{tag}/>").append contents
  position.range.insertNode phrase[0]

  octavo.selectEnd phrase[0]

  phrase

exit_phrase = (position, tag) ->
  console.log ":exit_phrase"
  octavo.selectStart position.phrase.nextSibling

toggle_phrase = (position, tag) ->
  console.log ":toggle_phrase"

  if position.balanced
    if tag in position.tags
      if tag is (node_name position.phrase)
        exit_phrase position, tag
    else
      create_phrase position, tag

# These two are used in the move_block_up/down shortcuts
# and in the move into previous/next commands

previous_element = (node) ->
  while node.previousSibling
    if node.previousSibling.nodeType is 1
      return node.previousSibling
    else
      node = node.previousSibling

next_element = (node) ->
  while node.nextSibling
    if node.nextSibling.nodeType is 1
      return node.nextSibling
    else
      node = node.nextSibling

weirds =
  div: true
  pre: true

# @@ document this
weird_to_paragraph = (position) ->
  # @@ This causes return from change-to-div to not work
  if position.selected
    if (node_name position.element) of weirds
      text = $(position.element).text()
      if text is ""
        block = octavo.change position.element, "p"
        if block and block[0]
          octavo.selectStart block[0]
        return true

pseudo_schemes =
  "chrome-": true
  "webkit-": true

clean_up = () ->
  screen_capture_injected = body.attr "screen_capture_injected"
  if screen_capture_injected
    body.removeAttr "screen_capture_injected"

  $("style").each (index, node) ->
    style = $ node
    if style.text() is ""
      style.remove()

  $("script").each (index, node) ->
    script = $ node
    if /_gaUserPrefs/.test script.text()
      script.remove()
    src = script.attr "src"
    if src and src.slice(0, 7) of pseudo_schemes
      script.remove()

  $("link").each (index, node) ->
    link = $ node
    href = link.attr "href"
    if href and href.slice(0, 7) of pseudo_schemes
      link.remove()

  $("img").each (index, node) ->
    img = $ node
    src = img.attr "src"
    if src and src.slice(0, 7) of pseudo_schemes
      img.remove()

  $("span").each (index, node) ->
    span = $ node
    if node.attributes.length is 1
      style = span.attr "style"
      if style
        if /line-height:[^;]+;[ \t]*$/.test style
          # @@ Generic take. The other saves caret
          # Could have a save caret wrapper too
          # with_saved_caret () ->
          inner = $("<span/>").appendTo span
          inner.unwrap()
          inner.remove()

  # Not sure what happens if there one "" text node
  # This might be what breaks a <p><table> paste
  $("p, a, code, em, strong").each (index, node) ->
    element = $ node
    if not element.contents().size()
      element.remove()

  while true
    break if not body[0].childNodes.length

    last = body[0].childNodes[body[0].childNodes.length - 1]
    if last.nodeType is 3
      if /^[ \t\r\n]+$/.test last.textContent
        $(last).remove()
      else
        break
    else
      break

  # @@ phrase with no content. it can happen!
  # make sure this comes after ZWS removal, then

  $("img").each (index, node) ->
    img = $ node
    src = img.attr "src"
    if src and src.slice(0, 5) is "data:"
      img.remove()

# Should put Markdown mode stuff here

preformatted_br_return = (position, e) ->
  children = position.block.childNodes
  last_child = position.range.endContainer is children[children.length - 1]
  node_end = position.range.endOffset is position.range.endContainer.length

  if last_child and node_end
    LF = document.createTextNode "\n\n"
  else
    LF = document.createTextNode "\n"

  position.range.deleteContents()
  position.range.insertNode LF
  octavo.selectEnd LF
  octavo.silently -> LF.parentNode.normalize()
  # If you position.block.normalize() here, it screws up. So don't do that

  e.preventDefault()
  false

regular_br_return = (position, e) ->
  octavo.silently ->
    rangy.getSelection().move "character", 1
    if get_position().block isnt position.block
      end_of_block = true
    else
      end_of_block = false

  position.range.deleteContents()
  br = $("<br/>")
  position.range.insertNode br[0]
  if end_of_block
    br2 = $("<br/>").insertAfter br
    br = br2
  br = br[0]
  if br.nextSibling
    octavo.selectStart br.nextSibling
  else
    octavo.selectEnd br.parentNode

  e.preventDefault()
  false



## Extensions

# TODO: octavo.position

paste_image = (position, e) ->
  clipboardData = e.originalEvent.clipboardData
  return if not clipboardData
  return if not clipboardData.items
  return if not clipboardData.items.length

  item = clipboardData.items[0]
  return if not item
    
  if item.type of image_formats
    blob = item.getAsFile()
    save_image position, item.type, blob
    true

image_formats =
  "image/jpeg": "jpg"
  "image/png": "png"

save_image = (position, format, blob) ->
  console.log ":save_image"

  extension = image_formats[format]

  req = new XMLHttpRequest()
  # @@ This should probably be configurable
  req.open "PUT", "/image/create/#{extension}", true
  req.onload = (e) ->
    console.log e.target.status
    console.log e.target.responseText

    if e.target.status isnt 201
      message e.target.responseText, "failure"
      return

    contents = position.range.extractContents()
    text = $(contents).text()

    img = $ "<img/>"
    if text.length
      img.attr "alt", text

    img_src = e.target.responseText.replace /[ \t\r\n]+$/, ""
    img.attr "src", img_src

    # octavo.selectEnd img[0]
    position.range.insertNode img[0]
    message "Saved as #{e.target.responseText}", "success"
  req.send blob
