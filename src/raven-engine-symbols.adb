with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Equal_Case_Insensitive;
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
      end record;

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
