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

   --  Three ways to bind a name, one for each thing a caller can mean.
   --  Define is what define means: the name is bound here, whether or
   --  not it is bound here already, and whether or not an outer
   --  environment has it.  Insert is for a name that must be new, and
   --  says so by failing if it is not.  Replace is what set! means: it
   --  follows the chain to the binding that exists, and fails if there
   --  is none.

   procedure Define
     (This  : in out Abstraction;
      Name  : String;
      Value : Object)
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
