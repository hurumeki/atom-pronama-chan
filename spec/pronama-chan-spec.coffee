PronamaChan = require '../lib/pronama-chan'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "PronamaChan", ->
  workspaceView = null
  textEdiorView = null
  activationPromise = null

  beforeEach ->
    workspaceView = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('atom-pronama-chan')

    waitsForPromise ->
      activationPromise
    waitsForPromise ->
      atom.workspace.open("README.md")

  describe "when the atom-pronama-chan activated", ->
    it "add pronama-chan class to workspace", ->
      expect(workspaceView.classList.contains('pronama-chan')).toEqual(true)
      expect(PronamaChan.audio.src).not.toBeUndefined()

  describe "when the atom-pronama-chan:toggle event is triggered", ->
    beforeEach ->
      textEdiorView = atom.views.getView(atom.workspace.getTextEditors()[0])

    it "toggle off pronama-chan class to workspace", ->
      waitsFor ->
        atom.commands.dispatch textEdiorView, 'atom-pronama-chan:toggle'
      runs ->
        expect(workspaceView.classList.contains('pronama-chan')).toEqual(false)

    it "toggle on pronama-chan class to workspace", ->
      waitsFor ->
        atom.commands.dispatch textEdiorView, 'atom-pronama-chan:toggle'
      waitsFor ->
        atom.commands.dispatch textEdiorView, 'atom-pronama-chan:toggle'
      runs ->
        expect(workspaceView.classList.contains('pronama-chan')).toEqual(true)

  describe "PronamaChan methods", ->
    orgSrc = null
    beforeEach ->
      orgSrc = PronamaChan.audio.src

    describe "speak method", ->
      it "speak method sucess", ->
        runs ->
          expect(PronamaChan.audio.src).not.toBeUndefined()
          PronamaChan.speak atom.config.get("atom-pronama-chan.startVoice.morning")
          expect(PronamaChan.audio.src).not.toEqual(orgSrc)

      it "speak method nothing to do when pronama-chan is hidden", ->
        runs ->
          PronamaChan.speak atom.config.get("")
          expect(PronamaChan.audio.src).toEqual(orgSrc)

      it "speak method fail file is not exists", ->
        runs ->
          PronamaChan.speak "test"
          expect(PronamaChan.audio.src).toEqual(orgSrc)

    describe "startVoice method", ->
      it "is morning from", ->
        PronamaChan.startVoice new Date("2014/01/01 6:00")

        runs ->
          expect(PronamaChan.audio.src).toContain(atom.config.get("atom-pronama-chan.startVoice.morning"))

      it "is morning to", ->
        PronamaChan.startVoice new Date("2014/01/01 11:59")

        runs ->
          expect(PronamaChan.audio.src).toContain(atom.config.get("atom-pronama-chan.startVoice.morning"))

      it "is afternoon from", ->
        PronamaChan.startVoice new Date("2014/01/01 12:00")

        runs ->
          expect(PronamaChan.audio.src).toContain(atom.config.get("atom-pronama-chan.startVoice.afternoon"))

      it "is afternoon to", ->
        PronamaChan.startVoice new Date("2014/01/01 17:59")

        runs ->
          expect(PronamaChan.audio.src).toContain(atom.config.get("atom-pronama-chan.startVoice.afternoon"))

      it "is night from", ->
        PronamaChan.startVoice new Date("2014/01/01 18:00")

        runs ->
          expect(PronamaChan.audio.src).toContain(atom.config.get("atom-pronama-chan.startVoice.night"))

      it "is night to", ->
        PronamaChan.startVoice new Date("2014/01/02 5:59")

        runs ->
          expect(PronamaChan.audio.src).toContain(atom.config.get("atom-pronama-chan.startVoice.night"))

      it "is night to", ->
        PronamaChan.startVoice new Date("2014/01/02 5:59")

        runs ->
          expect(PronamaChan.audio.src).toContain(atom.config.get("atom-pronama-chan.startVoice.night"))

    describe "changeFace method", ->
      beforeEach ->
        atom.notifications.clear()
        textEdiorView = atom.views.getView(atom.workspace.getTextEditors()[0])

      it "add info notification", ->
        waitsFor ->
          atom.notifications.addInfo("info")
        runs ->
          expect(workspaceView.classList.contains('pronama-usual')).toEqual(true)

      it "add success notification", ->
        waitsFor ->
          atom.notifications.addSuccess("success")
        runs ->
          expect(workspaceView.classList.contains('pronama-happy')).toEqual(true)

      it "add warning notification", ->
        waitsFor ->
          atom.notifications.addWarning("warning")
        runs ->
          expect(workspaceView.classList.contains('pronama-sad')).toEqual(true)

      it "add error notification", ->
        waitsFor ->
          atom.notifications.addError("error")
        runs ->
          expect(workspaceView.classList.contains('pronama-surprise')).toEqual(true)

      it "add fatal error notification", ->
        waitsFor ->
          atom.notifications.addFatalError("fatal error")
        runs ->
          expect(workspaceView.classList.contains('pronama-surprise')).toEqual(true)
