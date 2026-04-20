with Raven.Evaluator;
with Raven.Memory;

private package Raven.Engine is

   function Create
     (VM            : Raven_VM;
      Memory        : Raven.Memory.Reference;
      Configuration : String)
      return Raven.Evaluator.Reference;

   function Create_Memory
     (Size : Natural)
      return Raven.Memory.Reference;

end Raven.Engine;
