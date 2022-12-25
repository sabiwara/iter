require Iter

[1, 2, 3]
|> Iter.take(-1)
|> Iter.map(&to_string/1)
