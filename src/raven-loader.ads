with Raven.Target;

--  Reads a source file into a target, a form at a time.  The loop
--  lives here rather than in the parser because what is between two
--  forms is the loader's business: a declaration has to be acted on
--  before the form after it is translated.

private package Raven.Loader is

   procedure Import
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String);

end Raven.Loader;
