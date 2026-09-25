package Raven.Parser.Lexical.Characters is

   --  A character by the name it is written under.  Raven.Target
   --  writes the same table the other way round, for putting a
   --  character back so that this can read it again; the two are the
   --  nine names R7RS fixes, and euro, which only this takes.

   function Name_To_Character
     (Name : Wide_Wide_String)
      return Wide_Wide_Character;

end Raven.Parser.Lexical.Characters;
