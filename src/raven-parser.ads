with Raven.Target;

private package Raven.Parser is

   procedure Parse_Expression
     (Expression : String;
      Target     : Raven.Target.Reference);

   procedure Load_Module
     (Name   : String;
      Source : String;
      Target : Raven.Target.Reference);

end Raven.Parser;
