with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Wide_Wide_Hash;

package body Raven.Parser.Lexical.Characters is

   package Character_Maps is
     new Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => Wide_Wide_String,
        Element_Type    => Wide_Wide_Character,
        Hash            => Ada.Strings.Wide_Wide_Hash,
        Equivalent_Keys => "=");

   Name_Map : Character_Maps.Map;

   procedure Create_Name_Map;

   ---------------------
   -- Create_Name_Map --
   ---------------------

   procedure Create_Name_Map is
   begin
      --  standard character names
      Name_Map.Insert ("alarm", Wide_Wide_Character'Val (7));
      Name_Map.Insert ("backspace", Wide_Wide_Character'Val (8));
      Name_Map.Insert ("delete", Wide_Wide_Character'Val (127));
      Name_Map.Insert ("escape", Wide_Wide_Character'Val (27));
      Name_Map.Insert ("newline", Wide_Wide_Character'Val (10));
      Name_Map.Insert ("null", Wide_Wide_Character'Val (0));
      Name_Map.Insert ("return", Wide_Wide_Character'Val (13));
      Name_Map.Insert ("space", ' ');
      Name_Map.Insert ("tab", Wide_Wide_Character'Val (9));

      --  extra character names
      Name_Map.Insert ("euro", Wide_Wide_Character'Val (16#20AC#));
   end Create_Name_Map;

   -----------------------
   -- Name_To_Character --
   -----------------------

   function Name_To_Character
     (Name : Wide_Wide_String)
      return Wide_Wide_Character
   is
   begin
      if Name_Map.Is_Empty then
         Create_Name_Map;
      end if;
      if Name'Length = 1 then
         return Name (Name'First);
      elsif Name_Map.Contains (Name) then
         return Name_Map.Element (Name);
      else
         raise Constraint_Error with
           "undefined character name: " & Encode (Name);
      end if;
   end Name_To_Character;

end Raven.Parser.Lexical.Characters;
