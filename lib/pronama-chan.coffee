fs   = require "fs"
Path = require "path"
remote = require("electron").remote
browserWindow = remote.BrowserWindow
{CronJob} = require 'cron'
ASSETS_MODULE_PREFIX_REGEXP = /^atom-pronama-chan-assets-/

module.exports =
  config:
    themeDir:
      type: "string"
      default: "atom-pronama-chan-assets-pronama-chan"
      description: "directory name in assetsDir or package name in package.json dependencies"
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
    pJson = JSON.parse(fs.readFileSync(Path.join(__dirname, '..', 'package.json')))
    @loadConfig atom.config.get("atom-pronama-chan.themeDir")
    @themes = fs.readdirSync @getAssetsDirPath()
    @themes = @themes.concat(pkg for pkg in (key for key of pJson.dependencies) when ASSETS_MODULE_PREFIX_REGEXP.test(pkg))
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

  loadConfig: (themeDir) ->
    if fs.existsSync(Path.join(__dirname, '..', 'node_modules', themeDir))
      data = require(Path.join(themeDir))
    else if fs.existsSync(Path.join(@getAssetsDirPath(), themeDir, 'config.json'))
      data = require(Path.join(@getAssetsDirPath(), themeDir, 'config.json'))

    if data?
      atom.config.setDefaults("atom-pronama-chan", data)

  init: ->
    imageDir = Path.join(@getThemeDirPath(), 'image', '/')

    @element = document.createElement('style')
    @element.textContent = " .pronama-chan .editor .scroll-view::after {
      opacity: " + atom.config.get("atom-pronama-chan.imageOpacity").toString() + ";
      background-size: " + atom.config.get("atom-pronama-chan.imageSize") + ";
    }"

    if fs.existsSync (imageDir + atom.config.get("atom-pronama-chan.images.background"))
      @element.textContent += " .pronama-chan .editor .scroll-view::after {
        background-image: url(\"" + @getImageUrl("background") + "\");
      }"

    ["wink", "blink", "happy", "sad", "surprise", "usual"].forEach (item, i) =>
      if atom.config.get("atom-pronama-chan.images." + item) and
         fs.existsSync (imageDir + atom.config.get("atom-pronama-chan.images." + item))
        @element.textContent += " .pronama-chan.pronama-#{item} .editor .scroll-view::after {
          background-image: url(\"" + @getImageUrl(item) + "\");
        }"
        img = document.createElement('img')
        img.src = @getImageUrl(item)

    atom.views.getView(atom.workspace).appendChild(@element)

    if atom.config.get("atom-pronama-chan.timeSignal").length > 0
      @timer = new CronJob '00 00 * * * *', @timeSignal.bind(this), null, true

    if atom.config.get("atom-pronama-chan.images.wink") or
       atom.config.get("atom-pronama-chan.images.blink")
      @winkTimer = @wink()

  reload: ->
    @deactivate()
    @loadConfig atom.config.get("atom-pronama-chan.themeDir")
    @init()

  toggle: ->
    atom.views.getView(atom.workspace).classList.toggle("pronama-chan")

  roundTheme: ->
    idx = @themes.indexOf(atom.config.get("atom-pronama-chan.themeDir")) + 1

    if not @themes[idx]
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

  startVoice: (d) ->
    return if not d.getHours
    time = "night"
    if d.getHours() >= 6 and d.getHours() < 12
      time = "morning"
    else if  d.getHours() >= 12 and d.getHours() < 18
      time = "afternoon"
    @speak atom.config.get("atom-pronama-chan.startVoice." + time)

  timeSignal: ->
    d = new Date
    @speak atom.config.get("atom-pronama-chan.timeSignal")[d.getHours()]

  speak: (filename) ->
    windows = browserWindow.getAllWindows()
    return unless windows[0].id is atom.getCurrentWindow().id
    return unless atom.views.getView(atom.workspace).classList.contains("pronama-chan")

    filepath = Path.join(@getThemeDirPath(), 'voice', filename)
    fileurl = @getThemeDirUrl() + 'voice/' + filename

    unless fs.existsSync filepath
      console.warn ("Pronama Chan: no voice file:" + filepath) if atom.inDevMode
      return

    @audio = @audio or document.createElement("audio")
    @audio.autoplay = true
    @audio.volume = atom.config.get("atom-pronama-chan.voiceVolume")
    @audio.src = fileurl

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
    setTimeout ->
      atom.views.getView(atom.workspace).classList.remove(className)
    , 3000

  getImageUrl: (type) ->
    @getThemeDirUrl() + "image/" + atom.config.get("atom-pronama-chan.images." + type)

  getThemeDirUrl: ->
    themeDir = atom.config.get('atom-pronama-chan.themeDir')
    if ASSETS_MODULE_PREFIX_REGEXP.test(themeDir)
      url = 'atom://atom-pronama-chan/node_modules/' + themeDir
    else
      url = 'atom://atom-pronama-chan/assets/' + themeDir

    @trailingslash url

  getThemeDirPath: ->
    themeDir = atom.config.get("atom-pronama-chan.themeDir")
    if ASSETS_MODULE_PREFIX_REGEXP.test(themeDir)
      Path.join(__dirname, '..',  'node_modules', themeDir, '/')
    else
      Path.join(@getAssetsDirPath(), themeDir, '/')

  getAssetsDirPath: ->
    path =  atom.config.get("atom-pronama-chan.assetsDir")
    if path[0] is "~"
      path = @getUserHome() + path.substr(1)

    @trailingslash path

  getUserHome: ->
    if process.platform is 'win32'
      return process.env.USERPROFILE

    process.env.HOME

  trailingslash: (path) ->
    path = path.slice(0, -1) if path[path.length-1] is "/"
    path + "/"
