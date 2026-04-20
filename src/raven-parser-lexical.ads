private with Ada.Containers.Indefinite_Vectors;
private with Ada.Strings.Wide_Wide_Unbounded;

with Raven.Parser.Tokens;             use Raven.Parser.Tokens;

private package Raven.Parser.Lexical is

   type Instance is tagged private;

   procedure Open
     (This   : in out Instance;
      Name   : String;
      Source : Wide_Wide_String);

   procedure Close (This : in out Instance);

   procedure Scan (This : in out Instance);

   function Tok (This : Instance'Class)
                 return Token;
   function Tok_Text (This : in out Instance'Class)
                      return Wide_Wide_String;
   function Tok_Character_Value
     (This : in out Instance'Class)
      return Wide_Wide_Character;
   function Tok_Integer_Value (This : in out Instance'Class)
                               return Natural;

   procedure Error
     (This    : in out Instance;
      Message : Wide_Wide_String);

   function Current_File_Name (This : Instance)  return String;
   function Current_Line (This : Instance)  return Natural;

private

   use Ada.Strings.Wide_Wide_Unbounded;

   package Line_Vectors is
     new Ada.Containers.Indefinite_Vectors (Positive, Wide_Wide_String);

   type Source_Stream_Record is
      record
         Identity   : Unbounded_Wide_Wide_String;
         Lines      : Line_Vectors.Vector;
         Line       : Natural;
         Column     : Natural;
         Tok_Line   : Natural;
         Tok_Column : Natural;
         Ch         : Wide_Wide_Character;
         Tok        : Token;
         Tok_Text   : Unbounded_Wide_Wide_String;
         Tok_Char   : Wide_Wide_Character;
         EOF        : Boolean;
      end record;

   Empty_Stream : constant Source_Stream_Record :=
                    (Identity      => Null_Unbounded_Wide_Wide_String,
                     Lines         => [],
                     Line          => 0,
                     Column        => 0,
                     Tok_Line      => 0,
                     Tok_Column    => 0,
                     Ch            => ' ',
                     Tok           => Tok_None,
                     Tok_Text      => Null_Unbounded_Wide_Wide_String,
                     Tok_Char      => ' ',
                     EOF           => True);

   Max_Source_Files : constant := 10;

   type Source_Stream is access all Source_Stream_Record;
   type Source_Stream_Array is array (1 .. Max_Source_Files) of Source_Stream;

   type Instance is tagged
      record
         Source_Stream_Stack  : Source_Stream_Array;
         Current_Stream_Index : Natural := 0;
         Current_Stream       : Source_Stream;
      end record;

   function Hex_Digit (Ch : Wide_Wide_Character) return Natural;

end Raven.Parser.Lexical;
