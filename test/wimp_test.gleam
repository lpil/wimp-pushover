import gleeunit
import wimp
import gleam/io
import gleam/httpc

pub fn main() {
  gleeunit.main()
}

pub fn hello_world_test() {
  let assert Ok(response) =
    wimp.new("token", "user", "hi")
    |> wimp.message_request
    |> httpc.send

  response
  |> wimp.decode_message_response
  |> io.debug

  panic
}
