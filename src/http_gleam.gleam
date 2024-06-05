import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/otp/actor
import gleam/string
import glisten.{Packet, User}

pub type ParseError {
  UnexpectedInput(got: BitArray)
  InvalidUnicode
  InvalidString
}

pub type ParsedDataLines {
  ParsedDataLines(start_line: String, headers: List(String))
}

pub type ParsedStartLine {
  ParsedStartLine(method: String, path: String)
}

pub fn main() {
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, loop)
    |> glisten.serve(6379)
  process.sleep_forever()
}

fn loop(message: glisten.Message(a), state: state, conn: glisten.Connection(a)) {
  case message {
    User(_) -> actor.continue(state)
    Packet(data) -> handle_message(state, conn, data)
  }
}

fn handle_message(
  state: state,
  conn: glisten.Connection(a),
  message: BitArray,
) -> actor.Next(glisten.Message(a), state) {
  let assert Ok(message_string) = parse_unicode(message)
  let data_lines = string.split(message_string, on: "\r\n")
  let assert Ok(body) = list.last(data_lines)
  let assert Ok(parsed_data_lines) = parse_data_lines(data_lines)
  let assert Ok(parsed_start_line) =
    parse_start_line(parsed_data_lines.start_line)
  io.debug(parsed_data_lines.start_line)
  io.debug(parsed_start_line)

  let assert Ok(_) =
    glisten.send(conn, bytes_builder.from_string("HTTP/1.1 200 OK\r\n"))
  actor.continue(state)
}

fn parse_unicode(input: BitArray) -> Result(String, ParseError) {
  case bit_array.to_string(input) {
    Ok(content) -> Ok(content)
    Error(_) -> Error(InvalidUnicode)
  }
}

fn parse_data_lines(
  data_lines: List(String),
) -> Result(ParsedDataLines, ParseError) {
  case data_lines {
    [start_line, ..headers] -> Ok(ParsedDataLines(start_line, headers))
    _ -> Error(InvalidString)
  }
}

fn parse_start_line(start_line: String) -> Result(ParsedStartLine, ParseError) {
  case string.split(start_line, on: " ") {
    [method, path, ..] -> Ok(ParsedStartLine(method, path))
    _ -> Error(InvalidString)
  }
}
