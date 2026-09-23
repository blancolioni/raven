private with Ada.Containers.Vectors;
private with Ada.Strings.Unbounded;

with Raven.Environment;
with Raven.Target;

--  What a library is here: an identity, and an environment of its own.
--  The table holds them all, and hands the running machine the
--  environment for the id the code carries, so that a name written in
--  one library and a name written in another are two names.
--
--  Every library environment is made with a parent, which holds what
--  the engine binds and what the host binds through
--  Bind_Foreign_Function.  Those stay visible everywhere, which R7RS
--  would not have: a host's bindings belong to the machine rather than
--  to any library, and there is nowhere else to put them.

private package Raven.Engine.Libraries is

   type Instance is tagged private;

   function Create
     (This   : in out Instance;
      Name   : String;
      Parent : Raven.Environment.Reference)
      return Raven.Target.Real_Library_Id;

   function Find
     (This : Instance;
      Name : String)
      return Raven.Target.Library_Id;

   function Name
     (This : Instance;
      Id   : Raven.Target.Real_Library_Id)
      return String;

   function Environment
     (This : Instance;
      Id   : Raven.Target.Real_Library_Id)
      return Raven.Environment.Reference;

   --  A library environment is reachable only from here, so what a
   --  library holds is kept only by this.

   procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object));

private

   use Ada.Strings.Unbounded;

   type Library_Record is
      record
         Name        : Unbounded_String;
         Environment : Raven.Environment.Reference;
      end record;

   package Library_Vectors is
     new Ada.Containers.Vectors
       (Raven.Target.Real_Library_Id, Library_Record);

   type Instance is tagged
      record
         Table : Library_Vectors.Vector;
      end record;

   function Name
     (This : Instance;
      Id   : Raven.Target.Real_Library_Id)
      return String
   is (To_String (This.Table (Id).Name));

   function Environment
     (This : Instance;
      Id   : Raven.Target.Real_Library_Id)
      return Raven.Environment.Reference
   is (This.Table (Id).Environment);

end Raven.Engine.Libraries;
