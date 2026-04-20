with Raven.Environment;

private package Raven.Engine.Environment is

   function Create
      return Raven.Environment.Reference;

   function Create
     (Parent : Raven.Environment.Reference)
      return Raven.Environment.Reference;

end Raven.Engine.Environment;
