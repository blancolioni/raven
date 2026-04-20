private package Raven.Containers is

   type Abstraction is interface;

   procedure Before_Collection
     (This : in out Abstraction)
   is null;

   procedure After_Collection
     (This : in out Abstraction)
   is null;

   procedure Mark
     (This : in out Abstraction;
      Process : not null access procedure (Value : in out Object))
   is abstract;

end Raven.Containers;
