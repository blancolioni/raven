private package Raven.Parser.Tokens is

   type Token is
      (Tok_None, Tok_End_Of_File, Tok_Bad_Character,
       Tok_Identifier, Tok_String, Tok_Character, Tok_Integer, Tok_Float,

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
