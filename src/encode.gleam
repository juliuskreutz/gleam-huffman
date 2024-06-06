import gleam/bit_array
import gleam/bytes_builder.{type BytesBuilder}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option

import priorityq
import simplifile

type EncodeTree {
  Leaf(weight: Int, value: BitArray)
  Node(weight: Int, left: EncodeTree, right: EncodeTree)
}

pub fn run(from: String, to: String) {
  let assert Ok(bits) = simplifile.read_bits(from)

  let bytes = bytes(bits, []) |> list.append([<<0>>])
  let frequencies = count_frequencies(bytes, dict.new())
  let queue = frequencies_to_queue(frequencies)
  let tree = queue_to_tree(queue)
  let dictionary = tree_to_dictionary(tree, <<>>, dict.new())

  let bits = encode_tree(tree, bytes_builder.new())
  let bits = encode_bytes(dictionary, bytes, bits)
  let bits = bits |> bytes_builder.to_bit_array |> pad_to_next_byte

  let assert Ok(Nil) = simplifile.write_bits(to, bits)
}

fn bytes(bits: BitArray, acc: List(BitArray)) -> List(BitArray) {
  case bits {
    <<>> -> acc
    <<b:8, rest:bits>> -> bytes(rest, [<<b>>, ..acc])
    _ -> panic as "Not a byte"
  }
}

fn count_frequencies(
  bytes: List(BitArray),
  acc: dict.Dict(BitArray, Int),
) -> dict.Dict(BitArray, Int) {
  case bytes {
    [] -> acc
    [byte, ..rest] -> {
      let increment = fn(x: option.Option(Int)) {
        case x {
          option.Some(i) -> i + 1
          option.None -> 1
        }
      }
      let acc = dict.update(acc, byte, increment)
      count_frequencies(rest, acc)
    }
  }
}

fn frequencies_to_queue(
  frequencies: dict.Dict(BitArray, Int),
) -> priorityq.PriorityQueue(EncodeTree) {
  let queue =
    priorityq.new(fn(a: EncodeTree, b: EncodeTree) {
      int.compare(b.weight, a.weight)
    })

  dict.fold(frequencies, queue, fn(queue, byte, weight) {
    priorityq.push(queue, Leaf(weight, byte))
  })
}

fn queue_to_tree(queue: priorityq.PriorityQueue(EncodeTree)) -> EncodeTree {
  case priorityq.size(queue) {
    0 -> panic as "Empty"
    1 -> {
      let assert option.Some(root) = priorityq.peek(queue)
      root
    }
    _ -> {
      let assert option.Some(left) = priorityq.peek(queue)
      let queue = priorityq.pop(queue)
      let assert option.Some(right) = priorityq.peek(queue)
      let queue = priorityq.pop(queue)

      let node = Node(left.weight + right.weight, left, right)

      queue
      |> priorityq.push(node)
      |> queue_to_tree
    }
  }
}

fn tree_to_dictionary(
  tree: EncodeTree,
  path: BitArray,
  acc: dict.Dict(BitArray, BitArray),
) -> dict.Dict(BitArray, BitArray) {
  case tree {
    Leaf(_, value) -> dict.insert(acc, value, path)
    Node(_, left, right) ->
      acc
      |> dict.merge(tree_to_dictionary(left, <<path:bits, 0:1>>, acc))
      |> dict.merge(tree_to_dictionary(right, <<path:bits, 1:1>>, acc))
  }
}

fn encode_tree(tree: EncodeTree, acc: BytesBuilder) -> BytesBuilder {
  case tree {
    Leaf(_, value) -> acc |> bytes_builder.append(<<1:1, value:bits>>)
    Node(_, left, right) ->
      acc
      |> bytes_builder.append(<<0:1>>)
      |> bytes_builder.append_builder(encode_tree(left, acc))
      |> bytes_builder.append_builder(encode_tree(right, acc))
  }
}

fn encode_bytes(
  dictionary: dict.Dict(BitArray, BitArray),
  bytes: List(BitArray),
  acc: BytesBuilder,
) -> BytesBuilder {
  case bytes {
    [] -> acc
    [byte, ..bytes] -> {
      let assert Ok(bits) = dict.get(dictionary, byte)
      encode_bytes(dictionary, bytes, acc |> bytes_builder.append(bits))
    }
  }
}

fn pad_to_next_byte(bits: BitArray) -> BitArray {
  let size = bit_array.byte_size(bits)
  let new_bits = <<bits:bits, 0:1>>

  case bit_array.byte_size(new_bits) > size {
    True -> bits
    False -> pad_to_next_byte(new_bits)
  }
}
