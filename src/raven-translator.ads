with Raven.Target;

private package Raven.Translator is

   type Abstraction is limited interface;

   procedure Translate
     (This   : in out Abstraction;
      Target : Raven.Target.Reference)
   is abstract;

end Raven.Translator;
