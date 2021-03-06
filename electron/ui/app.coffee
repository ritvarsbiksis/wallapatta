Mod.require 'Weya.Base',
 'Weya'
 'Editor'
 'Help'
 (Base, Weya, Editor, Help) ->
  ELECTRON = require 'electron'
  REMOTE = ELECTRON.remote
  FS = require 'fs'
  PATH = require 'path'

  TEMPORARY_FILE = 'temporary.swp.ds'
  OPTIONS_FILE = 'options.json'
  TEMPORARY_SAVE_INTERVAL = 10 * 1000
  CHANGED_WATCH_INTERVAL = 500

  FILTERS = [
   name: 'Wallapatta', extensions: ['ds']
  ]


  PROTOCOLS = [
   'https://'
   'http://'
   'file://'
  ]

  window.wallapattaDecodeURL = (url) ->
   for protocol in PROTOCOLS
    if (url.substr 0, protocol.length) is protocol
     return url

   return url if not APP.folder?
   url = "/#{url}" if url[0] isnt '/'
   return "#{APP.folder.url}#{url}"

  class App extends Base
   @initialize ->
    @elems = {}
    @resources = {}
    @_editorChanged = false
    @content = ''
    @options =
     file: ''
     folder: ''
    @editor = new Editor
     openUrl: @on.openUrl
     onChanged: @on.editorChanged
     app: this

   load: (callback) ->
    @_userDataPath = REMOTE.app.getPath 'userData'
    try
     options = "#{FS.readFileSync PATH.join @_userDataPath, OPTIONS_FILE}"
     @options = JSON.parse options
    catch e
     @options =
      file: ''
      folder: ''
    @setFolder()
    @setFile()
    if @file?
     try
      @content = "#{FS.readFileSync @file.path}"
     catch e
      @content = '=====Error reading file====='
    else
     @content = null

    try
     @_tempContent = "#{FS.readFileSync PATH.join @_userDataPath, TEMPORARY_FILE}"
    catch e
     if @content?
      @_tempContent = @content
     else
      @_tempContent = @content = Help
    callback()

   @listen 'error', (e) ->
    console.error e

   @listen 'editorChanged', ->
    @_editorChanged = true

   @listen 'openUrl', (url) ->
    ELECTRON.shell.openExternal url

   render: (callback) ->
    @elems.container = document.body
    Weya elem: @elems.container, context: this, ->
     btn = (icon, event, title) ->
      @button ".btn.btn-default",
       title: title
       on: {click: @$.on[event]}
       ->
        @i ".fa.fa-#{icon}", null


     @$.elems.window = @div ".window", ->
      @header ".toolbar.toolbar-header", ->
       @div ".toolbar-actions", ->
        @div ".btn-group", ->
         btn.call this, 'folder', 'folder', 'Select images folder'
         btn.call this, 'upload', 'file', 'Open file'
         #@$.elems.save = btn.call this, 'download', 'save', 'Save file'
         @$.elems.saveBtn = @button ".btn.btn-default",
          title: "Save file"
          style: {display: 'none'}
          on: {click: @$.on.save}
          ->
           @i ".fa.fa-download.icon-text", null
           #@span ".icon.icon-download.icon-text", null
           @$.elems.saveName = @span ""

         @button ".btn.btn-default",
          title: "Save file"
          on: {click: @$.on.saveAs}
          "Save As"

         @$.elems.printBtn = btn.call this, 'print', 'print', 'Print'
         @$.elems.editBtn = @button ".btn.btn-positive",
           title: "Edit"
           on: {click: @$.on.edit}
           style: {display: 'none'}
           ->
            @i ".fa.fa-pencil", null

        @$.elems.editorToolbar = @span ""

        @button ".btn.btn-default.pull-right",
         title: "Help"
         on: {click: @$.on.help}
         ->
          @span ".icon.icon-help", null

      @div ".window-content", ->
       @$.elems.editor = @div ".editor", ''

    @editor.render @elems.editor, @elems.editorToolbar, =>
     @_watchInterval = setInterval @on.watchChanges, CHANGED_WATCH_INTERVAL
     @_saveTemInterval = setInterval @on.saveTemporary, TEMPORARY_SAVE_INTERVAL
     @editor.setText @_tempContent
     delete @_tempContent
     if @file?
      @elems.saveBtn.style.display = 'inline-block'
     @on.watchChanges()
     callback()

   @listen 'help', ->
    ELECTRON.shell.openExternal "http://wallapatta.github.io/"

   @listen 'folder', ->
    REMOTE.dialog.showOpenDialog
     properties: ['openDirectory']
     (files) =>
      @on.folderOpened null, files


   @listen 'folderOpened', (e, folders) ->
    console.log folders
    return if not folders?
    return if folders.length <= 0
    @options.folder = folders[0]
    @setFolder()
    @saveOptions()
    @editor.setText @removeTrailingSpace @editor.getText()

   @listen 'file', ->
    REMOTE.dialog.showOpenDialog
     properties: ['openFile']
     filters: FILTERS
     (files) =>
      @on.fileOpened null, files

   @listen 'fileOpened', (e, files) ->
    return if not files?
    return if files.length <= 0
    @options.file = files[0]
    @setFile()

    @content = "#{FS.readFileSync @file.path}"
    @editor.setText @content
    @_editorChanged = true
    @on.saveTemporary()
    @saveOptions()
    @elems.saveBtn.style.display = 'inline-block'
    @elems.saveName.textContent = "#{@file.name}"

   @listen 'save', ->
    @content = @removeTrailingSpace @editor.getText()
    @editor.setText @content
    FS.writeFile @file.path, @content, (err) ->
     if err?
      console.error err
     else
      console.log 'file saved'

   @listen 'saveAs', ->
    REMOTE.dialog.showSaveDialog
     filters: FILTERS
     (filename) =>
      @on.saveFile null, filename

   @listen 'saveFile', (e, file) ->
    return if not file?
    @options.file = file
    @setFile()

    @content = @removeTrailingSpace @editor.getText()
    @editor.setText @content
    @_editorChanged = true
    @on.saveTemporary()
    @saveOptions()
    @elems.saveBtn.style.display = 'inline-block'
    @elems.saveName.textContent = "#{@file.name}"
    FS.writeFile @file.path, @content, (err) ->
     if err?
      console.error err
     else
      console.log 'file saved'


   @listen 'print', ->
    @elems.printBtn.style.display = 'none'
    @elems.editBtn.style.display = 'inline-block'
    @elems.window.classList.add 'print-window'
    @editor.print()

   @listen 'edit', ->
    @elems.editBtn.style.display = 'none'
    @elems.printBtn.style.display = 'inline-block'
    @elems.window.classList.remove 'print-window'
    @editor.edit()

   removeTrailingSpace: (text) ->
    lines = text.split '\n'
    for line, i in lines
     lines[i] = line.trimRight()

    lines.join '\n'

   saveOptions: ->
    FS.writeFile (PATH.join @_userDataPath, OPTIONS_FILE),
     (JSON.stringify @options)
     (err) ->
      if err?
       console.error err
      else
       console.log 'options file saved'

   @listen 'saveTemporary', ->
    return if not @file?
    return if not @_editorChanged
    FS.writeFile (PATH.join @_userDataPath, TEMPORARY_FILE),
     @editor.getText()
     (err) ->
      if err?
       console.error err
      else
       console.log 'temporary file saved'
    @_editorChanged = false
    @elems.saveName.style.color = '#333'

   @listen 'watchChanges', ->
    return if not @file?
    if @editor.getText() isnt @content
     @elems.saveName.textContent = "#{@file.name} *"
     if @_editorChanged
      @elems.saveName.style.color = '#c00'
    else
     @elems.saveName.textContent = "#{@file.name}"

   setFolder: ->
    @folder = null
    folder = @options.folder
    return if folder is ''
    url = folder.split PATH.sep
    url.shift() while url.length > 0 and url[0] is ''
    return if not url.length > 1
    url = ['file://'].concat folder.split PATH.sep
    url = url.slice 0, url.length - 1
    @folder =
     path: folder
     url: url.join '/'

   setFile: ->
    @file = null
    file = @options.file
    return if file is ''
    @file =
     name: PATH.basename file, '.ds'
     path: file

   getResources: ->
    return null if not @folder

    results = []

    add = (path) ->
     return if path[0] is '.'
     return if path[path.length - 1] is '~'
     try
      stats = FS.statSync path
     catch e
      console.error e
      return

     if stats.isDirectory()
      try
       files = FS.readdirSync path
      catch e
       console.log error e
       return

      for file in files
       add PATH.join path, file
     else if stats.isFile()
      results.push path

    add @folder.path
    p = @folder.path.split PATH.sep
    last = p[p.length - 1]
    console.log last
    for p, i in results
     relative = PATH.relative @folder.path, p
     relative = relative.split PATH.sep
     relative.unshift last
     results[i] = relative.join '/'

    console.log results
    return results





  APP = new App()
  APP.load ->
   APP.render ->

document.addEventListener 'DOMContentLoaded', ->
 Mod.set 'Weya', Weya
 Mod.set 'Weya.Base', Weya.Base
 Mod.set 'CodeMirror', CodeMirror
 Mod.set 'CoffeeScript', CoffeeScript
 Mod.set 'HLJS', hljs

 Mod.initialize()
