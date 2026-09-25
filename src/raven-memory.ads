with Raven.Containers;
with Raven.Objects;
with Raven.Reportable;

private package Raven.Memory is

   type Abstraction is interface and Raven.Reportable.Abstraction;

   type Reference is access all Abstraction'Class;

   type Cell_Type is
      record
         Car, Cdr : Object;
      end record;

   function Get
     (This    : Abstraction;
      Address : Address_Type)
      return Cell_Type
      is abstract;

   procedure Set
     (This    : in out Abstraction;
      Address : Address_Type;
      Cell    : Cell_Type)
      is abstract;

   function Cons
     (This : in out Abstraction;
      Car  : Object;
      Cdr  : Object)
      return Object
      is abstract;

   --  A vector of this many elements, every one of them nil.  The
   --  cells it takes are contiguous, so an element is reached by
   --  arithmetic; asking for one may collect, and nothing of the
   --  vector exists until it answers, so there is nothing of it to
   --  keep alive across that.

   function New_Vector
     (This   : in out Abstraction;
      Length : Natural)
      return Object
   is abstract;

   function Vector_Length
     (This : Abstraction;
      V    : Object)
      return Natural
   is abstract;

   function Vector_Element
     (This  : Abstraction;
      V     : Object;
      Index : Natural)
      return Object
   is abstract;

   procedure Set_Vector_Element
     (This  : in out Abstraction;
      V     : Object;
      Index : Natural;
      Value : Object)
   is abstract;

   procedure Add_Container
     (This      : in out Abstraction;
      Container : not null access Raven.Containers.Abstraction'Class)
   is abstract;

   function Create_Foreign_Value
     (This  : in out Abstraction;
      Value : Foreign_Value_Instance'Class)
      return Object
      is abstract;

   function To_Foreign_Value
     (This : Abstraction;
      Value : Object)
      return Foreign_Value_Instance'Class
   is abstract
     with Pre'Class => Raven.Objects.Is_Foreign_Value (Value);

   procedure Mark
     (This : in out Abstraction;
      Root : in out Object)
   is abstract;

end Raven.Memory;
