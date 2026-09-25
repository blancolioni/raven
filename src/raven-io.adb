with Ada.Wide_Wide_Text_IO;

package body Raven.IO is

   type Null_IO_Instance is new IO_Interface with null record;

   overriding procedure Put (This : in out Null_IO_Instance;
                             Ch   : Wide_Wide_Character)
   is null;

   overriding procedure Put_Error (This : in out Null_IO_Instance;
                                   Ch   : Wide_Wide_Character)
   is null;

   overriding procedure Get (This      : in out Null_IO_Instance;
                             Ch        : out Wide_Wide_Character;
                             Available : out Boolean);

   Local_Null_IO : aliased Null_IO_Instance;

   type Standard_IO_Instance is new IO_Interface with null record;

   overriding procedure Put (This : in out Standard_IO_Instance;
                             Ch   : Wide_Wide_Character);

   overriding procedure Put_Error (This : in out Standard_IO_Instance;
                                   Ch   : Wide_Wide_Character);

   overriding procedure Get (This      : in out Standard_IO_Instance;
                             Ch        : out Wide_Wide_Character;
                             Available : out Boolean);

   Local_Standard_IO : aliased Standard_IO_Instance;

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

   function Null_IO return IO_Reference is
   begin
      return Local_Null_IO'Access;
   end Null_IO;

   ---------
   -- Put --
   ---------

   overriding procedure Put (This : in out Standard_IO_Instance;
                             Ch   : Wide_Wide_Character)
   is
      pragma Unreferenced (This);
   begin
      Ada.Wide_Wide_Text_IO.Put (Ch);
   end Put;

   ---------------
   -- Put_Error --
   ---------------

   overriding procedure Put_Error (This : in out Standard_IO_Instance;
                                   Ch   : Wide_Wide_Character)
   is
      pragma Unreferenced (This);
   begin
      Ada.Wide_Wide_Text_IO.Put (Ada.Wide_Wide_Text_IO.Standard_Error, Ch);
   end Put_Error;

   -----------------
   -- Standard_IO --
   -----------------

   function Standard_IO return IO_Reference is
   begin
      --  One of these, rather than one for each VM that asks: it holds
      --  nothing, and two of them would be the same terminal anyway.

      return Local_Standard_IO'Access;
   end Standard_IO;

end Raven.IO;
