with Raven.Target;

--  Reads a source file into a library, a form at a time.  The loop
--  lives here rather than in the parser because what is between two
--  forms is the loader's business: an import has to take effect before
--  the form after it is translated, and a translation is no place to
--  start reading another file.

private package Raven.Loader is

   --  A library asked for by name is looked for on the target's
   --  library path.  One that is loaded already is not read again,
   --  which is also what stops a cycle of imports.

   function Load
     (Target : Raven.Target.Reference;
      Name   : String)
      return Raven.Target.Library_Id;

   --  A file given a path is read whether or not a library of this
   --  name is loaded, into that library if there is one.

   function Load_File
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String)
      return Raven.Target.Library_Id;

   --  Reads a file as above and imports it into the library the host's
   --  own forms are translated in.

   procedure Import
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String);

end Raven.Loader;
