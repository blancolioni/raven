with Raven.Target;

--  Reads a source file into a library, a form at a time.  The loop
--  lives here rather than in the parser because what is between two
--  forms is the loader's business: an import has to take effect before
--  the form after it is translated, and a translation is no place to
--  start reading another file.

private package Raven.Loader is

   --  Reads a file as a library of this name, whether or not a
   --  library of the name is loaded, and imports it into the library
   --  the host's own forms are translated in.  A library asked for by
   --  name, rather than given a path, is what an import declaration
   --  asks for, and the loader looks after that itself.

   procedure Import
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String);

   --  A form the host has just handed the machine may be a
   --  declaration rather than an expression.  Takes it if it is, and
   --  says whether it was: what a program opens with, a REPL has to be
   --  able to type.

   function Take_Declaration
     (Target : Raven.Target.Reference)
      return Boolean;

end Raven.Loader;
