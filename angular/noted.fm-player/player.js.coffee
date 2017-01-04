angular.module('app').factory 'Player', [
  '$rootScope'
  '$routeParams'
  '$timeout'
  'Constants'
  'YoutubeAPI'
  'Like'
  'CreatePostModal'
  'Progress'
  'Queue'
  'SpotifyPlayer'
  'AppleMusicPlayer'
  'SongSync'
  'Popups'
  'SongSyncMessage'
  'PostTakenDown'
  'PlayCount'
  ($rootScope, $routeParams, $timeout, Constants, YoutubeAPI, Like, CreatePostModal, Progress, Queue, SpotifyPlayer, AppleMusicPlayer, SongSync, Popups, SongSyncMessage, PostTakenDown, PlayCount) ->
    $rootScope.playerState = Constants.PLAYER_PAUSED
    $rootScope.showSongSyncMessage = false

    postIndex = (postId, posts) ->
      i = 0
      while i < posts.length
        return i if posts[i].id is postId
        i++

    feedReady = ->
      post = Queue.getCurrentPost()
      $rootScope.currentSongSource = post.source
      if post.source is Constants.SOURCES.YOUTUBE
        if $rootScope.youtubeReady
          YoutubeAPI.cueVideo $rootScope.currentPost.video
        else
          youtubeReadyListener = $rootScope.$on Constants.EVENTS.YOUTUBE_READY, ->
            youtubeReadyListener()
            YoutubeAPI.cueVideo $rootScope.currentPost.video

    songSyncYoutube = (post, success, failure) ->
      # PostLoading.show()
      if not post.youtube_id
        # songSyncMessage 'Searching for Youtube version...'
        obj = if post.messageId then new SongSyncMessage else new SongSync
        obj.$save(id: post.id).then (res) ->
          unless res.song.youtube_id
            failure(res.song)
          else
            success(res.song)
        , ->
         songSyncError post.id, 0
      else
        success(post)    

    notAvailableYouTube = (post) ->
      Popups.navMessage "Not available on YouTube. Playing Apple Music preview."
      $timeout ->
        Popups.hideNavMessage()
      , 3000
      playAppleMusic post.video

    notAvailableSpotify = (post) ->
      Popups.navMessage "Not available on YouTube. Playing Spotify preview."
      $timeout ->
        Popups.hideNavMessage()
      , 3000
      playSpotify post.video

    play = ->
      post = Queue.getCurrentPost()
      $rootScope.playerState = Constants.PLAYER_PLAYING
      if post.youtube_id? 
        playYouTube post.youtube_id 
      else
        Popups.navMessage "Searching for YouTube version..."
        songSyncYoutube post, (new_post) ->
          Popups.navMessage "Playing YouTube"
          $timeout ->
            Popups.hideNavMessage()
          , 3000
          currentPost = Queue.getFeed()[Queue.getCurrentIndex()]
          currentPost.youtube_id = new_post.youtube_id
          playYouTube new_post.youtube_id 
        , (new_post) ->
          if post.source is Constants.SOURCES.APPLE_MUSIC
            notAvailableYouTube post
          else if post.source is Constants.SOURCES.SPOTIFY
            notAvailableSpotify post

    playYouTube = (videoId) ->
      Progress.setDuration YoutubeAPI.getDuration()
      YoutubeAPI.loadVideo videoId
      $rootScope.currentSongSource = 0
      SpotifyPlayer.stop()
      AppleMusicPlayer.stop()

    playSpotify = (track) ->
      track_parts = track.split(':')
      SpotifyPlayer.playPreview track_parts[track_parts.length - 1]
      $rootScope.currentSongSource = 2
      YoutubeAPI.stopVideo()
      AppleMusicPlayer.stop()

    playAppleMusic = (track) ->
      AppleMusicPlayer.playPreview track
      SpotifyPlayer.stop()
      $rootScope.currentSongSource = 3
      YoutubeAPI.stopVideo()

    feedReadyListener = $rootScope.$on Constants.EVENTS.FEED_READY, ->
      feedReadyListener()
      if $rootScope.currentPost then feedReady()

    $rootScope.$on Constants.EVENTS.KEYPRESS.SPACEBAR, ->
      if $rootScope.playerState is Constants.PLAYER_PLAYING then player.pause() else player.resume()
    $rootScope.$on Constants.EVENTS.KEYPRESS.LEFT_ARROW, ->
      player.previous()
    $rootScope.$on Constants.EVENTS.KEYPRESS.RIGHT_ARROW, ->
      player.next()
    $rootScope.$on Constants.EVENTS.SONG_FINISHED, ->
      player.next() if player.auto_play_next
    $rootScope.$on Constants.EVENTS.PLAYBACK_ERROR, ->
      player.next()
    $rootScope.$on Constants.EVENTS.PREVIEW_STARTED, ->
      player.pause()

    player =
      auto_play_next: true
      play: ->
        Progress.stop()
        Progress.reset()
        play()
        $rootScope.$broadcast Constants.EVENTS.PLAYING_POST
      # check if the post should be skipped
      checkSkip: (post) ->
        return false if not $rootScope.currentUser.video_skips
        return true for video in $rootScope.currentUser.video_skips when video.video_id is post.video
      pause: ->
        $rootScope.playerState = Constants.PLAYER_PAUSED
        Progress.stop()
        return if not Queue.getCurrentPost()
        source = $rootScope.currentSongSource
        if source is Constants.SOURCES.YOUTUBE
          YoutubeAPI.pauseVideo()
        else if source is Constants.SOURCES.APPLE_MUSIC
          AppleMusicPlayer.pause()
        else if source is Constants.SOURCES.SPOTIFY
          SpotifyPlayer.pause()
        $rootScope.$broadcast Constants.EVENTS.PAUSING_POST
      mute: ->
        if $rootScope.currentSongSource is Constants.SOURCES.YOUTUBE
          YoutubeAPI.muteVideo()
      unMute: ->
        if $rootScope.currentSongSource is Constants.SOURCES.YOUTUBE
          YoutubeAPI.unMuteVideo()
      setVolume: (volume) ->
        if $rootScope.currentSongSource is Constants.SOURCES.YOUTUBE
          YoutubeAPI.setVolume volume
      resume: ->
        $rootScope.playerState = Constants.PLAYER_PLAYING
        Progress.start()
        source = $rootScope.currentSongSource
        if source is Constants.SOURCES.YOUTUBE
          YoutubeAPI.seekTo $rootScope.progressTime
          YoutubeAPI.playVideo()
        else if source is Constants.SOURCES.APPLE_MUSIC
          AppleMusicPlayer.seekTo $rootScope.progressTime
          AppleMusicPlayer.resume()
        else if source is Constants.SOURCES.SPOTIFY
          SpotifyPlayer.seekTo $rootScope.progressTime
          SpotifyPlayer.resume()
        $rootScope.$broadcast Constants.EVENTS.PLAYING_POST
      stop: ->
        if $rootScope.currentSongSource is Constants.SOURCES.YOUTUBE
          YoutubeAPI.stopVideo()
        else if $rootScope.currentSongSource is Constants.SOURCES.APPLE_MUSIC
          AppleMusicPlayer.stop()
        else if $rootScope.currentSongSource is Constants.SOURCES.SPOTIFY
          SpotifyPlayer.stop()
      previous: ->
        player.stop()
        Progress.reset()
        Progress.stop()
        Queue.previousSong()
        play()
      next: ->
        player.stop()
        Progress.reset()
        Progress.stop()
        if Queue.nextSong() then player.play()
      like: (post)->
        Like.create post
      destroyLike: (post) ->
        Like.destroy post
      repost: (post) ->
        CreatePostModal.repost post
      getDuration: ->
        if $rootScope.currentSongSource is Constants.SOURCES.YOUTUBE
          YoutubeAPI.getDuration()
        else if $rootScope.currentSongSource is Constants.SOURCES.APPLE_MUSIC
          AppleMusicPlayer.duration
        else if $rootScope.currentSongSource is Constants.SOURCES.SPOTIFY
          SpotifyPlayer.duration
      getPlayerState: ->
        YoutubeAPI.state()
      error: (post) ->
        if $rootScope.currentPost.source is Constants.SOURCES.APPLE_MUSIC
          notAvailableYouTube $rootScope.currentPost
        else if $rootScope.currentPost.source is Constants.SOURCES.SPOTIFY 
          notAvailableSpotify $rootScope.currentPost
        else
          $rootScope.currentPost.image = '/images/video-not-found.png'
          $rootScope.loadingYoutube = false
          takenDownNotification = new PostTakenDown(post_id: $rootScope.currentPost.id)
          takenDownNotification.$save()
          player.next()
]