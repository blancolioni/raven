with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Raven.Parser;

package body Raven.Libraries is

   function Load_File (Name : String) return String;

   ------------
   -- Import --
   ------------

   procedure Import
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String)
   is
      Source : constant String := Load_File (Path);
   begin
      Raven.Parser.Load_Module (Name, Source, Target);
   exception
      when E : Raven.Target.Undefined_Symbol =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Undefined: " & Ada.Exceptions.Exception_Message (E));
      when E : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Error: " & Ada.Exceptions.Exception_Message (E));
   end Import;

   ---------------
   -- Load_File --
   ---------------

   function Load_File (Name : String) return String is
      use Ada.Text_IO;
      use Ada.Strings.Unbounded;

      File : File_Type;
      Buf  : Unbounded_String := Null_Unbounded_String;
   begin
      Open (File, In_File, Name);

      while not End_Of_File (File) loop
         declare
            Line : constant String := Get_Line (File);
         begin
            Append (Buf, Line);
            Append (Buf, ASCII.LF);
         end;
      end loop;

      Close (File);
      return To_String (Buf);
   end Load_File;

end Raven.Libraries;
