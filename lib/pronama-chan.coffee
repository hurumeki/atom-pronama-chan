fs   = require "fs"

module.exports =
  config:
    themeDir:
      type: "string"
      default: "pronama-chan"
      description: "directory name in assetsDir"
      order: 1
    assetsDir:
      type: "string"
      default: "~/.atom/packages/atom-pronama-chan/assets/"
      description: "Path to Assets directory. (Do not modify)"
      order: 2
    images:
      type: "object"
      properties:
        background:
          type: "string"
          default: ""
        wink:
          type: "string"
          default: ""
        blink:
          type: "string"
          default: ""
      order: 3
    startVoice:
      type: "object"
      properties:
        morning:
          type: "string"
          default: ""
          description: "from 6:00 to 12:00"
        afternoon:
          type: "string"
          default: ""
          description: "from 12:00 to 18:00"
        night:
          type: "string"
          default: ""
          description: "from 18:00 to 6:00"
      order: 4
    timeSignal:
      type: "array"
      default: []
      items:
        type: "string"
      description: "Time signal voice filename. Array [0 - 23]"
      order: 5

  timer: null
  winkTimer: null
  audio: null
  themes: []

  activate: (state) ->
    @loadConfig()
    @themes = fs.readdirSync @getAssetsDirPath()
    atom.workspaceView.command "atom-pronama-chan:toggle", => @toggle()
    atom.workspaceView.command "atom-pronama-chan:roundTheme", => @roundTheme()
    atom.workspaceView.addClass("pronama-chan")
    @init()

    atom.config.observe 'atom-pronama-chan.themeDir', (newValue) =>
      @deactivate()
      @loadConfig()
      @init()

  deactivate: ->
    @audio = null
    @element.remove()
    clearInterval @timer
    clearTimeout @winkTimer

  serialize: ->

  loadConfig: ->
    if fs.existsSync (@getAssetsDirPath() + @trailingslash(atom.config.get("atom-pronama-chan.themeDir")) + "config.json")
      data = require("../assets/" + @trailingslash(atom.config.get("atom-pronama-chan.themeDir")) + "config.json")
      atom.config.setDefaults("atom-pronama-chan", data)

  init: ->
    imageDir = @getThemeDirPath() + "image/"

    @element = document.createElement('style')
    @element.textContent = ""
    if fs.existsSync (imageDir + atom.config.get("atom-pronama-chan.images.background"))
      @element.textContent += " .pronama-chan .item-views>atom-text-editor .scroll-view::after {
        background-image: url(\"" + @getImagePath("background") + "\");
      }"
    if fs.existsSync (imageDir + atom.config.get("atom-pronama-chan.images.wink"))
      @element.textContent += " .pronama-chan.pronama-wink .item-views>atom-text-editor .scroll-view::after {
        background-image: url(\"" + @getImagePath("wink") + "\");
      }"
    if fs.existsSync (imageDir + atom.config.get("atom-pronama-chan.images.blink"))
      @element.textContent += " .pronama-chan.pronama-blink .item-views>atom-text-editor .scroll-view::after {
        background-image: url(\"" + @getImagePath("blink") + "\");
      }"

    atom.workspaceView.append(@element)

    @StartVoice(new Date)

    if atom.config.get("atom-pronama-chan.timeSignal").length > 0
      @timer = setInterval =>
        @timeSignal()
      , 60000

    if atom.config.get("atom-pronama-chan.images.wink") || atom.config.get("atom-pronama-chan.images.blink")
      @winkTimer = @wink()

  toggle: ->
    atom.workspaceView.toggleClass("pronama-chan")

  roundTheme: ->
    idx = @themes.indexOf(atom.config.get("atom-pronama-chan.themeDir")) + 1

    if !@themes[idx]
      idx = 0
    atom.config.set("atom-pronama-chan.themeDir", @themes[idx])

  wink: ->
    atom.workspaceView.removeClass("pronama-blink")
    atom.workspaceView.removeClass("pronama-wink")
    setTimeout =>
        d = new Date
        if d.getSeconds() % 10 is 0
          atom.workspaceView.addClass("pronama-wink")
        else
         atom.workspaceView.addClass("pronama-blink")
        @winkTimer = setTimeout =>
          @wink()
        , Math.floor(Math.random() * 300) + 200
    , Math.floor(Math.random() * 600000)

  StartVoice: (d)->
    return if !d.getHours
    time = "night"
    if d.getHours() >= 6 && d.getHours() < 12
      time = "morning"
    else if  d.getHours() >= 12 && d.getHours() < 18
      time = "afternoon"
    @speak atom.config.get("atom-pronama-chan.startVoice." + time)

  timeSignal: ->
    d = new Date
    if d.getMinutes() is 0
      @speak atom.config.get("atom-pronama-chan.timeSignal")[d.getHours()]

  speak: (filename) ->
    return  unless atom.workspaceView.hasClass("pronama-chan")

    filepath = @getThemeDirPath() +  "voice/" + filename

    unless fs.existsSync filepath
      console.warn "Pronama Chan: no voice file:", filepath
      return

    @audio = @audio || document.createElement("audio")
    @audio.autoplay = true
    @audio.src = filepath

  getImagePath: (type) ->
      themeDir = "atom://atom-pronama-chan/assets/" +
        @trailingslash(atom.config.get("atom-pronama-chan.themeDir")) +
        "image/" + atom.config.get("atom-pronama-chan.images." + type)

  getThemeDirPath: () ->
      @getAssetsDirPath() + @trailingslash(atom.config.get("atom-pronama-chan.themeDir"))

  getAssetsDirPath: () ->
    path =  atom.config.get("atom-pronama-chan.assetsDir")
    if path[0] is "~"
      path = @getUserHome() + path.substr(1)

    @trailingslash path

  getUserHome: () ->
    if process.platform is 'win32'
      return process.env.USERPROFILE

    process.env.HOME

  trailingslash: (path) ->
    path = path.slice(0, -1) if path[path.length-1] == "/"
    path + "/"
