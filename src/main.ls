#!/usr/bin/env lsc

require! {livescript, vm, JSONStream, path, 'stream-reduce', split2, fs}
require! <[ ./argv ./config ]>
require! through2: through
require! stream: {PassThrough}
require! ramda: {apply, is-nil, append, flip, type, replace, merge, map, join, for-each, split, head, pick-by}: R
require! util: {inspect}
require! './utils': {HOME}
debug = require 'debug' <| 'ramda-cli:main'

process.env.'NODE_PATH' = path.join HOME, 'node_modules'
require 'module' .Module._init-paths!

# naive fix to get `match` work despite being a keyword in LS
fix-match = ->
    it.replace /\bmatch\b/g, (m, i, str) ->
        if str[i-1] is not \. then \R.match else m

lines   = split '\n'
words   = split ' '
unlines = join '\n'
unwords = join ' '

remove-extra-newlines = (str) ->
    if /\n$/ == str then str.replace /\n*$/, '\n' else str

wrap-in-parens = (str) -> "(#str)"
path-with-cwd = path.join process.cwd!, _

make-sandbox = ->
    try user-config = require config.BASE_PATH
    catch e
        unless (e.code is 'MODULE_NOT_FOUND' and e.message is /\.config\/ramda-cli/)
            throw e

    {R, require} <<< R <<< user-config <<<
        treis     : -> apply (require 'treis'), &
        flat      : -> apply (require 'flat'), &
        read-file : path-with-cwd >> fs.read-file-sync _, 'utf8'
        id        : R.identity
        lines     : lines
        words     : words
        unlines   : unlines
        unwords   : unwords

compile-and-eval = (code) ->
    compiled = livescript.compile code, {+bare, -header}
    debug "\n#compiled", 'compiled code'
    ctx = vm.create-context make-sandbox!
    vm.run-in-context compiled, ctx

concat-stream   = -> stream-reduce flip(append), []
unconcat-stream = -> through.obj (chunk,, next) ->
    switch type chunk
    | \Array    => for-each this~push, chunk
    | otherwise => this.push chunk
    next!

raw-output-stream = -> through.obj (chunk,, next) ->
    switch type chunk
    | \Array    => for-each (~> this.push "#it\n"), chunk
    | otherwise => this.push remove-extra-newlines "#chunk\n"
    next!

inspect-stream = -> through.obj (chunk,, next) ->
    this.push (inspect chunk, colors: true) + '\n'
    next!

debug-stream = (debug, opts, str) ->
    unless debug.enabled and opts.very-verbose
        return PassThrough {+object-mode}

    through.obj (chunk,, next) ->
        debug {"#str": chunk.to-string!}
        this.push chunk
        next!

json-stringify-stream = (compact) ->
    indent = if not compact then 2 else void
    through.obj (data,, next) ->
        json = JSON.stringify data, null, indent
        this.push json + '\n'
        next!

pass-through-unless = (val, stream) ->
    switch | val       => stream
           | otherwise => PassThrough object-mode: true

map-stream = (func) -> through.obj (chunk,, next) ->
    val = func chunk
    this.push val unless is-nil val
    next!

table-output-stream = (compact) ->
    require! './format-table'
    opts = {compact}
    through.obj (chunk,, next) ->
        this.push "#{format-table chunk, opts}\n"
        next!

csv-opts-by-type = (type) ->
    opts = headers: true
    switch type
    | \csv => opts
    | \tsv => opts <<< delimiter: '\t'

output-type-to-stream = (type, compact) ->
    switch type
    | \pretty       => inspect-stream!
    | \raw          => raw-output-stream!
    | <[ csv tsv ]> => require 'fast-csv' .create-write-stream csv-opts-by-type type
    | \table        => table-output-stream compact
    | otherwise     => json-stringify-stream compact

input-type-to-stream = (type) ->
    switch type
    | \raw          => split2!
    | <[ csv tsv ]> => (require 'fast-csv') csv-opts-by-type type
    | otherwise     => JSONStream.parse!

blank-obj-stream = ->
    PassThrough {+object-mode}
        ..end {}

main = (process-argv, stdin, stdout, stderr) ->
    stdout.on \error ->
        if it.code is 'EPIPE' then process.exit 0

    debug {argv: process-argv}
    log-error = (+ '\n') >> stderr~write
    die       = log-error >> -> process.exit 1

    try opts = argv.parse process-argv
    catch e then return die [argv.help!, e.message] * '\n\n'
    debug pick-by (is not false), opts

    if opts.help    then return die argv.help!
    if opts.version then return die <| require '../package.json' .version
    if opts.configure
        return config.edit (err) ->
            if err != 0 or err then die err
            else process.exit 0

    if opts.file
        try fun = require path.resolve opts.file
        catch {stack, code}
            return switch code
            | \MODULE_NOT_FOUND  => die head lines stack
            | otherwise          => die stack

        unless typeof fun is 'function'
            return die "Error: #{opts.file} does not export a function"

        if fun.opts then opts <<< argv.parse [,,] ++ words fun.opts
    else
        code = join ' >> ', map (wrap-in-parens >> fix-match), opts._
        debug (inspect code), 'input code'
        if not code then return die argv.help!

        try fun = compile-and-eval code
        catch {message}
            return die "Error: #{message}"

        debug (inspect fun), 'evaluated to'
        unless typeof fun is 'function'
            return die "Error: evaluated into type of #{type fun} instead of Function"

    if opts.input-type  in <[ csv tsv ]> then opts.slurp   = true
    if opts.output-type in <[ csv tsv ]> then opts.unslurp = true

    input-parser = input-type-to-stream opts.input-type
    output-formatter = output-type-to-stream opts.output-type, opts.compact
    stdin-parser = ->
        stdin
        .pipe debug-stream debug, opts, \stdin
        .pipe input-parser .on \error -> die it
        .pipe pass-through-unless opts.slurp, concat-stream!

    (if opts.no-stdin then blank-obj-stream! else stdin-parser!)
        .pipe map-stream fun
        .pipe pass-through-unless opts.unslurp, unconcat-stream!
        .pipe output-formatter
        .pipe debug-stream debug, opts, \stdout
        .pipe stdout

module.exports = main
