package Raven.Reportable is

   type Abstraction is interface;

   procedure Report (This : Abstraction) is abstract;

end Raven.Reportable;
