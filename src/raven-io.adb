with Ada.Wide_Wide_Text_IO;

package body Raven.IO is

   type Null_IO_Instance is new Abstraction with null record;

   overriding procedure Get (This      : in out Null_IO_Instance;
                             Ch        : out Wide_Wide_Character;
                             Available : out Boolean);

   Local_Null_IO : aliased Null_IO_Instance;

   type Standard_IO_Instance is new Abstraction with
      record
         null;
      end record;

   overriding procedure Put
     (This : in out Standard_IO_Instance;
      Ch   : Wide_Wide_Character);

   overriding procedure Get (This      : in out Standard_IO_Instance;
                             Ch        : out Wide_Wide_Character;
                             Available : out Boolean);

   ---------
   -- Get --
   ---------

   overriding procedure Get (This      : in out Null_IO_Instance;
                             Ch        : out Wide_Wide_Character;
                             Available : out Boolean)
   is
      pragma Unreferenced (This);
   begin
      --  A host that writes nowhere reads nothing.

      Ch := ' ';
      Available := False;
   end Get;

   ---------
   -- Get --
   ---------

   overriding procedure Get (This      : in out Standard_IO_Instance;
                             Ch        : out Wide_Wide_Character;
                             Available : out Boolean)
   is
      pragma Unreferenced (This);
   begin
      Ada.Wide_Wide_Text_IO.Get_Immediate (Ch, Available);
   exception
      when Ada.Wide_Wide_Text_IO.End_Error =>
         Ch := ' ';
         Available := False;
   end Get;

   -------------
   -- Null_IO --
   -------------

   function Null_IO return Reference is
   begin
      return Local_Null_IO'Access;
   end Null_IO;

   -----------------
   -- Standard_IO --
   -----------------

   function Standard_IO return Reference is
   begin
      return new Standard_IO_Instance;
   end Standard_IO;

   ---------
   -- Put --
   ---------

   overriding procedure Put
     (This : in out Standard_IO_Instance;
      Ch   : Wide_Wide_Character)
   is
   begin
      Ada.Wide_Wide_Text_IO.Put (Ch);
   end Put;

end Raven.IO;
