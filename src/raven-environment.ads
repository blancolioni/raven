with Raven.Containers;

private package Raven.Environment is

   type Abstraction is interface
     and Raven.Containers.Abstraction;

   type Reference is access all Abstraction'Class;

   function Parent
     (This : Abstraction)
      return Reference
      is abstract;

   function Lookup
     (This : Abstraction;
      Name : String)
      return Object
      is abstract;

   procedure Insert
     (This  : in out Abstraction;
      Name  : String;
      Value : Object)
   is abstract;

   procedure Replace
     (This  : in out Abstraction;
      Name  : String;
      Value : Object)
   is abstract;

   procedure Close
     (This  : not null access Abstraction)
   is abstract;

end Raven.Environment;
