{
    var generator = new (require('./html-generator').HtmlGenerator);
}


document =
    text+                   { return generator.html(); }

text =
    !break s:(nl / sp)+     { generator.processSpace(); } /
    break                   { generator.processParagraphBreak(); } /
    n:nbsp                  { generator.processNbsp(n); } /
    w:char+                 { generator.processWord(w.join("")); } /
    p:punctuation           { generator.processPunctuation(p); } /
    group /
    macro /
    environment /
    comment

break "paragraph break" =
    (nl / comment)          // a paragraph break is a newline...
    (sp* nl)+               // followed by one or more newlines, mixed with spaces,...
    (sp / nl / comment)*    // ...and optionally followed by any whitespace and/or comment


group "group" =
    begin_group text* end_group


// supports LaTeX2e and LaTeX3 identifiers
identifier =
    id:(char / "_" / ":")+  { return id.join("") }

macro =
    !begin !end
    escape name:identifier
    s:"*"?
    args:(
        begin_group t:text* end_group { return t.join(""); } /
        begin_optgroup t:(!end_optgroup text)* end_optgroup { return t.join(""); } /
        (!break (nl / sp / comment))+ { return undefined; }
    )*

    {
        generator.processMacro(name, s != undefined, args);
    }

environment =
    b:begin
        c:(text*)
    e:end

    {
        generator.processEnvironment(b, c, e);

        if (b != e)
            throw Error("line " + location().start.line + ": begin and end don't match!")

        if (!envs.includes(b))
            throw Error("unknown environment!")
    }

begin =
    escape "begin" begin_group id:identifier end_group
    { return id }

end =
    escape "end" begin_group id:identifier end_group
    { return id }






/* syntax tokens - TeX's first catcodes */

escape          = "\\" { return undefined; }
begin_group     = "{"  { generator.beginGroup(); return undefined; }
end_group       = "}"  { generator.endGroup(); return undefined; }
math_shift      = "$"  { return undefined; }
alignment_tab   = "&"  { return undefined; }
macro_parameter = "#"  { return undefined; }
superscript     = "^"  { return undefined; }
subscript       = "_"  { return undefined; }
comment         = "%"  (!nl .)* (nl / EOF)      // everything up to and including the newline
                       { return undefined; }
EOF             = !.


/* syntax tokens - LaTeX */

// Note that these are in reality also just text! I'm just using a separate rule to make it look like syntax, but
// brackets do not need to be balanced.

begin_optgroup  = "["  { return undefined; }
end_optgroup    = "]"  { return undefined; }


/* text tokens - symbols that generate output */

nl       "newline"          =   [\n\r]                  { return generator.sp; }
sp       "whitespace"       =   [ \t]+                  { return generator.sp; }
char     "alpha-num"        = c:[a-z0-9]i               { return generator.character(c); }
esc_char "escaped char"     = escape c:[\\$%#&~{}_^]    { return generator.character(c); }
punctuation                 = p:[.,;:\-\*/()!?=+<>\[\]] { return generator.character(p); }
quotes                      = q:[“”"']                  // TODO

nbsp  "non-breakable space" = "~"                       { return generator.nbsp; }
endash                      = "--"                      { return generator.endash; }
emdash                      = "---"                     { return generator.emdash; }