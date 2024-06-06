import gleam/bytes_builder.{type BytesBuilder}

import simplifile

type DecodeTree {
  Leaf(value: BitArray)
  Node(left: DecodeTree, right: DecodeTree)
}

pub fn run(from: String, to: String) {
  let assert Ok(bits) = simplifile.read_bits(from)

  let #(tree, bits) = decode_tree(bits)
  let bits = decode_bytes(tree, bits, bytes_builder.new())

  let assert Ok(Nil) =
    bits
    |> bytes_builder.to_bit_array
    |> simplifile.write_bits(to, _)
}

fn decode_tree(bits: BitArray) -> #(DecodeTree, BitArray) {
  case bits {
    <<1:1, value:8, bits:bits>> -> #(Leaf(<<value>>), bits)
    <<0:1, bits:bits>> -> {
      let #(left, bits) = decode_tree(bits)
      let #(right, bits) = decode_tree(bits)
      #(Node(left, right), bits)
    }
    _ -> panic as "Failed decoding tree"
  }
}

fn decode_bytes(
  tree: DecodeTree,
  bits: BitArray,
  acc: BytesBuilder,
) -> BytesBuilder {
  case decode_byte(tree, bits) {
    #(<<0:8>>, _) -> acc
    #(byte, bits) -> decode_bytes(tree, bits, bytes_builder.prepend(acc, byte))
  }
}

fn decode_byte(tree: DecodeTree, bits: BitArray) -> #(BitArray, BitArray) {
  case bits, tree {
    _, Leaf(value) -> #(value, bits)
    <<0:1, bits:bits>>, Node(left, _) -> decode_byte(left, bits)
    <<1:1, bits:bits>>, Node(_, right) -> decode_byte(right, bits)
    _, _ -> panic as "Error decoding"
  }
}
