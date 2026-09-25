private package Raven.IO is

   type Abstraction is interface;
   type Reference is access all Abstraction'Class;

   procedure Put (This : in out Abstraction;
                  Ch   : Wide_Wide_Character)
   is null;

   --  A character from wherever the host reads, and whether there was
   --  one.  Nothing could be read at all before this.

   procedure Get (This      : in out Abstraction;
                  Ch        : out Wide_Wide_Character;
                  Available : out Boolean)
   is abstract;

   function Null_IO return Reference;
   function Standard_IO return Reference;

end Raven.IO;
