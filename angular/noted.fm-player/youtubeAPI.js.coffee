angular.module('app').service 'YoutubeAPI', [
  '$rootScope'
  'Constants'
  'Popups'
  '$window'
  ($rootScope, Constants, Popups, $window) ->
    playerData =
      playerObj: null
      videoId: null
      autoplay: 0
      html5: 1
      controls: false
      modestbranding: 1
      height: 200
      width: 300
      listType: null
      list: null
      feedItems: null
      playsinline: 1

    criticalError = (startUp) ->
      message = if startUp then 'Looks like the YouTube player was not properly loaded. Please reload the page in order to play videos.' else 'Looks like the YouTube player hasn\'t loaded yet. Give it a minute then reload your page.'
      message += ' If it keeps up, shoot us an email at info@noted.fm so we can help!'
      Popups.quickAlert "YouTube's Having a Moment", message

    loadVideo = (videoId) ->
      $rootScope.loadingYoutube = true
      if not playerData.playerObj.loadVideoById then return criticalError false
      playerData.playerObj.loadVideoById videoId

    api =
      setPlayerId: (elemId) ->
        playerData.playerId = elemId

      setDimensions: (width, height) ->
        playerData.width = width
        playerData.height = height

      setPlayerVars: (player_vars) ->
        for attr of player_vars
          this[attr] = player_vars[attr]

      closePlayer: ->
        playerData.playerObj.loadVideoById Constants.NUSIKI_VIDEO_ID
        playerData.playerObj.cueVideoById Constants.NUSIKI_VIDEO_ID

      loadPlayer: (onStateChange, onReady, onError) ->
        if not $window.YT then return criticalError true
        playerVars =
          autoplay: playerData.autoplay
          controls: playerData.controls

        playerConfig =
          height: playerData.height
          width: playerData.width
          playerVars: playerVars
          events:
            'onReady': onReady
            'onError': onError

        if playerData.listType
          playerConfig.playerVars.listType = playerData.listType
          playerConfig.playerVars.list = playerData.list
        else
          playerConfig.videoId = playerData.videoId
          playerConfig.events.onStateChange = onStateChange  if onStateChange
        if YT.Player
          playerData.playerObj = new YT.Player playerData.playerId, playerConfig
          $rootScope.youtubePlayerLoaded = true

      muteVideo: ->
        playerData.playerObj.mute()

      unMuteVideo: ->
        playerData.playerObj.unMute()

      setVolume: (volume) ->
        playerData.playerObj.setVolume volume

      seekTo: (seconds) ->
        playerData.playerObj.seekTo(seconds)

      playVideo: ->
        playerData.playerObj.playVideo()

      pauseVideo: ->
        playerData.playerObj.pauseVideo()

      setVideoId: (videoId) ->
        playerData.videoId = videoId

      loadVideo: (videoId) ->
        loadVideo videoId

      cueVideo: (videoId) ->
        if playerData.playerObj.cueVideoById
          playerData.playerObj.cueVideoById videoId

      stopVideo: ->
        playerData.playerObj.stopVideo()

      state: ->
        playerData.playerObj.getPlayerState()

      getDuration: ->
        if not playerData.playerObj.getDuration then return 0
        playerData.playerObj.getDuration()

      getCurrentTime: ->
        playerData.playerObj.getCurrentTime()
]