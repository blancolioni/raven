private with Ada.Containers.Indefinite_Hashed_Maps;
private with Ada.Containers.Indefinite_Ordered_Maps;
private with Ada.Containers.Indefinite_Ordered_Sets;
private with Ada.Containers.Indefinite_Vectors;
private with Ada.Containers.Vectors;
private with Ada.Strings.Equal_Case_Insensitive;
private with Ada.Strings.Hash_Case_Insensitive;
private with Ada.Strings.Unbounded;

with Raven.Environment;
with Raven.Target;

--  What a library is here: an identity, an environment of its own, and
--  a record of where the names written in it come from.  The table
--  holds them all, and hands the running machine the environment for
--  the id the code carries, so that a name written in one library and
--  the same name written in another are two names.
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

   function Environment
     (This : Instance;
      Id   : Raven.Target.Real_Library_Id)
      return Raven.Environment.Reference;

   --  A library defines a name at the moment the form that defines it
   --  is translated, which is what takes the name back from anything
   --  the library imported under it.  What is written after that
   --  means what is written here; what was written before it does not
   --  change, which is the price of deciding this while reading.

   procedure Define_Name
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String);

   procedure Add_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Imported : Raven.Target.Real_Library_Id);

   --  An import of only some of what a library offers, or under other
   --  names (#27): (only ...), (except ...), (prefix ...) and (rename
   --  ...), however nested.  The loader works out, once, which names the
   --  import gives this library and what the imported library offers
   --  each as; Begin_Mapped_Import starts the import and Map_Import adds
   --  each name to it.  Local is what a name is written as here, and
   --  External what Imported exports it as.

   procedure Begin_Mapped_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Imported : Raven.Target.Real_Library_Id);

   procedure Map_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Local    : String;
      External : String);

   --  Every name a library offers an importer, which is what an import
   --  set starts from.

   procedure Iterate_Exports
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Process : not null access procedure (Name : String));

   --  A library that says what it is offers nothing until it says
   --  what it offers, and then exactly that.  A file that does not say
   --  is a library that offers everything it defines, which is what a
   --  program is and what every library was before there was a way to
   --  say otherwise.

   procedure Set_Export_List
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id);

   procedure Add_Export
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String);

   --  A name offered under another: what an importer writes as External
   --  is what the library itself calls Internal.

   procedure Add_Export
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Internal : String;
      External : String);

   --  Which library holds what a name written in Library means: the
   --  one that wrote it, or the last one it was imported from, or
   --  Library itself, whether or not it has the name yet.  A name
   --  nothing here accounts for is one the engine or the host bound,
   --  and the environment chain finds it.

   function Resolve
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Real_Library_Id;

   --  And what that library calls it, which is the name itself unless
   --  the export it came through renamed it.  The two go together: a
   --  reference is a library and a name in it, and a renamed import is
   --  a different name in a different library.

   function Resolved_Name
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return String;

   --  Whether anything here accounts for the name at all, which is
   --  not the same question: Resolve gives back the library itself
   --  for a name nothing accounts for, because that is where it would
   --  be defined.

   function Binds
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Boolean;

   --  The names of the macros a library has.  The definitions are not
   --  here: these are ids, and play no part in collection.

   procedure Define_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String;
      Id      : Raven.Target.Real_Macro_Id);

   procedure Undefine_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String);

   --  A macro name resolves as a variable name does: the library's
   --  own first, then what it imported, most recent first.  A library
   --  that has defined the name as a variable has taken it from any
   --  macro it imported under it.

   function Macro
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Macro_Id;

   --  What the library itself has, which is all it may give back.

   function Own_Macro
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Macro_Id;

   --  Where a library name is looked for, in the order they were
   --  added.  Path gives back nothing past the last.

   procedure Add_Path
     (This : in out Instance;
      Path : String);

   function Path
     (This  : Instance;
      Index : Positive)
      return String;

   --  A library environment is reachable only from here, so what a
   --  library holds is kept only by this.

   procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object));

private

   use Ada.Strings.Unbounded;

   package Name_Sets is
     new Ada.Containers.Indefinite_Ordered_Sets (String);

   --  An export list is a map rather than a set, from the name an
   --  importer writes to the name the library holds, because an export
   --  may rename.  Most map a name to itself.

   package Name_Maps is
     new Ada.Containers.Indefinite_Ordered_Maps (String, String);

   --  An import: the library, and when it was an import set, which
   --  names it gives and what the library calls each.  A plain import
   --  gives every name the library offers, as the library offers it, and
   --  asks the library each time, so that a library that offers
   --  everything it defines offers what it goes on to define.

   type Import_Entry is
      record
         Library : Raven.Target.Real_Library_Id;
         Mapped  : Boolean := False;
         Names   : Name_Maps.Map;
      end record;

   package Import_Vectors is
     new Ada.Containers.Vectors (Positive, Import_Entry);

   package Macro_Maps is
     new Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Raven.Target.Real_Macro_Id,
        Hash            => Ada.Strings.Hash_Case_Insensitive,
        Equivalent_Keys => Ada.Strings.Equal_Case_Insensitive,
        "="             => Raven.Target."=");

   type Library_Record is
      record
         Name        : Unbounded_String;
         Environment : Raven.Environment.Reference;
         Defined     : Name_Sets.Set;
         Imports     : Import_Vectors.Vector;
         Macros      : Macro_Maps.Map;
         Exports     : Name_Maps.Map;
         Exports_All : Boolean := True;
      end record;

   package Library_Vectors is
     new Ada.Containers.Vectors
       (Raven.Target.Real_Library_Id, Library_Record);

   package Path_Vectors is
     new Ada.Containers.Indefinite_Vectors (Positive, String);

   type Instance is tagged
      record
         Table : Library_Vectors.Vector;
         Paths : Path_Vectors.Vector;
      end record;

   function Environment
     (This : Instance;
      Id   : Raven.Target.Real_Library_Id)
      return Raven.Environment.Reference
   is (This.Table (Id).Environment);

   function Path
     (This  : Instance;
      Index : Positive)
      return String
   is (if Index <= This.Paths.Last_Index
       then This.Paths (Index)
       else "");

end Raven.Engine.Libraries;
