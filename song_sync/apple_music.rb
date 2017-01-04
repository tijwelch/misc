module SongSync::AppleMusic
  # we build up an array @search_classes of search techniques and then run them one at a time until one returns a match
  class Search

    class << self
      include SongSync::Helper
      attr_reader :search_classes
    end

    @search_classes = []

    class << self
      # Search.inherited is automatically called whenever a class inherits the Search class. if we find some weird search case that we aren't handling (e.g. we assume youtube titles are formated "Artist - Song Title" but want to handle "Song Title - Arist") add a new class to the SongSync::AppleMusic module that inherits Search and has a track method that either returns a song or nil.
      def inherited(subclass)
        Search.search_classes << subclass
      end

      def find_song(song)
        track = nil
        Search.search_classes.each do |klass|
          begin
            track = klass.new(song).track
          rescue
          end
          # remove track number from title
          if track.nil?
            track = Search.try_without_ft(song, klass)
          end
          track = klass.new(song).track
          break unless track.nil?
        end
        return track
      end


      def try_without_ft(song, klass)
        rescue_nil do
          song.title = song.title.gsub('(', '').gsub(')', '').gsub('ft. ', '').gsub('ft ', '').gsub('feat ', '').gsub('feat. ', '').lstrip
          klass.new(song).track
        end
      end
    end

  end

  class SearchArtistAndTitleProvided < Search
    # assumes song.artist and song.title are provided - in other words, we already have spotify data for this song
    include SongSync::Helper

    def initialize(song)
      return unless song.artist && song.title
      @song = song
      # find apple's artistId for the song.artist (this class assumes song.artist and song.title are both provided)
      uri = "https://itunes.apple.com/search?media=music&entity=musicArtist&term=#{song.artist.gsub(' - ', ' ').gsub(' ', '+')}"
      data = http_search uri: uri
      if data["results"].count == 0
        return @result = nil
      end
      artistId = data["results"][0]["artistId"]
      # search apple for songs with title = song.title
      uri = "https://itunes.apple.com/search?term=#{(song.title).gsub(' - ', ' ').gsub(' ', '+')}&media=music&entity=song&attribute=songTerm"
      data = http_search uri: uri
      # filter songs that have the same artistId
      tracks = data["results"].find_all { |x| x["artistId"] == artistId }
      durations = tracks.map { |x| x["trackTimeMillis"] }
      # of the filtered songs, return the one with a duration most similar to song.milliseconds (the duration from the spotify song)
      duration_match = closest_duration(durations, song.milliseconds)
      track_index = tracks.index { |x| x["trackTimeMillis"] == duration_match}
      track_index && @result = tracks[track_index]
      track_index.nil? && @result = nil
    end

    def track
      # rescue_nil is defined in SongSync::Helper
      rescue_nil do 
        apple_title = @result["artistName"] + ' ' + @result["trackName"]
        if match_duration(@result["trackTimeMillis"], @song.milliseconds) && match_confidence(apple_title, @song.artist + ' ' + @song.title) > 0.5 
          @result
        else
          nil
        end
      end
    end
  end

  class GeneralSearch < Search
    # search the full title instead of breaking out artist and track title
    include SongSync::Helper

    def initialize(song)
      if !song.artist.nil? && !song.title.nil?
        @term = song.artist + ' ' + song.title
      elsif !song.title.nil?
        @term = clean_youtube_title song.title
      end
      return unless !@term.nil?
      uri = "https://itunes.apple.com/search?entity=musicTrack&term=#{@term.gsub(' ', '+')}"
      data = http_search uri: uri
      @result = find_apple_match(tracks: data["results"], query: @term)
      @song = song
    end

    def track
      rescue_nil do 
        @result["trackName"] = @result["trackName"].gsub('(', '').gsub(')', '').gsub('ft. ', '').gsub('ft ', '').gsub('feat ', '').gsub('feat. ', '')
        return @result if match_confidence(@result["artistName"] + ' ' + @result["trackName"], @term) > 0.75
        if match_duration(@result["trackTimeMillis"], @song.milliseconds) && match_confidence(@result["artistName"] + ' ' + @result["trackName"], @term) > 0.5
          @result
        else
          nil
        end
      end
    end
  end

end