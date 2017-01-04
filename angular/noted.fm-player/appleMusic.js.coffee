angular.module('app').factory 'AppleMusicPlayer', [
  '$rootScope'
  'Progress'
  '$interval'
  'Constants'
  'AppleMusicTrack'
  ($rootScope, Progress, $interval, Constants, AppleMusicTrack) ->
    audio = new Audio() 
    preview = new Audio() 
    progressInterval = null

    startProgress = ->
      $rootScope.step = $rootScope.duration / 100
      progressInterval = $interval ->
        Progress.setSpotifyTime audio.currentTime
        songEnded() if audio.currentTime >= audio.duration
      , 1000

    stopProgress = ->
      $interval.cancel progressInterval

    songEnded = ->
      stopProgress()
      $rootScope.$broadcast Constants.EVENTS.SONG_FINISHED
    playPreview: (track) ->
      if audio.pause? then this.stop()
      AppleMusicTrack.get(id: track).$promise.then (data) ->
        Progress.setDuration 30
        audio.src = data.results[0].previewUrl
        audio.play()
        startProgress()
        Progress.start()
    pause: ->
      audio.pause()
    resume: ->
      audio.play()
    duration: ->
      audio.duration
    getCurrentTime: ->
      audio.currentTime
    stop: ->
      audio.pause()
      audio.currentTime = 0
    stopPreview: ->
      preview.pause()
    seekTo: (seconds) ->
      audio.currentTime = seconds
    preview: (track) ->
      $rootScope.$broadcast Constants.EVENTS.PREVIEW_STARTED
      AppleMusicTrack.get(id: track).$promise.then (data) ->
        preview.src = data.results[0].previewUrl
        preview.play()

]