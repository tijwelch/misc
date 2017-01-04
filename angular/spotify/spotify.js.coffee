app = angular.module 'app'
app.factory 'Spotify', [
  '$window'
  'Constants'
  '$http'
  '$rootScope'
  '$q'
  ($window, Constants, $http, $rootScope, $q) ->

    currentUser = $rootScope.currentUser

    ensureValidToken = (url, data) ->
      $q (resolve, reject) ->
        # access token expires after 3600 seconds. request a new token if ours is about to expire (< 100 seconds)
        expiration = new Date($rootScope.currentUser.spotify_token_expiration)
        if (expiration - Date.now()) / 1000 < 100
          $http.post("/new_spotify_token").then (res) ->
            $rootScope.currentUser.spotify_access_token = res.data.token
            $rootScope.currentUser.spotify_token_expiration = res.data.expiration
            resolve url
          , reject
        else
          resolve url

    getUnauthorized = (url) ->
      $http.get(url, {headers: { 'Content-Type': 'application/json' }, interceptAuth: false})

    getAuthorized = (url) ->
      # handles rqeuesting a new validation token if current token is expired
      ensureValidToken(url).then ->
        $http.get(url, {headers: { 'Content-Type': 'application/json', 
          'Authorization': "Bearer #{$rootScope.currentUser.spotify_access_token}" }, interceptAuth: false})

    get = (url) ->
      return getAuthorized(url) if spotify.user
      getUnauthorized(url)

    post = (url, data) ->
      ensureValidToken(url, data).then ->
        $http.post(url, {data}, {headers: { 'Content-Type': 'application/json', 
          'Authorization': "Bearer #{$rootScope.currentUser.spotify_access_token}" }, interceptAuth: false})
        
    spotify =
      add_to_playlist: (playlist_id, track_uri) ->
        post("https://api.spotify.com/v1/users/#{this.user.id}/playlists/#{playlist_id}/tracks?uris=#{track_uri}")
      authenticate: ->
        redirect_uri = "#{window.location.origin}/spotify_callback"
        rights = 'streaming playlist-modify-public playlist-modify-private user-read-private user-read-email user-library-read playlist-modify-public'
        $window.location = "https://accounts.spotify.com/authorize/?client_id=#{Constants.SPOTIFY.CLIENT_ID}&response_type=code&redirect_uri=#{redirect_uri}&scope=#{rights}"
      create_playlist: (name, is_public) ->
        post("https://api.spotify.com/v1/users/#{this.user.id}/playlists", {name: name, public: is_public})
      format_playlist: (playlist) ->
        playlist.is_spotify = true
        playlist
      get_playlists: ->
        get("https://api.spotify.com/v1/me/playlists")
      get_track: (track_id) ->
        if this.user?
          get("https://api.spotify.com/v1/tracks/#{track_id}?market=#{this.user.country}")
        else
          get("https://api.spotify.com/v1/tracks/#{track_id}")
      get_saved_tracks: ->
        get("https://api.spotify.com/v1/me/tracks")
      get_user: (success, error) ->
        getAuthorized('https://api.spotify.com/v1/me')
      new_token: ->
        $http.post('/new_spotify_token')
      search: (term, type, offset, limit) ->
        if limit is undefined then limit = 20
        get("https://api.spotify.com/v1/search?q=#{term}&type=#{type}&limit=#{limit}&offset=#{offset}")



]


