# wimp

[![Package Version](https://img.shields.io/hexpm/v/wimp)](https://hex.pm/packages/wimp)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/wimp/)

A Gleam client for the Pushover push notification API.

```sh
gleam add wimp
```
```gleam
import wimp
import gleam/httpc

pub fn send_notification() {
  let assert Ok(response) =
    wimp.new(token: token, user: user, message: "Hello, Joe!")
    |> wimp.message_request
    |> httpc.send

  response
  |> wimp.decode_message_response
}
```

Code documentation can be found at <https://hexdocs.pm/wimp>.

More information about the Pushover API can be found at <https://pushover.net/api>.
