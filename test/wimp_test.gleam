import gleam/httpc
import gleeunit
import wimp

pub fn main() {
  gleeunit.main()
}

pub fn invalid_api_key_test() {
  let assert Ok(response) =
    wimp.new("token", "user", "hi")
    |> wimp.message_request
    |> httpc.send

  let assert Error(wimp.InvalidApplicationToken) =
    response
    |> wimp.decode_message_response
}
