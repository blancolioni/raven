private package Raven.Parser.Tokens is

   type Token is
      (Tok_None, Tok_End_Of_File, Tok_Bad_Character,
       Tok_Identifier, Tok_String, Tok_Character, Tok_Integer, Tok_Float,

       --  An exact rational written with a slash, 7/2, which the reader
       --  hands to the machine to make (#104).

       Tok_Rational,

       --  A name written between vertical bars is a name and nothing
       --  else, which is what tells it from the one above: |#t| is a
       --  symbol whose name is #t, where #t is a boolean.

       Tok_Bar_Identifier,

       Tok_Dot, Tok_At,

       Tok_Left_Paren, Tok_Right_Paren, Tok_Quote, Tok_Quasiquote, Tok_Comma,
       Tok_Unquote_Splice,
       Tok_Start_Vector, Tok_Start_Bytevector,

       --  #; takes out the datum after it rather than a run of
       --  characters, so the lexer can only say that it saw one and
       --  the parser is what reads the datum and drops it.

       Tok_Datum_Comment,
       Tok_Nil);

end Raven.Parser.Tokens;
