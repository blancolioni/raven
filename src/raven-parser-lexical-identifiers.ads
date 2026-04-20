with Raven.Parser.Tokens;

package Raven.Parser.Lexical.Identifiers is

   function Classify_Identifier
     (Id : Wide_Wide_String)
      return Raven.Parser.Tokens.Token;

end Raven.Parser.Lexical.Identifiers;
