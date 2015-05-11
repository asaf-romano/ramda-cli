# ramda-cli

An experimental command-line tool for processing JSON with
[Ramda](http://ramdajs.com).

Takes advantage of [LiveScript](http://livescript.net) to provide a nice and
terse interface for writing pipelines.

```sh
npm install -g ramda-cli
```

## usage

```sh
cat data.json | ramda [function]
```

`function` should be a snippet of LiveScript that evaluates into a function.

The function is applied to the JSON data piped in through standard input, and
the result is printed as JSON.

All Ramda's functions are available directly in the scope. See
http://ramdajs.com/docs/ for a full list.

## examples

```sh
echo 1 | ramda 'add 1' # 2
```

```sh
echo [1,2,3] | ramda 'sum' # 6
```

Reformat and check validity of JSON with [R.identity](http://ramdajs.com/docs/#identity):

```sh
cat data.json | ramda identity
```

```sh
curl -s http://raine.github.io/ramda-json-docs/latest.json | \
  ramda '(pluck \name) . filter where {category: \Logic}'
[
    "and",
    "both",
    "complement",
    "cond",
    ...
]
```

```sh
# parentheses can be used like in JavaScript, if necessary
echo [1,2,3,4,5] | ramda 'pipe(map(multiply(2)), filter(gt(__, 4)))'
```

Given [`friends.json`](https://gist.github.com/raine/59c411488b5d0718f4f3):

```sh
cat friends.json |\
  ramda 'first-word=(head . split " "); prop(\friends) >> map(first-word . prop(\fullName)) >> sortBy length'
[
    "Sara",
    "Abby",
    "Carla",
    "Beach",
    "Carroll",
    "Belinda",
    "Mitchell",
    "Courtney"
]
```

## debugging

You can turn on the debug logging with `export DEBUG=*`.

```
ramda-cli 'R.sum' +0ms input code
ramda-cli 'R.sum;' +14ms compiled code
ramda-cli [Function: f1] +4ms evaluated to
```

## why LiveScript?

> [LiveScript](http://livescript.net) is a fork of Coco and an indirect
descendant of CoffeeScript, with which it has much compatibility.

- Function composition operators `.`, `<<`, `>>`
- Pipes for nested function calls `|>`
- Partial application with `_`
- It's awesome.
