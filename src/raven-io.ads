private package Raven.IO is

   type Abstraction is interface;
   type Reference is access all Abstraction'Class;

   procedure Put (This : in out Abstraction;
                  Ch   : Wide_Wide_Character)
   is null;

   function Null_IO return Reference;
   function Standard_IO return Reference;

end Raven.IO;
