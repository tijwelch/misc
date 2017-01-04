module SongSync::Youtube
  # see comments in apple_music.rb for explanation

  class Search

    class << self
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
        track = klass.new(song).track
        break unless track.nil?
      end
      return track
    end

  end

  class SearchArtistAndTitleProvided < Search
    # we're only ever converting to youtube if spotify or apple music is known (song.artist and song.title are known)
    include SongSync::Helper

    def initialize(song)
      (song.artist.nil? || song.title.nil?) && return 
      artist = song.artist
      title = song.title
      search_string = (artist + ' - ' + title).gsub(' & ', ' ')
      uri = "https://www.googleapis.com/youtube/v3/search?q=#{search_string.gsub(' ', '+')}&key=AIzaSyDjlvcU8LoyHyjig6Vc-P53cHu884eMlqc&part=snippet&maxResults=40&type=video&videoCategoryId=10"
      data = http_search uri: uri
      @result = find_youtube_match(tracks: data["items"], query: search_string)
      @result["regionCode"] = data["regionCode"]
      @song = song
    end

    def track
      rescue_nil do 
        youtube_title = @result["snippet"]["title"].gsub(' (Official Audio)', '')
        if (match_confidence(youtube_title.upcase.split(' ').sort.join(' '), (@song.artist.upcase + ' ' + @song.title.upcase).split(' ').sort.join(' ')) > 0.5) || (match_confidence(youtube_title.upcase.split(' ').sort.join(' '), @song.title.upcase.split(' ').sort.join(' ')) > 0.5) 
          # unless youtube_blocked_in_region(@result["id"]["videoId"], @result["regionCode"])
          @result
          # end
        else
          nil
        end
      end
    end
  end

  class ArtistNameInChannelTitle < Search
    include SongSync::Helper

    def initialize(song)
      return if song.artist.nil? || song.title.nil?
      artist = song.artist
      title = song.title
      search_string = (artist + ' ' + title).gsub(' & ', ' ')
      uri = "https://www.googleapis.com/youtube/v3/search?q=#{search_string.gsub(' ', '+')}&key=AIzaSyDjlvcU8LoyHyjig6Vc-P53cHu884eMlqc&part=snippet&maxResults=40&type=video&videoCategoryId=10"
      data = http_search uri: uri
      @result = find_youtube_match(tracks: data["items"], query: title)
      @song = song
    end

    def track
      rescue_nil do 
        if @result["snippet"]["channelTitle"].include? @song.artist
          if (match_confidence(@result["snippet"]["title"].upcase.split(' ').sort, @song.title.upcase.split(' ').sort) > 0.5)
            # unless youtube_blocked_in_region(@result["id"]["videoId"], @result["regionCode"])
            @result
            # end
          else
            nil
          end
        end
      end
    end
  end


end