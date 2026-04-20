with Raven.Environment;
with Raven.Memory;
with Raven.Symbols;
with Raven.Target;

private package Raven.Engine.SECD is

   function Create
     (VM      : Raven_VM;
      Memory  : Raven.Memory.Reference;
      Env     : Raven.Environment.Reference;
      Symbols : not null access Raven.Symbols.Abstraction'Class)
      return Raven.Target.Reference;

end Raven.Engine.SECD;
