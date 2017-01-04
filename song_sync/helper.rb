module SongSync::Helper
  require 'fuzzy_match'
  require 'amatch'
  FuzzyMatch.engine = :amatch
  
  #TODO: make these general to work for apple music / youtube also
  def http_search(uri:)
    uri = normalize_uri(uri)
    JSON.parse Net::HTTP.get_response(uri).body
  end

  def normalize_uri(uri)
    return uri if uri.is_a? URI
    uri = uri.to_s
    uri, *tail = uri.rpartition "#" if uri["#"]
    URI(URI.encode(uri) << Array(tail).join)
  end

  def youtube_blocked_in_region(video, region)
    uri = "https://www.googleapis.com/youtube/v3/videos?id=#{video}&key=AIzaSyDjlvcU8LoyHyjig6Vc-P53cHu884eMlqc&part=contentDetails"
    data = http_search uri: uri
    blocked_regions = data["items"].first["contentDetails"]["regionRestriction"]["blocked"]
    blocked_regions.include? region

  end

  def basic_title_clean(str)
    str.upcase!
    str.gsub! ' - ', ''
  end

  def remove_parens(str)
    str.gsub(/\(.*?\)/, '').gsub('  ', ' ')
  end

  def find_spotify_match(tracks:, query:)
    songs = []
    tracks.each do |track|
      artist_names = track["artists"].map { |artist| artist["name"] }
      songs << { track: track, search_string: artist_names.push(track["name"]).join(" ") }
    end
    begin
      FuzzyMatch.new(songs, read: :search_string).find(query)[:track]
    rescue
      nil
    end
  end

  def clean_youtube_title(title)
    # get rid of some extra attributes like [OFFICIAL VIDEO] from youtube titles
    # need to try to be careful not to remove any of the actual title
    title
      .gsub(/lyric video/i, '')
      .gsub(/lyrics video/i, '')
      .gsub(/official video/i, '')
      .gsub(/official music video/i, '')
      .gsub(/music video/i, '')
      .gsub(/video version/i, '')
      .gsub(/\(video\)/i, '')
      .gsub(/\[video\]/i, '')
      .gsub(/\(audio\)/i, '')
      .gsub(/\[audio\]/i, '')
      .gsub(/\(lyrics\)/i, '')
      .gsub(/\[lyrics\]/i, '')
      .gsub(/\(hd\)/i, '')
      .gsub(/\[hd\]/i, '')
      .gsub(/\(explicit\)/i, '')
      .gsub(/\[explicit\]/i, '')
      .gsub('ft. ', '')
      .gsub('()', '')
      .gsub('[]', '')
  end

  def find_apple_match(tracks:, query:)
    songs = []
    tracks.each do |track|
      songs << { track: track, search_string: track["artistName"] + ' ' +  track["trackName"]}
    end
    begin
      FuzzyMatch.new(songs, read: :search_string).find(query)[:track]
    rescue
      nil
    end
  end

  def find_youtube_match(tracks:, query:)
    songs = []
    tracks.each do |track|
      songs << { track: track, search_string: track["snippet"]["title"].gsub(' - ', ' ').gsub(' (Official Audio)', '').gsub(' [Official Audio]', '')}
    end
    begin
      FuzzyMatch.new(songs, read: :search_string).find(query)[:track]
    rescue
      nil
    end
  end

  def alphabetize_words(words)
    words.split(' ').sort.join(' ')
  end

  def remove_artist_names_from_title(data, title)
    artist_names = data["artists"].map { |artist| artist["name"] }
    artist_names.each { |name| title.gsub!(name, '') }
    title.lstrip!
    title.rstrip!
  end

  def most_confident_title(track)
    parts = @song.title.split(' ').delete_if { |x| ['-', ' - '].include? x}
    parts.inject do |memo, word|
      match_confidence(track["name"], memo + " " + word) > match_confidence(track["name"], memo) ? memo + " " + word : memo
    end
  end

  def match_duration(track_length, song_length)
    track_length > song_length - 2000 && track_length < song_length + 2000
  end

  def closest_duration(options, target)
    options.min_by { |x| (x.to_f - target).abs } 
  end

  def match_confidence(first_title, second_title)
    first_title.upcase.delete(' - ').delete(' & ').levenshtein_similar second_title.upcase.delete(' - ').delete(' & ')
  end

  def update_song(track)
    @song.update_columns spotify_id: track["uri"], artist: track["artists"].first["name"], title: track["name"], spotify_url: track["external_urls"]["spotify"]
  end

  def rescue_nil(&block)
    begin
      yield if block_given?
    rescue NoMethodError
      nil
    end
  end

  def update_spotify_song
    song = @song ||= self.song
    track = SongSync::Spotify::Search.find_song(song)
    unless track.nil?
      @song.update_columns spotify_id: track["uri"], artist: track["artists"].first["name"], title: track["name"], spotify_url: track["external_urls"]["spotify"]
    end
  end

  def update_apple_music_song
    song = @song ||= self.song
    track = SongSync::AppleMusic::Search.find_song(song)
    unless track.nil?
      @song.update_columns apple_music_id: track["trackId"], artist: track["artistName"], title: track["trackName"], apple_music_url: track["trackViewUrl"]
    end
  end

  def update_youtube_song
    song = @song ||= self.song
    track = SongSync::Youtube::Search.find_song(song)
    unless track.nil?
      @song.update_columns youtube_id: track["id"]["videoId"], youtube_title: track["snippet"]["title"]
    end
  end

  def get_youtube_title(video)
    uri = URI("https://www.googleapis.com/youtube/v3/videos?part=snippet&id=#{video}&key=AIzaSyDjlvcU8LoyHyjig6Vc-P53cHu884eMlqc")
    data = JSON.parse Net::HTTP.get_response(uri).body
    data["items"].first["snippet"]["title"]
  end



end