//// A Gleam client for the Pushover push notification API.
////
//// https://pushover.net/api

import gleam/http.{Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Error {
  MessageLimitExceeded(limits: Limits)
  InvalidApplicationToken
  BadRequest(body: String)
  RateLimited(limits: Limits, body: String)
  UnexpectedResponse(status: Int, body: String)
}

pub type Priority {
  Emergency(
    // The number of seconds before resending the notification.
    // Must be be at least 30, lower values will be set to 30.
    retry: Int,
    // How many seconds the notification will continue to be retried for.
    // Must be at most 10800, higher values will be set to 10800.
    expire: Int,
  )
  High
  Normal
  Low
  Lowest
}

pub type Formatting {
  Html
  Text
  Monospace
}

pub type Limits {
  Limits(
    app_limit: Int,
    app_remaining: Int,
    /// The unix timestamp when the app counter will reset.
    app_reset: Int,
  )
}

pub opaque type Builder {
  Builder(
    token: String,
    user: String,
    message: String,
    device: Option(String),
    title: Option(String),
    priority: Priority,
    formatting: Formatting,
    time_to_live: Option(Int),
    sound: Option(String),
    supplimentary_url: Option(#(String, String)),
  )
}

/// Create a new Pushover message to send to a Pushover user as the application
/// for the token.
///
/// Messages are limited to 1024 characters in length, longer messages will be
/// truncated.
pub fn new(
  token token: String,
  user user: String,
  message message: String,
) -> Builder {
  let message = string.slice(message, 0, length: 1024)
  Builder(
    token: token,
    user: user,
    message: message,
    device: None,
    title: None,
    priority: Normal,
    formatting: Text,
    time_to_live: None,
    sound: None,
    supplimentary_url: None,
  )
}

/// Set the formatting of the message.
///
pub fn formatting(builder: Builder, formatting: Formatting) -> Builder {
  Builder(..builder, formatting: formatting)
}

/// Set the title of the message.
///
/// Titles are limited to 250 characters in length, longer titles will be
/// truncated.
pub fn title(builder: Builder, title: String) -> Builder {
  let title = string.slice(title, 0, length: 250)
  Builder(..builder, title: Some(title))
}

/// Set the priority of the message.
///
pub fn priority(builder: Builder, priority: Priority) -> Builder {
  Builder(..builder, priority: priority)
}

/// Set the time to live of the message in seconds.
///
pub fn time_to_live(builder: Builder, seconds time_to_live: Int) -> Builder {
  Builder(..builder, time_to_live: Some(time_to_live))
}

/// Set the device to send the message to.
///
pub fn device(builder: Builder, device: String) -> Builder {
  Builder(..builder, device: Some(device))
}

/// Set a supplimentary URL and a title for the link.
///
pub fn supplimentary_url(
  builder: Builder,
  title title: String,
  url url: String,
) -> Builder {
  Builder(..builder, supplimentary_url: Some(#(title, url)))
}

/// Set the sound of the message.
///
/// The default sounds are:
/// - `pushover` - Pushover (default)  
/// - `bike` - Bike  
/// - `bugle` - Bugle  
/// - `cashregister` - Cash Register  
/// - `classical` - Classical  
/// - `cosmic` - Cosmic  
/// - `falling` - Falling  
/// - `gamelan` - Gamelan  
/// - `incoming` - Incoming  
/// - `intermission` - Intermission  
/// - `magic` - Magic  
/// - `mechanical` - Mechanical  
/// - `pianobar` - Piano Bar  
/// - `siren` - Siren  
/// - `spacealarm` - Space Alarm  
/// - `tugboat` - Tug Boat  
/// - `alien` - Alien Alarm (long)  
/// - `climb` - Climb (long)  
/// - `persistent` - Persistent (long)  
/// - `echo` - Pushover Echo (long)  
/// - `updown` - Up Down (long)  
/// - `vibrate` - Vibrate Only
/// - `none` - None (silent) 
///
pub fn sound(builder: Builder, sound: String) -> Builder {
  Builder(..builder, sound: Some(sound))
}

pub fn message_request(builder: Builder) -> Request(String) {
  case builder.message {
    "" -> panic as "message must not be blank"
    _ -> Nil
  }

  let properties =
    [
      #("token", json.string(builder.token)),
      #("user", json.string(builder.user)),
      #("message", json.string(builder.message)),
    ]
    |> add_priority(builder.priority)
    |> add_formatting(builder.formatting)
    |> add_supplimentary_url(builder.supplimentary_url)
    |> maybe_add("ttl", builder.time_to_live, json.int)
    |> maybe_add("title", builder.title, json.string)
    |> maybe_add("sound", builder.sound, json.string)
    |> maybe_add("device", builder.device, json.string)

  request.new()
  |> request.set_method(Post)
  |> request.set_host("api.pushover.net")
  |> request.set_path("/1/messages.json")
  |> request.set_body(json.to_string(json.object(properties)))
  |> request.prepend_header("accept", "application/json")
  |> request.prepend_header("content-type", "application/json")
}

fn add_formatting(
  properties: List(#(String, Json)),
  formatting: Formatting,
) -> List(#(String, Json)) {
  case formatting {
    Text -> properties
    Html -> [#("html", json.int(1)), ..properties]
    Monospace -> [#("monospace", json.int(1)), ..properties]
  }
}

fn add_supplimentary_url(
  properties: List(#(String, Json)),
  supplimentary_url: Option(#(String, String)),
) -> List(#(String, Json)) {
  case supplimentary_url {
    None -> properties
    Some(#(title, url)) -> [
      #("url", json.string(url)),
      #("url_title", json.string(title)),
      ..properties
    ]
  }
}

fn add_priority(
  properties: List(#(String, Json)),
  priority: Priority,
) -> List(#(String, Json)) {
  let #(extra, priority) = case priority {
    Emergency(retry: retry, expire: expire) -> {
      let extra = [
        #("retry", json.int(int.max(retry, 30))),
        #("expire", json.int(int.min(expire, 10_800))),
      ]

      #(extra, 2)
    }
    High -> #([], 1)
    Normal -> #([], 0)
    Low -> #([], -1)
    Lowest -> #([], -2)
  }

  extra
  |> list.append(properties)
  |> list.prepend(#("priority", json.int(priority)))
}

fn maybe_add(
  properties: List(#(String, Json)),
  key: String,
  value: Option(t),
  encode: fn(t) -> Json,
) -> List(#(String, Json)) {
  case value {
    None -> properties
    Some(value) -> [#(key, encode(value)), ..properties]
  }
}

/// Decode the response from Pushover to determine whether the message sending
/// was successful or not.
///
pub fn decode_message_response(resp: Response(String)) -> Result(Limits, Error) {
  let get_int_header = fn(name) {
    resp
    |> response.get_header(name)
    |> result.try(int.parse)
    |> result.unwrap(0)
  }
  let app_limit = get_int_header("x-limit-app-limit")
  let app_remaining = get_int_header("x-limit-app-remaining")
  let app_reset = get_int_header("x-limit-app-reset")
  let limits =
    Limits(
      app_limit: app_limit,
      app_remaining: app_remaining,
      app_reset: app_reset,
    )
  case resp.status {
    200 -> Ok(limits)
    400 ->
      Error(case string.contains(resp.body, "application token is invalid") {
        True -> InvalidApplicationToken
        False -> BadRequest(resp.body)
      })
    429 -> Error(RateLimited(limits, resp.body))
    code -> Error(UnexpectedResponse(code, resp.body))
  }
}
