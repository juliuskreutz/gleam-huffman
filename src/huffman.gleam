import gleam/io

import argv

import decode
import encode

pub fn main() {
  case argv.load().arguments {
    ["encode", from, to] -> encode.run(from, to)
    ["decode", from, to] -> decode.run(from, to)
    _ -> {
      io.println("./huffman <encode|decode> <from> <to>")
      Ok(Nil)
    }
  }
}
