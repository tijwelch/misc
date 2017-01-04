angular.module('app').service 'WebSocket', [
  '$rootScope'
  'Constants'
  'Logger'
  ($rootScope, Constants, Logger) ->
    window.wsData = {}
    subscriptionId = 1
    subscriptions = []
    ws = null
    send = (data) ->
      ws.send JSON.stringify data

    unsubscribe = (id) ->
      subscriptions = (s for s in subscriptions when s.id isnt id)

    init = ->
      if window.document.location.protocol is "https:"
        uri = "wss://" + window.document.location.host + "/websocket"
      else
        uri = "ws://" + window.document.location.host + "/websocket"
      ws = new WebSocket uri
      ws.onclose = (close) ->
        setTimeout ->
          init()
        , 1000
      ws.onmessage = (message) ->
        Logger.log message
        json = JSON.parse message.data
        return if not json or not json.socket_message_type
        $rootScope.$apply(-> subscription.callback(json.data)) for subscription in subscriptions when subscription.action is json.socket_message_type
      ws.onopen = ->
        if $rootScope.currentUser?
          send {'initialization': true, 'user_id': $rootScope.currentUser.id}
    init()

    api =
      getSocket: ->
        ws
      send: (action, data) ->
        send data
      subscribe: (action, callback) ->
        id = subscriptionId++
        subscription =
          id: id
          action: action
          callback: callback
          unsubscribe: ->
            unsubscribe id
        subscriptions.push subscription
        subscription
]