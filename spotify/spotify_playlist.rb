class SpotifyPlaylist
  require 'unirest'

  attr_accessor :new_playlist, :spotify_playlist_id

  def initialize(access_token:, spotify_user_id:, spotify_playlist_id:)
    @access_token = access_token
    @response = get_playlist(access_token, spotify_user_id, spotify_playlist_id)
    @spotify_user_id = spotify_user_id
    @spotify_playlist_id = spotify_playlist_id
  end

  def get_playlist(access_token, spotify_user_id, spotify_playlist_id)
    response = spotify_request("get", "https://api.spotify.com/v1/users/#{spotify_user_id}/playlists/#{spotify_playlist_id}")
    response.body
  end

  def owner_id
    @response["owner"]["id"]
  end

  def name
    @response["name"]
  end

  def owner_name
    response = spotify_request("get", "https://api.spotify.com/v1/users/#{self.owner_id}")
    response.body["display_name"]
  end

  def tracks
    @response["tracks"]["items"]
  end

  def import(user_id:)
    create_noted_playlist(user_id)
    add_tracks_to_playlist
  end

  def create_noted_playlist(noted_user_id)
    user = User.find(noted_user_id)
    @new_playlist = Playlist.where(name: self.name, user_id: noted_user_id).first
    if @new_playlist.nil?
      @new_playlist = Playlist.create(name: self.name, user_id: noted_user_id, spotify_user_id: @spotify_user_id, spotify_playlist_id: @spotify_playlist_id)
    end
    if UserPlaylist.where(user: user, playlist: @new_playlist).empty?
      user.add_as_collaborator(@new_playlist.id, true, true, true)
    end
    return @new_playlist
  end

  def add_tracks_to_playlist
    self.tracks.each do |item|
      unless already_in_playlist(video: item["track"]["uri"])   
        post = create_noted_post(user_id: @new_playlist.user_id, video: item["track"]["uri"], title: item["track"]["name"], artist: format_artists(item["track"]["artists"]), image: item["track"]["album"]["images"][0]["url"])
        create_playlist_post(playlist: @new_playlist, post: post)
      end
    end
  end

  def format_artists(artists)
    artist_names_array = artists.collect { |x| x["name"] }
    artist_names_array.join(", ")
  end

  def create_noted_post(user_id:, video:, title:, image:, artist: nil)
    user = User.find(user_id)
    post = user.posts.build(user_id: user_id, video: video, title: title, source: 2, is_playlist: true, artist: artist, image: image)
    Post.create_post(user, post)
  end

  def already_in_playlist(video:)
    @new_playlist.posts.collect(&:video).include? video
  end

  def create_playlist_post(playlist:, post:)
    PlaylistPost.create_post(post.id, playlist.id, @new_playlist.user_id)
  end

  private

  def spotify_request(method, url)
    Unirest.send(method, url, 
                    headers:{ 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{@access_token}" })
  end

end