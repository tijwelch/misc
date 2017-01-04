angular.module('app').factory 'FeedCache', [
  '$cacheFactory'
  '$rootScope'
  '$resource'
  '$q'
  '$interval'
  'NewPostsFromFeed'
  'Constants'
  'DataFilters'
  'Logger'
  'Page'
  ($cacheFactory, $rootScope, $resource, $q, $interval, NewPostsFromFeed, Constants, DataFilters, Logger, Page) ->
    cache = $cacheFactory 'feed-cache'
    cache.feedIntervalSet = false if !cache.feedIntervalSet?

    # Since feed posts are cached, we need to check for new posts if we're not viewing the feed and 
    # add them to cache so they're visible when navigating to the feed
    handlePollResponse = (response) ->
      if response.feed.length
        if Page.current() is "/"
          # run tweet filters on the posts
          response.feed = DataFilters.setPostCommentsAndCaption response.feed
          for post in response.feed
            $rootScope.newPosts.unshift post
          cache.addToCache 'feed-posts', response.feed
        else
          cache.addToCache 'feed-posts', response.feed

    # When the current user creates a new post, add it to their feed and profile cache
    $rootScope.$on "postCreated", (event, post) ->
      request = new $resource "/feed/get_posts"
      postPromise = request.save({}, {ids: [post.id]}).$promise
      updateFeedCache = (new_post) ->
        Logger.log 'caching new posts'
        current_cache = cache.get 'feed-posts'
        current_cache.feed.unshift new_post
        cache.put 'feed-posts', current_cache

      updateUserCache = (new_post) ->
        Logger.log 'caching new posts'
        current_cache = cache.get "users/#{$rootScope.currentUser.username}/posts"
        current_cache.feed.unshift new_post
        cache.put "users/#{$rootScope.currentUser.username}/posts", current_cache

      postPromise.then (post) ->
        $rootScope.$broadcast 'showNewPostOnFeed', post.feed[0]
        updateFeedCache(post.feed[0])
        updateUserCache(post.feed[0])
      
    cache.getIds = (cache_name, queryFunction) ->
      cachedIds = cache.get cache_name
      if cachedIds
        Logger.log "returning results from #{cache_name}"
        deferred = $q.defer()
        deferred.resolve cachedIds
        return deferred.promise
      idsQuery = queryFunction().$promise
      idsQuery.then (res) ->
        Logger.log 'setting cache'
        cache.put cache_name, res
      return idsQuery

    cache.addToCache = (cacheName, posts) ->
      current_cache = cache.get(cacheName)
      Logger.log 'adding new post to cache'
      new_cache = posts
      for post in posts by -1
        current_cache.feed.unshift post 
      cache.put cacheName, current_cache

    cache.setFeedInterval = ->
      # check for new posts in feed on an interval and add them to feed cache
      Logger.log 'setting feed interval'
      cache.feedIntervalSet = true
      setInterval ->
        firstPost = cache.get('feed-posts').feed[0]
        newPosts = NewPostsFromFeed.get id: firstPost.id
        newPosts.$promise.then (res) ->
          handlePollResponse(res)
      , Constants.FEED_POLL_INTERVAL

    cache.setUnseenPostCount = (playlist_id, unseen_post_count) ->
      try
        cachedTopPlaylists = cache.get 'top-playlists'
        playlist.unseen_post_count = unseen_post_count for playlist in cachedTopPlaylists when playlist.id is playlist_id
        cache.put 'top-playlists', cachedTopPlaylists
      catch error
        console.error error
      
    cache.expire = (name) ->
      cache.remove(name)

    return cache
]
