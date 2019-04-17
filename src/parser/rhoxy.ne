@include "spacecomments.ne"
@include "ground.ne"
@include "patternMatcher.ne"

# Apparently, the top-level thing should always be the first parse rule
main -> _ proc _ {% ([,p,]) => p %}

proc ->
    ground {% id %}
  | "{" _ proc _ "}"  {% ([,,proc,,]) => (proc) %}
  | chan _ "!" _ "(" _ proc _ ")"
      {% ([chan,,,,,,message,,]) => ({
        tag: 'send',
        chan,
        message
      }) %}

  | "for" _ "(" _ actions _ ")" _ "{" _ proc _ "}"
      {% ([,,,,actions,,,,,,body,,]) => ({
        tag: 'join',
        actions,
        body
      }) %}
  | proc _ "|" _ proc
      {% ([p1,,,,p2]) => {
        ps1 = p1.tag === "par" ? p1.procs : [p1]
        ps2 = p2.tag === "par" ? p2.procs : [p2]
        return {
          tag: "par",
          procs: ps1.concat(ps2)
        }
      } %}
  | "bundle" _ "{" proc "}"
      # For now bundles are only to prevent destructuring. Not read-write restriction.
      {% ([,,,proc,]) => ({
        tag: "bundle",
        proc
      }) %}
  | "new" __ variables __ "in" _ proc
      {% ([,,vars,,,,body]) => ({
          tag: "new",
          vars,
          body
      }) %}
  # TODO support multiple bindings Prolly worth fixing parse ambiguity discovered
  # in actions first though. For now I'll just want standard out anyway.
  | lookup __ variable "(`" uri "`)" _ "in" _ proc
      {% ([,,v,,uri,,,,,body]) => ({
        tag: "lookup",
        v,
        uri,
        body
      }) %}
  # This really should be zero or more stars, but Nil is parsing as variable
  | "*":+ variable {% ([,v]) => v %}

uri -> [a-zA-Z0-9:]:* {% ([l]) => l.join('') %}

lookup -> "new" | "lookup" {% (d) => null %}

chan -> "@" proc {% ([,c]) => c %}


actions ->
    action # Don't manually put this in a list {% d => [d] %}
           # Parsers always return a one-deeper list
  # TODO multiple actions doesn't seem to work yet. Ambiguous grammar.
  # nearley-test rhoxyGrammar.js --input "x <- @Nil; y <- @Nil"
  # https://nearley.js.org/docs/how-to-grammar-good says "don't roll your own unroller"
  | actions _ ";" _ action
      {% ([actions,,,,action]) =>
        actions.concat([action])
       %}


action -> _ pattern _ "<-" _ chan _
  {% ([,pattern,,,,chan,]) => ({
    tag: "action",
    pattern,
    chan
  }) %}


variable ->
  [a-zA-Z] [a-zA-Z0-9]:*
    {% ([n, ame]) => ({
      tag: "variable",
      givenName: n + ame.join('')
    }) %}

# TODO this is copied from "actions" which gives an ambiguous grammar.
variables ->
    variable
  | variables _ "," _ variable
    {% ([variables,,,,variable]) =>
      variables.concat([variable])
     %}
