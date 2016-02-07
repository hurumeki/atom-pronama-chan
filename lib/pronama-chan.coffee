fs   = require "fs"
remote = require('remote')
browserWindow = remote.require('browser-window')
{ CronJob } = require 'cron'

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
    voiceVolume:
      type: "number"
      default: 0.3
      minimum: 0.0
      maximum: 1.0
      description: "voice volume. between 0.0 and 1.0"
      order: 6
    imageOpacity:
      type: "number"
      default: 0.3
      minimum: 0.0
      maximum: 1.0
      description: "image opacity. between 0.0 and 1.0"
      order: 7
    imageSize:
      type: "string"
      default: "contain"
      description: "image size. background-size property value ('contain', px, %)"
      order: 8

  timer: null
  winkTimer: null
  audio: null
  themes: []

  activate: (state) ->
    @loadConfig atom.config.get("atom-pronama-chan.themeDir")
    @themes = fs.readdirSync @getAssetsDirPath()
    atom.commands.add 'atom-text-editor', "atom-pronama-chan:toggle", => @toggle()
    atom.commands.add 'atom-text-editor', "atom-pronama-chan:roundTheme", => @roundTheme()
    atom.views.getView(atom.workspace).classList.add("pronama-chan")
    atom.notifications.onDidAddNotification (notification) => @changeFace(notification)

    atom.config.onDidChange 'atom-pronama-chan.imageOpacity', ({newValue, oldValue}) => @reload()
    atom.config.onDidChange 'atom-pronama-chan.imageSize', ({newValue, oldValue}) => @reload()

    @init()

    @startVoice(new Date)

  deactivate: ->
    @audio = null
    @element.remove()
    @timer?.stop()
    @timer = null
    clearTimeout @winkTimer

  serialize: ->

  loadConfig: (themeDir)->
    if fs.existsSync (@getAssetsDirPath() + @trailingslash(themeDir) + "config.json")
      data = require("../assets/" + @trailingslash(themeDir) + "config.json")
      atom.config.setDefaults("atom-pronama-chan", data)

  init: ->
    imageDir = @getThemeDirPath() + "image/"

    @element = document.createElement('style')
    @element.textContent = " .pronama-chan .item-views /deep/ .editor--private:not(.mini) .scroll-view::after {
      opacity: " + atom.config.get("atom-pronama-chan.imageOpacity").toString() + ";
      background-size: " + atom.config.get("atom-pronama-chan.imageSize") + ";
    }"

    if fs.existsSync (imageDir + atom.config.get("atom-pronama-chan.images.background"))
      @element.textContent += " .pronama-chan .item-views /deep/ .editor--private:not(.mini) .scroll-view::after {
        background-image: url(\"" + @getImageUrl("background") + "\");
      }"

    ["wink", "blink", "happy", "sad", "surprise", "usual"].forEach (item, i) =>
      @element.textContent += " .pronama-chan.pronama-#{item} .item-views /deep/ .editor--private:not(.mini) .scroll-view::after {
        background-image: url(\"" + @getImageUrl(item) + "\");
      }"
      if atom.config.get("atom-pronama-chan.images." + item) &&
         fs.existsSync (imageDir + atom.config.get("atom-pronama-chan.images." + item))
        img = document.createElement('img')
        img.src = @getImageUrl(item)

    atom.views.getView(atom.workspace).appendChild(@element)

    if atom.config.get("atom-pronama-chan.timeSignal").length > 0
      @timer = new CronJob '00 00 * * * *', @timeSignal.bind(@), null, true

    if atom.config.get("atom-pronama-chan.images.wink") || atom.config.get("atom-pronama-chan.images.blink")
      @winkTimer = @wink()

  reload: ->
    @deactivate()
    @loadConfig atom.config.get("atom-pronama-chan.themeDir")
    @init()

  toggle: ->
    atom.views.getView(atom.workspace).classList.toggle("pronama-chan")

  roundTheme: ->
    idx = @themes.indexOf(atom.config.get("atom-pronama-chan.themeDir")) + 1

    if !@themes[idx]
      idx = 0
    atom.config.set("atom-pronama-chan.themeDir", @themes[idx])
    @reload()
    @startVoice(new Date)

  wink: ->
    atom.views.getView(atom.workspace).classList.remove("pronama-blink")
    atom.views.getView(atom.workspace).classList.remove("pronama-wink")
    setTimeout =>
        d = new Date
        if d.getSeconds() % 10 is 0
          atom.views.getView(atom.workspace).classList.add("pronama-wink")
        else
          atom.views.getView(atom.workspace).classList.add("pronama-blink")
        @winkTimer = setTimeout =>
          @wink()
        , Math.floor(Math.random() * 300) + 200
    , Math.floor(Math.random() * 600000)

  startVoice: (d)->
    return if !d.getHours
    time = "night"
    if d.getHours() >= 6 && d.getHours() < 12
      time = "morning"
    else if  d.getHours() >= 12 && d.getHours() < 18
      time = "afternoon"
    @speak atom.config.get("atom-pronama-chan.startVoice." + time)

  timeSignal: ->
    d = new Date
    @speak atom.config.get("atom-pronama-chan.timeSignal")[d.getHours()]

  speak: (filename) ->
    windows = browserWindow.getAllWindows()
    return unless windows[0].id == atom.getCurrentWindow().id
    return unless atom.views.getView(atom.workspace).classList.contains("pronama-chan")

    filepath = @getThemeDirPath() +  "voice/" + filename

    unless fs.existsSync filepath
      console.warn ("Pronama Chan: no voice file:" + filepath) if atom.inDevMode
      return

    @audio = @audio || document.createElement("audio")
    @audio.autoplay = true
    @audio.volume = atom.config.get("atom-pronama-chan.voiceVolume")
    @audio.src = filepath

  changeFace: (notification) ->
    switch notification.type
      when "info"
        className = "pronama-usual"
      when "success"
        className = "pronama-happy"
      when "warning"
        className = "pronama-sad"
      when "error"
        className = "pronama-surprise"
      when "fatal"
        className = "pronama-surprise"
      else
        className = "pronama-usual"

    atom.views.getView(atom.workspace).classList.add(className)
    setTimeout =>
      atom.views.getView(atom.workspace).classList.remove(className)
    , 3000

  getImageUrl: (type) ->
    @getThemeDirUrl() + "image/" + atom.config.get("atom-pronama-chan.images." + type)

  getThemeDirUrl: () ->
    "atom://atom-pronama-chan/assets/" + @trailingslash(atom.config.get("atom-pronama-chan.themeDir"))

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
