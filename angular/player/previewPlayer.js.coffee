angular.module("app").factory "PreviewPlayer", [
  'Player'
  (Player) ->
    player =
      load: (video, onStateChange) ->
        player.previewObj = new YT.Player "previewPlayer",
          videoId: video
          events:
            'onStateChange': onStateChange

    player
]