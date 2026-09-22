with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Fixed;
with Ada.Strings.Hash_Case_Insensitive;

with Raven.Objects;

package body Raven.Engine.Symbols is

   package Symbol_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Raven.Objects.Symbol_Id,
      Hash            => Ada.Strings.Hash_Case_Insensitive,
      Equivalent_Keys => Ada.Strings.Equal_Case_Insensitive,
      "="             => Raven.Objects."=");

   package Symbol_Vectors is
     new Ada.Containers.Indefinite_Vectors (Raven.Objects.Symbol_Id, String);

   type Instance is
     new Raven.Symbols.Abstraction with
      record
         Symbol_Map    : Symbol_Maps.Map;
         Symbol_Vector : Symbol_Vectors.Vector;
         Generated     : Natural := 0;
      end record;

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

   ------------
   -- Create --
   ------------

   function Create return Raven.Symbols.Reference is
   begin
      return new Instance;
   end Create;

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
      This.Symbol_Vector.Append
        (Ada.Characters.Handling.To_Lower (Prefix) & "." & Count);
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
      This.Symbol_Vector.Append (Ada.Characters.Handling.To_Lower (Name));
      return Id : constant Raven.Objects.Symbol_Id :=
        This.Symbol_Vector.Last_Index
      do
         This.Symbol_Map.Insert (Name, Id);
      end return;
   end To_Symbol_Id;

end Raven.Engine.Symbols;
