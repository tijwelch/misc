Song.class_eval do
  attr_accessor :modified_title
end

module SongSync::Spotify
  # see comments in apple_music.rb for explanation

  class Search

    class << self
      include SongSync::Helper
      attr_reader :search_classes
    end

    @search_classes = []

    # automatically called when a subclass inherits this class
    def self.inherited(subclass)
      Search.search_classes << subclass
    end

    def self.find_song(song)
      track = nil
      Search.search_classes.each do |klass|
        begin
          song.modified_title = song.title
          track = klass.new(song).track
        rescue => e
          puts e.message
        end
        # 
        # the following methods run through the search classes again with some modification to the search term
        # 
        # remove track number from title
        if track.nil?
          track = Search.try_without_track_number(song, klass)
        end
        # remove '(Official Video)'' from title
        if track.nil?
          track = Search.try_without_official_video(song, klass)
        end
        # remove '(Explicit)' from title
        if track.nil?
          track = Search.try_without_explicit(song, klass)
        end
        # remove everything between parenthesis
        if track.nil?
          track = Search.try_without_parens(song, klass)
        end
        break unless track.nil?
      end
      return track
    end

    def self.try_without_track_number(song, klass)
      rescue_nil do 
        track_number = song.title.match(/^\d{1,2}\.?/)
        unless track_number.nil?
          song.modified_title = song.title.gsub(/^\d{1,2}\.?/, '').lstrip
          klass.new(song).track
        end
      end
    end

    def self.try_without_official_video(song, klass)
      rescue_nil do 
        if song.title.include?('(Official Video)')
          song.modified_title = song.title.gsub('(Official Video)', '').lstrip
          klass.new(song).track
        end
      end
    end

    def self.try_without_explicit(song, klass)
      rescue_nil do 
        if song.title.include?('(Explicit)')
          song.modified_title = song.title.gsub('(Explicit)', '').lstrip
          klass.new(song).track
        end
      end
    end

    def self.try_without_parens(song, klass)
      rescue_nil do 
        if song.title.include?('(')
          song.modified_title = remove_parens(song.title)
          klass.new(song).track
        end
      end
    end

    def normalize_uri(uri)
      return uri if uri.is_a? URI
      uri = uri.to_s
      uri, *tail = uri.rpartition "#" if uri["#"]
      URI(URI.encode(uri) << Array(tail).join)
    end
  end

  class SearchArtistAndTitleProvided < Search
    # assumes we know song.artist and song.title (e.g. we're converting an apple music song)
    include SongSync::Helper

    def initialize(song)
      # return unless song.artist && song.modified_title
      artist = song.artist
      uri = normalize_uri %Q(https://api.spotify.com/v1/search?q=artist:"#{artist}"+track:#{song.modified_title.gsub(' ', '+')}&type=track&limit=30)
      data = http_search uri: uri
      @result = find_spotify_match(tracks: data["tracks"]["items"], query: song.modified_title)
      @song = song
    end

    def track
      rescue_nil do 
        artists = @result["artists"].map { |artist| artist["name"] }.join(',')
        if match_confidence(artists, @song.artist) > 0.5 && match_confidence(@result["name"], @song.modified_title) > 0.5
          @result
        else
          artists.each do |artist|
            return nil unless @song.modified_title.include?(artist) && @song.modified_title.include?(@result["name"])
          end
          @result
        end
      end
    end
  end

  class BasicSearch < Search
    # search the full title instead of breaking out artist and track title
    include SongSync::Helper

    def initialize(song)
      title = clean_youtube_title song.modified_title
      uri = normalize_uri "https://api.spotify.com/v1/search?q=#{title.gsub(' ', '+')}&type=track&limit=30"
      data = http_search uri: uri
      @result = find_spotify_match(tracks: data["tracks"]["items"], query: title)
      @song = song
    end

    def track
      rescue_nil do 
        return @result if match_confidence(@result["artists"].first["name"] + ' ' + @result["name"], @song.modified_title) > 0.75
        if match_confidence(@result["artists"].first["name"] + ' ' + @result["name"], @song.artist + ' ' +@song.modified_title) > 0.75
          @result
        else
          nil
        end
      end
    end
  end

  class GuessArtistAndTitle < Search
    # guess at the artist and title. 
    include SongSync::Helper

    def initialize(song)
      title = clean_youtube_title song.modified_title
      song_parts = title.split(' - ')
      artist = song.artist || song_parts[0]
      title = song_parts[1..-1].join('+')
      title.delete '-'
      uri = normalize_uri "https://api.spotify.com/v1/search?q=artist:#{artist}+track:#{title}&type=track&limit=30"
      data = http_search uri: uri
      @assumed_artist = artist
      @assumed_title = title
      @result = find_spotify_match(tracks: data["tracks"]["items"], query: song_parts.join(' '))
      @song = song
    end

    def track
      rescue_nil do 
        artists = @result["artists"].map { |artist| artist["name"] }
        spotify_title = artists.join(' ') + ' ' + @result["name"]
        if match_confidence(spotify_title, @song.modified_title) > 0.75 
          return @result
        else
          artists.each do |artist|
            return @result if @song.modified_title.include?(artist) && @song.modified_title.include?(@result["name"])
          end
        end
        if artists.include? @assumed_artist
          # remove artists from title - only compare song name
          artists.map { |x| spotify_title = spotify_title.gsub(x, '') }
          spotify_title.lstrip!
          spotify_title = spotify_title.gsub(/\(.*?\)/, '').gsub('  ', ' ').strip
          if match_confidence(spotify_title, @assumed_title) > 0.75
            @result
          end
        end
      end
    end
  end

  class SearchArtistAndTitleReversed < Search
    include SongSync::Helper

    def initialize(song)
      title = clean_youtube_title song.modified_title
      song_parts = title.split(' - ').reverse
      uri = normalize_uri "https://api.spotify.com/v1/search?q=artist:#{song_parts[0]}+track:#{song_parts[1..-1].join('+')}&type=track&limit=30"
      data = http_search uri: uri
      @result = find_spotify_match(tracks: data["tracks"]["items"], query: song_parts[1..-1].join(' '))
      @song = song
    end

    def track
      rescue_nil do 
        artists = @result["artists"].map { |artist| artist["name"] }
        if match_confidence(artists.join(',') + ' ' + @result["name"], @song.modified_title.split(' - ').reverse.join(',')) > 0.75
          @result
        else
          nil
        end
      end
    end
  end

end