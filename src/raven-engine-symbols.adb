with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Ordered_Maps;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;

with Raven.Objects;

package body Raven.Engine.Symbols is

   --  A symbol is its name exactly as written (#160).  This table
   --  folded every name to lower case, which made Foo and foo one
   --  symbol and meant string->symbol could not hand back the string
   --  it was given.  Folding is the reader's, after #!fold-case.

   package Symbol_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Raven.Objects.Symbol_Id,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Raven.Objects."=");

   package Symbol_Vectors is
     new Ada.Containers.Indefinite_Vectors (Raven.Objects.Symbol_Id, String);

   type Alias_Record is
      record
         Original : Raven.Objects.Symbol_Id;
         Library  : Positive;
         Scope    : Natural;
      end record;

   package Alias_Maps is
     new Ada.Containers.Ordered_Maps
       (Raven.Objects.Symbol_Id, Alias_Record, Raven.Objects."<");

   type Instance is
     new Raven.Symbols.Abstraction with
      record
         Symbol_Map    : Symbol_Maps.Map;
         Symbol_Vector : Symbol_Vectors.Vector;
         Generated     : Natural := 0;
         Aliases       : Alias_Maps.Map;
      end record;

   overriding function New_Alias_Id
     (This     : in out Instance;
      Original : Raven.Objects.Symbol_Id;
      Library  : Positive;
      Scope    : Natural := 0)
      return Raven.Objects.Symbol_Id;

   overriding function Alias_Scope
     (This : Instance;
      Id   : Raven.Objects.Symbol_Id)
      return Natural;

   overriding function Alias_Original
     (This : Instance;
      Id   : Raven.Objects.Symbol_Id)
      return Raven.Objects.Symbol_Id;

   overriding function Alias_Library
     (This : Instance;
      Id   : Raven.Objects.Symbol_Id)
      return Natural;

   overriding function New_Symbol_Id
     (This   : in out Instance;
      Prefix : String)
      return Raven.Objects.Symbol_Id;

   overriding function To_Symbol_Id
     (This  : in out Instance;
      Name  : String)
      return Raven.Objects.Symbol_Id;

   overriding function To_String
     (This  : Instance;
      Id    : Raven.Objects.Symbol_Id)
      return String;

   -------------------
   -- Alias_Library --
   -------------------

   overriding function Alias_Library
     (This : Instance;
      Id   : Raven.Objects.Symbol_Id)
      return Natural
   is
      Position : constant Alias_Maps.Cursor := This.Aliases.Find (Id);
   begin
      return (if Alias_Maps.Has_Element (Position)
              then Alias_Maps.Element (Position).Library
              else 0);
   end Alias_Library;

   --------------------
   -- Alias_Original --
   --------------------

   overriding function Alias_Original
     (This : Instance;
      Id   : Raven.Objects.Symbol_Id)
      return Raven.Objects.Symbol_Id
   is
      Position : constant Alias_Maps.Cursor := This.Aliases.Find (Id);
   begin
      return (if Alias_Maps.Has_Element (Position)
              then Alias_Maps.Element (Position).Original
              else Id);
   end Alias_Original;

   -----------------
   -- Alias_Scope --
   -----------------

   overriding function Alias_Scope
     (This : Instance;
      Id   : Raven.Objects.Symbol_Id)
      return Natural
   is
      Position : constant Alias_Maps.Cursor := This.Aliases.Find (Id);
   begin
      return (if Alias_Maps.Has_Element (Position)
              then Alias_Maps.Element (Position).Scope
              else 0);
   end Alias_Scope;

   ------------
   -- Create --
   ------------

   function Create return Raven.Symbols.Reference is
   begin
      return new Instance;
   end Create;

   ------------------
   -- New_Alias_Id --
   ------------------

   overriding function New_Alias_Id
     (This     : in out Instance;
      Original : Raven.Objects.Symbol_Id;
      Library  : Positive;
      Scope    : Natural := 0)
      return Raven.Objects.Symbol_Id
   is
      --  Shown as the name it stands for and a count, as a generated
      --  symbol is, so that a trace says which name it was.

      Id : constant Raven.Objects.Symbol_Id :=
             This.New_Symbol_Id (This.To_String (Original));
   begin
      This.Aliases.Insert (Id, (Original, Library, Scope));
      return Id;
   end New_Alias_Id;

   -------------------
   -- New_Symbol_Id --
   -------------------

   overriding function New_Symbol_Id
     (This   : in out Instance;
      Prefix : String)
      return Raven.Objects.Symbol_Id
   is
      Count : constant String :=
                Ada.Strings.Fixed.Trim
                  (Natural'Image (This.Generated + 1),
                   Ada.Strings.Both);
   begin
      --  The name goes in the vector, so that the symbol can be shown,
      --  and stays out of the map, so that reading it gives a symbol
      --  of its own.  Nothing but this can hand the name back.

      This.Generated := This.Generated + 1;
      This.Symbol_Vector.Append (Prefix & "." & Count);
      return This.Symbol_Vector.Last_Index;
   end New_Symbol_Id;

   ---------------
   -- To_String --
   ---------------

   overriding function To_String
     (This  : Instance;
      Id    : Raven.Objects.Symbol_Id)
      return String
   is
   begin
      return This.Symbol_Vector.Element (Id);
   end To_String;

   ------------------
   -- To_Symbol_Id --
   ------------------

   overriding function To_Symbol_Id
     (This  : in out Instance;
      Name  : String)
      return Raven.Objects.Symbol_Id
   is
      use Symbol_Maps;
      Position : constant Cursor := This.Symbol_Map.Find (Name);
   begin
      if Has_Element (Position) then
         return Element (Position);
      end if;
      This.Symbol_Vector.Append (Name);
      return Id : constant Raven.Objects.Symbol_Id :=
        This.Symbol_Vector.Last_Index
      do
         This.Symbol_Map.Insert (Name, Id);
      end return;
   end To_Symbol_Id;

end Raven.Engine.Symbols;
