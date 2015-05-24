# ramda-cli [![npm version](https://badge.fury.io/js/ramda-cli.svg)](https://www.npmjs.com/package/ramda-cli)

```sh
cat people.json | R 'pluck \name' 'filter -> it.starts-with \Rob'
```

A command-line tool for processing JSON with functional pipelines.

Utilizes [Ramda's][ramda] curried, data-last API and
[LiveScript's][livescript] terse and powerful syntax.

- [Examples](#examples)
- [Tutorial: Using ramda-cli to process and display data from GitHub API][tutorial]

## install

```sh
npm install -g ramda-cli
```

## usage

```sh
cat data.json | ramda [function] ...
```

The idea is to [compose][1] functions into a pipeline of operations that when
applied to given data, produces the desired output.

By default, the function is applied to a stream of JSON data read from stdin,
and the output data is sent to standard out as stringified JSON.

Technically, `function` should be a snippet of LiveScript that evaluates into
a function. However, JavaScript function call syntax is valid LS, so if more
suitable, JavaScript can be used when writing functions.

If multiple `function` arguments are supplied, they are composed into a
pipeline in  order from left to right, as with
[`R.pipe`](http://ramdajs.com/docs/#pipe).

All Ramda's functions are available directly in the scope. See
http://ramdajs.com/docs/ for a full list.

## options

```
Usage: ramda [options] [function] ...

  -f, --file         read a function from a js/ls file instead of args; useful for
                     larger scripts
  -c, --compact      compact JSON output
  -s, --slurp        read JSON objects from stdin as one big list
  -S, --unslurp      unwraps a list before output so that each item is formatted and
                     printed separately
  -i, --input-type   read input from stdin as (one of: raw, csv, tsv)
  -o, --output-type  format output sent to stdout (one of: pretty, raw, csv, tsv, table)
  -p, --pretty       pretty-printed output with colors, alias to -o pretty
  -r, --raw-output   raw output, alias to -o raw
  -v, --verbose      print debugging information
      --version      print version
  -h, --help         displays help
```

## output types

Aside from JSON, few other types of output are supported:

##### `--output-type pretty`

Print pretty output.

##### `--output-type raw`

With raw output type when a string value is produced, the result will be
written to stdout as is without any formatting.

##### `--output-type {csv,tsv}`

CSV or TSV output type can be used when pipeline evaluates to an array of
objects, an array of arrays or when stdin consists of a stream of bare
objects. First object's keys will determine the headers.

##### `--output-type table`

Print ~any shape of data as a table. If used with a list of objects, uses the
first object's keys as headers. See an example below.

## examples

In the examples, `ramda` is aliased to `R`.

```sh
# Sum a list of numbers in JSON
echo [1,2,3] | R 'sum'
6

# Multiply each value by 2
echo [1,2,3] | R 'map multiply 2'
[2,4,6]

# Parentheses can be used like in JavaScript, if so preferred
echo [1,2,3] | R 'map(multiply(2))'
[2,4,6]
```

> Ramda functions used:
> [`sum`](http://ramdajs.com/docs/#sum),
> [`map`](http://ramdajs.com/docs/#map),
> [`multiply`](http://ramdajs.com/docs/#multiply)

##### Get a list of people whose first name starts with "B"

```sh
cat people.json | R 'pluck \name' 'filter (name) -> name.0 is \B)' -o raw
Brando Jacobson
Betsy Bayer
Beverly Gleichner
Beryl Lindgren
```

> Ramda functions used:
> [`pluck`](http://ramdajs.com/docs/#pluck),
> [`filter`](http://ramdajs.com/docs/#filter)

##### List versions of npm module with dates formatted with [`timeago`](https://www.npmjs.com/package/timeago)

It looks for `timeago` installed to `$HOME/node_modules`.

```sh
npm view ramda --json | R \
  'prop \time' 'to-pairs' \
  'map -> version: it.0, time: require("timeago")(it.1)' \
  -o tsv | column -t -s $'\t'
...
0.12.0    2 months ago
0.13.0    2 months ago
0.14.0    12 days ago
```

##### Search twitter for people who tweeted about ramda and pretty print [the result](https://raw.githubusercontent.com/raine/ramda-cli/media/twarc-ramda.png)

``` sh
twarc.py --search '#ramda' | R -s -p 'map path [\user, \screen_name]' uniq
```

> Ramda functions used:
> [`map`](http://ramdajs.com/docs/#map),
> [`path`](http://ramdajs.com/docs/#path)


##### Pull response status data from Graphite and visualize it

Status codes per minute for last hour:

```
graphite -t "summarize(stats_counts.status_codes.*, '1min', 'sum', false)" -s --from '-1h' -o json | \
  R 'map evolve datapoints: (map head) >> require \sparkline' \
    'sort-by prop \target' \
    -o table
┌────────┬───────────────────────────────────────────────────────────────┐
│ target │ datapoints                                                    │
├────────┼───────────────────────────────────────────────────────────────┤
│ 200    │ ▅▂▂▃▃▂▂▂▂▂▂▄▂▆▃▂▂▂▃▂▄▃▂▂▃▄▃▃█▃▅▂▃▇▅▄▂▄▃▃▇▂▂▂▂▂▃▂▂▄▃▂▂▂▂▃▃▁▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 204    │ ▄▄▂▃▂▁▁▁▁▂▂▂▁▅▁▁▂▁▃▂▂▃▂▁▁▂▁▄█▃▃▁▂▄▃▁▁▃▁▃▆▄▁▂▃▂▁▁▁▅▁▂▂▂▁▁▁▁▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 302    │ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██▁▁▁▁▁▁▁█▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 304    │ ▄▁▂▃▂▁▂▁▁▂▁▂▁▄▃▁▂▁▂▂▃▃▁▂▂▃▂▄▆▂▄▂▂█▄▃▂▄▃▃▆▃▂▂▂▁▂▂▂▃▂▂▂▁▁▂▂▁▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 400    │ ▁█▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 401    │ ▅▃▃▄▃▂▃▂▃▂▂▃▂▆▃▂▂▂▂▂▄▃▂▂▃▃▂▂█▃▄▃▃▅▅▄▂▃▃▃▆▂▂▂▂▂▂▁▂▃▃▂▂▂▂▂▃▁▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 404    │ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█▂▂▁▁▂▁▁▁▅▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 409    │ ▁▁▂▁▁▁▁▁▂▁▁▁▁▃▁▁▁▁▃▂▂▁▁▁▂▁▂▁▇▁▂▄▂█▃▁▁▂▁▂▁▁▂▁▁▁▁▁▁▁▁▁▂▁▁▁▂▁▁▁▁ │
├────────┼───────────────────────────────────────────────────────────────┤
│ 500    │ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ │
└────────┴───────────────────────────────────────────────────────────────┘
```


##### Use `--slurp` to read multiple JSON objects into a single list before any operations

```sh
$ cat text
"foo bar"
"test lol"
"hello world"
$ cat text | R -c --slurp identity
["foo bar","test lol","hello world"]
```

##### Solution to the [credit card JSON to CSV challenge](https://gist.github.com/jorin-vogel/2e43ffa981a97bc17259) using `--output-type csv`

```bash
#!/usr/bin/env bash

data_url=https://gist.githubusercontent.com/jorin-vogel/7f19ce95a9a842956358/raw/e319340c2f6691f9cc8d8cc57ed532b5093e3619/data.json
curl $data_url | R \
  'filter where creditcard: (!= null)' `# filter out those who don't have credit card` \
  'project [\name, \creditcard]'       `# pick name and creditcard fields from all objects` \
  -o csv > `date "+%Y%m%d"`.csv        `# print output as csv to a file named as the current date` 
```

##### Print a table with `--output-type table`

```sh
cat countries.json | R 'take 3' -o table
┌───────────────┬──────┐
│ name          │ code │
├───────────────┼──────┤
│ Afghanistan   │ AF   │
├───────────────┼──────┤
│ Åland Islands │ AX   │
├───────────────┼──────┤
│ Albania       │ AL   │
└───────────────┴──────┘
```

> Ramda functions used:
> [`take`](http://ramdajs.com/docs/#take)  
> Data: [countries.json](https://gist.github.com/raine/4756f6fc803a32663b3f)

##### List a project's dependencies in a table

```sh
npm ls --json | R 'prop \dependencies' 'map-obj prop \version' -o table
┌───────────────┬────────┐
│ data.maybe    │ 1.2.0  │
├───────────────┼────────┤
│ data.task     │ 3.0.0  │
├───────────────┼────────┤
│ es5-ext       │ 0.10.7 │
└───────────────┴────────┘
```

> Ramda functions used:
> [`filter`](http://ramdajs.com/docs/#filter),
> [`where`](http://ramdajs.com/docs/#where),
> [`project`](http://ramdajs.com/docs/#project),
> [`mapObj`](http://ramdajs.com/docs/#mapObj),
> [`prop`](http://ramdajs.com/docs/#prop)

##### Load function from a file with the `--file` option

```sh
$ cat shout.js
var R = require('ramda');
module.exports = R.pipe(R.toUpper, R.add(R.__, '!'));
$ echo -n 'hello world' | R -i raw --file shout.js
"HELLO WORLD!"
```

## debugging

You can turn on the debug output with `-v, --verbose` flag.

```sh
ramda-cli 'R.sum' +0ms input code
ramda-cli 'R.sum;' +14ms compiled code
ramda-cli [Function: f1] +4ms evaluated to
```

[`treis`][treis] is available for debugging individual functions in the
pipeline:

<img width="370" height="99" src="https://raw.githubusercontent.com/raine/ramda-cli/media/treis-face.png" />

## why LiveScript?

> [LiveScript][livescript] is a language which compiles to JavaScript. It has
a straightforward mapping to JavaScript and allows you to write expressive
code devoid of repetitive boilerplate. While LiveScript adds many features to
assist in functional style programming, it also has many improvements for
object oriented and imperative programming.

- Function composition operators `.`, `<<`, `>>`
- Pipes for nested function calls `|>`
- Partial application with `_`
- Implicit access `(.length)`

--

[![wercker status](https://app.wercker.com/status/92dbf35ece249fade3e8198181d93ec1/s "wercker status")](https://app.wercker.com/project/bykey/92dbf35ece249fade3e8198181d93ec1)

[1]: http://en.wikipedia.org/wiki/Function_composition_%28computer_science%29
[livescript]: http://livescript.net
[treis]: https://github.com/raine/treis
[ramda]: http://ramdajs.com
[tutorial]: https://gistlog.co/raine/d12d0ec3e72b2945510b
