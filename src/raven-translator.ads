with Raven.Containers;
with Raven.Target;

private package Raven.Translator is

   --  A translator holds objects while it works: the code it is
   --  building, and everything it has read out of the form it is
   --  translating.  Expanding a macro runs the machine, which
   --  allocates, so a collection can happen in the middle of a
   --  translation, and nothing else roots what the translator holds.
   --  It is therefore a container, and the target that runs one marks
   --  it for as long as it is running.

   type Abstraction is interface and Raven.Containers.Abstraction;

   procedure Translate
     (This   : in out Abstraction;
      Target : Raven.Target.Reference)
   is abstract;

end Raven.Translator;
