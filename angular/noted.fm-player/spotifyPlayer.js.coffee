angular.module('app').factory 'SpotifyPlayer', [
  '$rootScope'
  'Spotify'
  'Progress'
  '$interval'
  'Constants'
  'Popups'
  ($rootScope, Spotify, Progress, $interval, Constants, Popups) ->
    audio = new Audio() 
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
      Spotify.get_track(track).then (track) ->
        if Spotify.user? and track.data.is_playable is false then return Popups.quickAlert 'Song Not Available', 'The song you\'ve requested is not currently available in Spotify in your market.'
        Progress.setDuration 30
        audio.src = track.data.preview_url
        audio.play()
        startProgress()
        Progress.start()
        return
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
      audio.pause()
    seekTo: (seconds) ->
      audio.currentTime = seconds



]